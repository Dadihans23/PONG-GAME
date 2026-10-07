import 'dart:math';

/// Transforme l'inclinaison du téléphone en vitesse de raquette, sans
/// dépendance à Flutter ni au capteur.
///
/// Le capteur appelle [setAcceleration] à sa propre cadence ; l'écran appelle
/// [update] une fois par image. La vitesse obtenue ne dépend donc pas de la
/// cadence du capteur.
class TiltControl {
  TiltControl({
    required this.maxSpeed,
    required this.deadZone,
    required this.fullTilt,
    required this.smoothingTime,
  });

  /// Vitesse de la raquette à pleine inclinaison, en unités de terrain par seconde.
  final double maxSpeed;

  /// Inclinaison normalisée (0 à 1) sous laquelle la raquette ne bouge pas.
  final double deadZone;

  /// Inclinaison normalisée (0 à 1) à partir de laquelle la vitesse est maximale.
  final double fullTilt;

  /// Constante de temps du lissage, en secondes (0 : pas de lissage).
  final double smoothingTime;

  double _tilt = 0.0; // Dernière inclinaison reçue du capteur, de -1 à 1
  double _smoothedTilt = 0.0; // Inclinaison lissée, de -1 à 1

  double get smoothedTilt => _smoothedTilt;

  /// Inclinaison gauche/droite normalisée, de -1 à 1 : -x / norme du vecteur.
  /// Positive quand le téléphone penche vers la droite. Indépendante de la
  /// valeur de la gravité mesurée par le capteur.
  static double normalizedTilt(double x, double y, double z) {
    final double norm = sqrt(x * x + y * y + z * z);
    if (norm == 0) {
      return 0.0;
    }
    return (-x / norm).clamp(-1.0, 1.0);
  }

  /// Mémorise la dernière mesure de l'accéléromètre. Ne déplace rien.
  void setAcceleration(double x, double y, double z) {
    _tilt = normalizedTilt(x, y, z);
  }

  /// Recale le lissage sur l'inclinaison actuelle : à appeler quand la partie
  /// démarre ou reprend, pour ne pas repartir d'une valeur ancienne.
  void reset() {
    _smoothedTilt = _tilt;
  }

  /// Avance le lissage de [dt] secondes et retourne la vitesse de la raquette
  /// en unités de terrain par seconde (négative vers la gauche).
  double update(double dt) {
    if (smoothingTime <= 0) {
      _smoothedTilt = _tilt;
    } else if (dt > 0) {
      // Passe-bas calculé avec le temps réel écoulé : même réponse quelle que
      // soit la cadence d'affichage
      final double alpha = 1 - exp(-dt / smoothingTime);
      _smoothedTilt += (_tilt - _smoothedTilt) * alpha;
    }
    return speedFor(_smoothedTilt);
  }

  /// Vitesse pour une inclinaison normalisée [tilt] : nulle dans la zone
  /// morte, puis linéaire de 0 (au seuil) à [maxSpeed] (à [fullTilt]).
  double speedFor(double tilt) {
    final double amount = tilt.abs();
    if (amount <= deadZone) {
      return 0.0;
    }
    final double ratio = ((amount - deadZone) / (fullTilt - deadZone)).clamp(0.0, 1.0);
    return tilt > 0 ? maxSpeed * ratio : -maxSpeed * ratio;
  }
}
