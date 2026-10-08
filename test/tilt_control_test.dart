import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/tilt_control.dart';

const double g = 9.81;

// Réglages de la première version : vitesse maximale 1.18 unité/s à pleine
// inclinaison, zone morte 0.05, lissage 50 ms
TiltControl newControl({double smoothingTime = 0.05, double fullTilt = 1.0}) {
  return TiltControl(
    maxSpeed: 1.18,
    deadZone: 0.05,
    fullTilt: fullTilt,
    smoothingTime: smoothingTime,
  );
}

// Mesure de l'accéléromètre pour un téléphone tenu droit et penché de
// [degrees] vers la droite
void tiltRight(TiltControl control, double degrees, {double gravity = g}) {
  final double angle = degrees * pi / 180;
  control.setAcceleration(-gravity * sin(angle), gravity * cos(angle), 0);
}

void main() {
  group('Inclinaison normalisée', () {
    test('téléphone droit ou à plat : 0', () {
      expect(TiltControl.normalizedTilt(0, g, 0), 0.0);
      expect(TiltControl.normalizedTilt(0, 0, g), 0.0);
    });

    test('penché à droite : positif ; à gauche : négatif', () {
      expect(TiltControl.normalizedTilt(-g, 0, 0), closeTo(1.0, 1e-12));
      expect(TiltControl.normalizedTilt(g, 0, 0), closeTo(-1.0, 1e-12));
    });

    test('30° donne 0.5, quelle que soit la gravité mesurée', () {
      for (final gravity in [9.0, 9.81, 10.5]) {
        const double angle = 30 * pi / 180;
        final double tilt = TiltControl.normalizedTilt(-gravity * sin(angle), gravity * cos(angle), 0);
        expect(tilt, closeTo(0.5, 1e-12), reason: 'gravité $gravity');
      }
    });

    test('vecteur nul : 0, pas de division par zéro', () {
      expect(TiltControl.normalizedTilt(0, 0, 0), 0.0);
    });
  });

  group('Zone morte et vitesse', () {
    test('vitesse nulle dans la zone morte et à son seuil', () {
      final control = newControl();
      expect(control.speedFor(0.0), 0.0);
      expect(control.speedFor(0.03), 0.0);
      expect(control.speedFor(-0.03), 0.0);
      expect(control.speedFor(0.05), 0.0);
    });

    test('zone morte progressive : la vitesse part de 0 au seuil', () {
      final control = newControl();
      expect(control.speedFor(0.051), closeTo(1.18 * 0.001 / 0.95, 1e-9));
      expect(control.speedFor(0.051), lessThan(0.002));
    });

    test('vitesse linéaire entre le seuil et la pleine inclinaison', () {
      final control = newControl();
      expect(control.speedFor(0.525), closeTo(1.18 * 0.5, 1e-9));
      expect(control.speedFor(0.5), closeTo(1.18 * 0.45 / 0.95, 1e-9));
    });

    test('vitesse maximale à pleine inclinaison, jamais dépassée', () {
      final control = newControl();
      expect(control.speedFor(1.0), closeTo(1.18, 1e-12));
      expect(control.speedFor(-1.0), closeTo(-1.18, 1e-12));
      expect(control.speedFor(1.5), closeTo(1.18, 1e-12));
    });

    test('symétrique à gauche et à droite', () {
      final control = newControl();
      expect(control.speedFor(-0.4), closeTo(-control.speedFor(0.4), 1e-12));
    });

    test('fullTilt plus bas : vitesse maximale atteinte plus tôt', () {
      final control = newControl(fullTilt: 0.5);
      expect(control.speedFor(0.5), closeTo(1.18, 1e-12));
      expect(control.speedFor(0.8), closeTo(1.18, 1e-12));
      expect(control.speedFor(0.275), closeTo(1.18 * 0.5, 1e-9));
    });
  });

  group('Courbe de réponse (exposant)', () {
    TiltControl curved(double exponent) => TiltControl(
          maxSpeed: 2.0,
          deadZone: 0.05,
          fullTilt: 0.55,
          smoothingTime: 0,
          exponent: exponent,
        );

    test('exposant 1 : linéaire, comme avant', () {
      expect(curved(1).speedFor(0.3), closeTo(2.0 * 0.5, 1e-12));
    });

    test('exposant 1,5 : ratio ^ 1,5 entre le seuil et la pleine inclinaison', () {
      final control = curved(1.5);
      expect(control.speedFor(0.3), closeTo(2.0 * pow(0.5, 1.5), 1e-12));
      expect(control.speedFor(-0.3), closeTo(-2.0 * pow(0.5, 1.5), 1e-12));
    });

    test('petites inclinaisons plus douces, mêmes bornes', () {
      final linear = curved(1);
      final soft = curved(1.5);
      expect(soft.speedFor(0.05), 0.0);
      expect(soft.speedFor(0.55), closeTo(2.0, 1e-12));
      expect(soft.speedFor(0.9), closeTo(2.0, 1e-12));
      for (final tilt in [0.06, 0.1, 0.2, 0.3, 0.5]) {
        expect(soft.speedFor(tilt), lessThan(linear.speedFor(tilt)), reason: 'inclinaison $tilt');
      }
    });
  });

  group('Lissage', () {
    test('sans mesure du capteur : vitesse nulle', () {
      final control = newControl();
      expect(control.update(0.016), 0.0);
    });

    test('sans lissage : la vitesse suit tout de suite l\'inclinaison', () {
      final control = newControl(smoothingTime: 0);
      tiltRight(control, 90);
      expect(control.update(0.016), closeTo(1.18, 1e-9));
    });

    test('après une constante de temps : 63 % du chemin', () {
      final control = newControl();
      tiltRight(control, 90);
      control.update(0.05);
      expect(control.smoothedTilt, closeTo(1 - exp(-1), 1e-9));
    });

    test('même résultat à 60 ou 120 images par seconde', () {
      final at60 = newControl();
      final at120 = newControl();
      tiltRight(at60, 40);
      tiltRight(at120, 40);
      for (int i = 0; i < 6; i++) {
        at60.update(1 / 60);
      }
      for (int i = 0; i < 12; i++) {
        at120.update(1 / 120);
      }
      expect(at60.smoothedTilt, closeTo(at120.smoothedTilt, 1e-9));
    });

    test('converge vers l\'inclinaison du téléphone', () {
      final control = newControl();
      tiltRight(control, 30);
      double speed = 0;
      for (int i = 0; i < 60; i++) {
        speed = control.update(1 / 60);
      }
      expect(control.smoothedTilt, closeTo(0.5, 1e-6));
      expect(speed, closeTo(1.18 * 0.45 / 0.95, 1e-5));
    });

    test('la raquette s\'arrête quand le téléphone revient droit', () {
      final control = newControl();
      tiltRight(control, 45);
      for (int i = 0; i < 60; i++) {
        control.update(1 / 60);
      }
      tiltRight(control, 0);
      double speed = 1;
      for (int i = 0; i < 60; i++) {
        speed = control.update(1 / 60);
      }
      expect(speed, 0.0);
    });

    test('une image très longue ne dépasse pas l\'inclinaison réelle', () {
      final control = newControl();
      tiltRight(control, 30);
      control.update(5.0);
      expect(control.smoothedTilt, closeTo(0.5, 1e-9));
    });

    test('durée nulle ou négative : le lissage ne bouge pas', () {
      final control = newControl();
      tiltRight(control, 90);
      control.update(0.02);
      final double before = control.smoothedTilt;
      control.update(0);
      control.update(-0.01);
      expect(control.smoothedTilt, before);
    });

    test('reset recale le lissage sur l\'inclinaison actuelle', () {
      final control = newControl();
      tiltRight(control, 90);
      control.update(0.01);
      tiltRight(control, 0);
      control.reset();
      expect(control.smoothedTilt, closeTo(0.0, 1e-12));
      expect(control.update(0.016), 0.0);
    });
  });

  group('Indépendance de la cadence du capteur', () {
    // Distance parcourue en 1 s à 60 images par seconde, le capteur étant lu
    // toutes les [sensorEvery] images
    double distance(int sensorEvery) {
      final control = newControl();
      double x = 0;
      for (int frame = 0; frame < 60; frame++) {
        if (frame % sensorEvery == 0) {
          tiltRight(control, 30);
        }
        x += control.update(1 / 60) / 60;
      }
      return x;
    }

    test('même distance à 6 ou 60 mesures par seconde', () {
      expect(distance(10), closeTo(distance(1), 1e-9));
    });

    test('à 30°, environ 0.56 unité par seconde', () {
      // 1.18 × (0.5 - 0.05) / 0.95 = 0.559 en régime établi, un peu moins
      // sur la première seconde à cause du lissage
      expect(distance(1), inInclusiveRange(0.50, 0.56));
    });
  });
}
