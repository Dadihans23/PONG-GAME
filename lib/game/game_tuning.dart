/// Réglages de rythme communs au solo et au duel, sans dépendance à Flutter.
///
/// Ces valeurs ont été réglées au ressenti avec le propriétaire sur un vrai
/// téléphone (SM-A135F) : ne pas les changer sans un nouveau test sur
/// l'appareil. Le duel doit utiliser exactement les mêmes que le solo, pour
/// que la balle et les raquettes aient la même vitesse dans les deux modes.
///
/// `lib/hompage.dart` a encore ses propres copies de ces constantes ; elles
/// sont identiques et devront pointer ici lors d'une prochaine modification
/// de l'écran de jeu solo.
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
}
