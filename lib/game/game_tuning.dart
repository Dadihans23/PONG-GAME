/// Réglages de rythme communs au solo et au duel, sans dépendance à Flutter.
///
/// Ces valeurs ont été réglées au ressenti avec le propriétaire sur un vrai
/// téléphone (SM-A135F) : ne pas les changer sans un nouveau test sur
/// l'appareil. Le duel doit utiliser exactement les mêmes que le solo, pour
/// que la balle et les raquettes aient la même vitesse dans les deux modes.
///
/// Utilisées par l'écran solo (`lib/hompage.dart`), le contrôleur du duel et
/// le parcours multijoueur (`lib/multiplayer/multiplayer_flow.dart`).
abstract final class GameTuning {
  /// Pas de moteur par seconde : règle la vitesse de tout le jeu (balle,
  /// raquettes, accélération), identique sur tous les téléphones.
  static const int stepsPerSecond = 450;

  /// Vitesse maximale d'une raquette, en unités de terrain par seconde (le
  /// terrain fait 2 unités de large) : 1,18 d'origine + 20 %.
  static const double paddleMaxSpeed = 1.42;

  /// Pas de moteur joués au plus par image : au-delà, le temps en trop est
  /// abandonné pour que la balle ne saute pas après un blocage de l'écran.
  static const int maxStepsPerFrame = 50;

  // --- Inclinaison du téléphone → vitesse de la raquette (`TiltControl`) ---
  // L'inclinaison est normalisée : 0 = téléphone droit, 1 = téléphone couché
  // sur le côté (90°).

  /// Inclinaison qui donne la vitesse maximale. La baisser (0,5 = 30°) rend
  /// la raquette plus vive sans changer sa vitesse maximale.
  static const double tiltForMaxSpeed = 1.0;

  /// Zone morte : sous cette inclinaison (0,05 = environ 3°) la raquette ne
  /// bouge pas ; au-delà, la vitesse part de 0 et croît linéairement.
  static const double tiltDeadZone = 0.05;

  /// Lissage de l'inclinaison, en secondes : plus grand = plus doux mais
  /// plus de retard, 0 = aucun lissage.
  static const double tiltSmoothingTime = 0.05;

  /// Période de lecture de l'accéléromètre : 20 ms = 50 mesures par seconde.
  static const Duration sensorPeriod = Duration(milliseconds: 20);
}
