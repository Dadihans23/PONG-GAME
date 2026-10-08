import 'dart:math';

import 'game_tuning.dart';
import 'tilt_control.dart';

/// Sensibilité de la raquette choisie par le joueur, de 0 (douce) à 100
/// (vive), sans dépendance à Flutter.
///
/// Un seul nombre règle ensemble la vitesse maximale de la raquette et
/// l'inclinaison qui l'atteint (constantes dans [GameTuning]) : plus haut =
/// plus rapide et moins d'effort. Utilisée en solo, en duel et dans la zone
/// d'essai des Réglages.
///
/// ```dart
/// final tilt = PaddleSensitivity.tiltControl(settings.paddleSensitivity);
/// ```
abstract final class PaddleSensitivity {
  /// Valeur la plus douce.
  static const int min = 0;

  /// Valeur la plus vive.
  static const int max = 100;

  /// Valeur par défaut.
  static const int defaultValue = GameTuning.paddleSensitivityDefault;

  /// [value] ramenée dans [min]..[max].
  static int clamp(int value) => value.clamp(min, max).toInt();

  // Position de [value] entre 0 et 1
  static double _t(int value) => (clamp(value) - min) / (max - min);

  /// Vitesse maximale de la raquette, en unités de terrain par seconde.
  static double maxSpeed(int value) =>
      GameTuning.paddleMaxSpeedAtMin +
      (GameTuning.paddleMaxSpeedAtMax - GameTuning.paddleMaxSpeedAtMin) * _t(value);

  /// Inclinaison du téléphone, en degrés, qui donne la vitesse maximale.
  static double fullTiltDegrees(int value) =>
      GameTuning.tiltDegreesForMaxSpeedAtMin +
      (GameTuning.tiltDegreesForMaxSpeedAtMax - GameTuning.tiltDegreesForMaxSpeedAtMin) * _t(value);

  /// Même inclinaison, normalisée (sinus de l'angle, comme
  /// [TiltControl.normalizedTilt]).
  static double fullTilt(int value) => sin(fullTiltDegrees(value) * pi / 180);

  /// Commande d'inclinaison réglée pour [value].
  static TiltControl tiltControl(int value) => TiltControl(
        maxSpeed: maxSpeed(value),
        deadZone: GameTuning.tiltDeadZone,
        fullTilt: fullTilt(value),
        smoothingTime: GameTuning.tiltSmoothingTime,
        exponent: GameTuning.tiltCurveExponent,
      );

  /// Vitesse de la raquette, en unités de terrain par seconde, pour un
  /// téléphone tenu penché de [degrees] (sans lissage).
  static double speedAtDegrees(int value, double degrees) =>
      tiltControl(value).speedFor(sin(degrees * pi / 180));

  /// Valeur 0 à 100 équivalente à un ancien cran (0 à 4) ; un cran inconnu
  /// donne `null`.
  static int? fromLegacyNotch(int notch) {
    const values = GameTuning.legacySensitivityValues;
    if (notch < 0 || notch >= values.length) return null;
    return values[notch];
  }
}
