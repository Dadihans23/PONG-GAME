// Sensibilité de la raquette de 0 à 100 : courbe (vitesse maximale,
// inclinaison qui l'atteint, exposant), zone morte, 0 jouable, monotonie,
// plafond du duel et conversion des anciens crans.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/game_tuning.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';

// Ancien réglage « Normale » : 1,42 unité/s à 90°, linéaire
double oldNormalAt(double degrees) {
  final double s = sin(degrees * pi / 180);
  return 1.42 * max(0.0, (s - 0.05) / 0.95);
}

void main() {
  group('Bornes du curseur', () {
    test('0 à 100, valeur par défaut au milieu', () {
      expect(PaddleSensitivity.min, 0);
      expect(PaddleSensitivity.max, 100);
      expect(PaddleSensitivity.defaultValue, GameTuning.paddleSensitivityDefault);
      expect(PaddleSensitivity.clamp(-5), 0);
      expect(PaddleSensitivity.clamp(250), 100);
      expect(PaddleSensitivity.clamp(42), 42);
    });

    test('vitesse maximale et inclinaison aux deux extrémités', () {
      expect(PaddleSensitivity.maxSpeed(0), GameTuning.paddleMaxSpeedAtMin);
      expect(PaddleSensitivity.maxSpeed(100), GameTuning.paddleMaxSpeedAtMax);
      expect(PaddleSensitivity.fullTiltDegrees(0), closeTo(60, 1e-12));
      expect(PaddleSensitivity.fullTiltDegrees(100), closeTo(20, 1e-12));
      expect(PaddleSensitivity.fullTilt(0), closeTo(sin(pi / 3), 1e-12));
    });

    test('hors bornes : comme la borne la plus proche', () {
      expect(PaddleSensitivity.maxSpeed(-20), PaddleSensitivity.maxSpeed(0));
      expect(PaddleSensitivity.maxSpeed(400), PaddleSensitivity.maxSpeed(100));
    });
  });

  group('Courbe', () {
    test('zone morte : immobile sous 3° à toutes les sensibilités', () {
      for (final value in [0, 50, 100]) {
        expect(PaddleSensitivity.speedAtDegrees(value, 0), 0.0);
        expect(PaddleSensitivity.speedAtDegrees(value, 2.5), 0.0, reason: 'sensibilité $value');
        expect(PaddleSensitivity.speedAtDegrees(value, 4), greaterThan(0.0));
      }
    });

    test("vitesse maximale atteinte à l'inclinaison prévue, jamais dépassée", () {
      for (final value in [0, 25, 50, 75, 100]) {
        final double full = PaddleSensitivity.fullTiltDegrees(value);
        final double vmax = PaddleSensitivity.maxSpeed(value);
        expect(PaddleSensitivity.speedAtDegrees(value, full), closeTo(vmax, 1e-9));
        expect(PaddleSensitivity.speedAtDegrees(value, 89), closeTo(vmax, 1e-9));
        expect(PaddleSensitivity.speedAtDegrees(value, full - 5), lessThan(vmax));
      }
    });

    test('symétrique à gauche et à droite', () {
      final control = PaddleSensitivity.tiltControl(70);
      expect(control.speedFor(-0.4), closeTo(-control.speedFor(0.4), 1e-12));
    });

    test('précision : les petites inclinaisons plus douces que les grandes', () {
      // À mi-chemin entre la zone morte et la pleine inclinaison, moins de
      // la moitié de la vitesse maximale : courbe convexe
      for (final value in [0, 50, 100]) {
        final double full = PaddleSensitivity.fullTilt(value);
        final double half = (full + GameTuning.tiltDeadZone) / 2;
        final control = PaddleSensitivity.tiltControl(value);
        final double ratio = control.speedFor(half) / PaddleSensitivity.maxSpeed(value);
        expect(ratio, closeTo(pow(0.5, GameTuning.tiltCurveExponent), 1e-9), reason: 'sensibilité $value');
        expect(ratio, lessThan(0.5));
      }
    });

    test('monotone : plus haut = plus rapide à toute inclinaison', () {
      for (final degrees in [5.0, 10.0, 15.0, 30.0, 45.0, 70.0]) {
        double previous = -1;
        for (int value = 0; value <= 100; value += 5) {
          final double speed = PaddleSensitivity.speedAtDegrees(value, degrees);
          expect(speed, greaterThanOrEqualTo(previous), reason: '$degrees°, sensibilité $value');
          previous = speed;
        }
      }
    });

    test('monotone : plus incliné = plus rapide', () {
      for (final value in [0, 50, 100]) {
        double previous = -1;
        for (double degrees = 0; degrees <= 90; degrees += 1) {
          final double speed = PaddleSensitivity.speedAtDegrees(value, degrees);
          expect(speed, greaterThanOrEqualTo(previous));
          previous = speed;
        }
      }
    });

    test('0 reste jouable : le terrain traversé en moins de 5 s à 30°', () {
      final double speed = PaddleSensitivity.speedAtDegrees(0, 30);
      expect(2 / speed, lessThan(5.0));
      expect(PaddleSensitivity.maxSpeed(0), greaterThanOrEqualTo(1.0));
    });

    test("valeur par défaut plus rapide que l'ancien « Normale »", () {
      const value = PaddleSensitivity.defaultValue;
      for (final degrees in [10.0, 15.0, 30.0, 45.0, 60.0]) {
        expect(PaddleSensitivity.speedAtDegrees(value, degrees), greaterThan(oldNormalAt(degrees)),
            reason: '$degrees°');
      }
    });

    test('plafond du duel = vitesse maximale du réglage 100', () {
      expect(GameTuning.paddleSpeedCap, PaddleSensitivity.maxSpeed(100));
      for (int value = 0; value <= 100; value++) {
        expect(PaddleSensitivity.maxSpeed(value), lessThanOrEqualTo(GameTuning.paddleSpeedCap));
      }
    });
  });

  group('Anciens crans (0 à 4)', () {
    test('conversion croissante, dans 0..100', () {
      final values = [for (int notch = 0; notch < 5; notch++) PaddleSensitivity.fromLegacyNotch(notch)!];
      expect(values, [20, 35, 50, 65, 80]);
      for (int i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });

    test("l'ancien « Normale » devient le défaut, et chaque cran va au moins aussi vite qu'avant", () {
      expect(PaddleSensitivity.fromLegacyNotch(2), GameTuning.paddleSensitivityDefault);
      const multipliers = [0.6, 0.8, 1.0, 1.25, 1.5];
      for (int notch = 0; notch < 5; notch++) {
        final double old = oldNormalAt(30) * multipliers[notch];
        final double now = PaddleSensitivity.speedAtDegrees(PaddleSensitivity.fromLegacyNotch(notch)!, 30);
        expect(now, greaterThanOrEqualTo(old), reason: 'cran $notch');
      }
    });

    test('cran inconnu : null', () {
      expect(PaddleSensitivity.fromLegacyNotch(-1), isNull);
      expect(PaddleSensitivity.fromLegacyNotch(5), isNull);
    });
  });
}
