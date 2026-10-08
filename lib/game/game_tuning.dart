/// Réglages de rythme communs au solo et au duel, sans dépendance à Flutter.
///
/// Ces valeurs ont été réglées au ressenti avec le propriétaire sur un vrai
/// téléphone (SM-A135F) : ne pas les changer sans un nouveau test sur
/// l'appareil. Le duel doit utiliser exactement les mêmes que le solo, pour
/// que la balle et les raquettes aient la même vitesse dans les deux modes.
///
/// Utilisées par l'écran solo (`lib/hompage.dart`), le contrôleur du duel,
/// le parcours multijoueur (`lib/multiplayer/multiplayer_flow.dart`) et la
/// zone d'essai des Réglages.
abstract final class GameTuning {
  /// Pas de moteur par seconde : règle la vitesse de tout le jeu (balle,
  /// IA, accélération), identique sur tous les téléphones.
  static const int stepsPerSecond = 450;

  /// Pas de moteur joués au plus par image : au-delà, le temps en trop est
  /// abandonné pour que la balle ne saute pas après un blocage de l'écran.
  static const int maxStepsPerFrame = 50;

  // --- Inclinaison du téléphone → vitesse de la raquette (`TiltControl`) ---
  // L'inclinaison est normalisée : 0 = téléphone droit, 1 = téléphone couché
  // sur le côté (90°). Les vitesses sont en unités de terrain par seconde (le
  // terrain fait 2 unités de large).
  //
  // Le joueur choisit une sensibilité de 0 à 100 (`PaddleSensitivity`). Elle
  // règle ensemble la vitesse maximale et l'inclinaison qui l'atteint, par
  // interpolation linéaire entre les valeurs « à 0 » et « à 100 » ci-dessous.
  // Entre la zone morte et cette inclinaison, la vitesse suit une courbe :
  // vitesse max × ratio ^ [tiltCurveExponent], ratio allant de 0 (bord de la
  // zone morte) à 1 (inclinaison de la vitesse maximale).
  //
  // Réglées au ressenti avec le propriétaire : ne pas les changer sans un
  // test sur un vrai téléphone. Table de correspondance : CLAUDE.md, Input.

  /// Sensibilité par défaut (0 à 100), pour un joueur qui n'a rien réglé.
  /// Environ deux fois plus vive à 30° que l'ancien réglage « Normale ».
  static const int paddleSensitivityDefault = 50;

  /// Vitesse maximale à la sensibilité 0 : lente mais jouable. Les deux
  /// bornes ont été multipliées par 1,5 à la demande du propriétaire
  /// (raquette encore plus rapide) : 1,2 → 1,8 et 3,0 → 4,5.
  static const double paddleMaxSpeedAtMin = 1.8;

  /// Vitesse maximale à la sensibilité 100. C'est aussi le plafond commun du
  /// duel ([paddleSpeedCap]).
  static const double paddleMaxSpeedAtMax = 4.5;

  /// Inclinaison (en degrés) qui donne la vitesse maximale à la sensibilité 0.
  static const double tiltDegreesForMaxSpeedAtMin = 60;

  /// Inclinaison (en degrés) qui donne la vitesse maximale à la sensibilité
  /// 100 : moins d'effort pour aller vite.
  static const double tiltDegreesForMaxSpeedAtMax = 20;

  /// Exposant de la courbe de réponse. 1 = linéaire ; au-dessus de 1, les
  /// petites inclinaisons sont plus douces que les grandes, pour garder la
  /// précision (raquette facile à arrêter) même à haute sensibilité.
  static const double tiltCurveExponent = 1.5;

  /// Plafond commun du duel : aucune raquette ne va plus vite, quelle que
  /// soit la sensibilité annoncée.
  static const double paddleSpeedCap = paddleMaxSpeedAtMax;

  /// Zone morte : sous cette inclinaison (0,05 = environ 3°) la raquette ne
  /// bouge pas ; au-delà, la vitesse part de 0 et suit la courbe.
  static const double tiltDeadZone = 0.05;

  /// Lissage de l'inclinaison, en secondes : plus grand = plus doux mais
  /// plus de retard, 0 = aucun lissage.
  static const double tiltSmoothingTime = 0.05;

  /// Conversion des anciens crans (0 à 4 : Très douce, Douce, Normale, Vive,
  /// Très vive) en sensibilité 0 à 100. Choix du propriétaire : la base est
  /// plus rapide qu'avant, donc l'ancien « Normale » devient le nouveau
  /// défaut (50) et les autres crans restent à la même place relative.
  static const List<int> legacySensitivityValues = [20, 35, 50, 65, 80];

  /// Période de lecture de l'accéléromètre : 20 ms = 50 mesures par seconde.
  static const Duration sensorPeriod = Duration(milliseconds: 20);
}
