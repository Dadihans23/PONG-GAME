enum BallDirection { up, down, left, right }

/// Physique de la balle commune au solo ([PongEngine]) et au duel
/// ([DuelEngine]), sans dépendance à Flutter.
///
/// Terrain vertical en coordonnées normalisées (-1 à 1) : raquette du bas à
/// `y = 1`, raquette du haut à `y = -1`. Toutes les vitesses sont en unités de
/// terrain par pas de moteur. La base ne décide ni du score ni de la fin de
/// partie : chaque mode appelle ces briques dans son propre `tick()`.
abstract class PongPhysics {
  static const double initialBallSpeed = 0.002;
  static const double paddleHitZone = 0.85;
  // Gain de vitesse verticale à chaque accélération de la balle
  static const double speedUpStep = 0.0005;
  // Rebond angulaire : vitesse horizontale maximale (bord de la raquette)
  // en multiple de la vitesse verticale
  static const double bounceFactor = 1.5;

  double ballX = 0.0;
  double ballY = 0.0;
  double ballSpeedX = initialBallSpeed;
  double ballSpeedY = initialBallSpeed;
  BallDirection ballYDirection = BallDirection.down;
  BallDirection ballXDirection = BallDirection.left;

  // Nombre d'accélérations de la balle depuis le dernier service à vitesse de départ
  int speedUps = 0;

  int _hitsCounter = 0; // Renvois depuis la dernière accélération

  /// Demi-largeur de la zone de contact des raquettes, en unités de terrain.
  double get paddleHalfWidth;

  /// Niveau de vitesse affiché (« VITESSE n ») : 1 au service, +1 à chaque
  /// accélération.
  int get speedLevel => speedUps + 1;

  /// Renvois depuis la dernière accélération : la balle accélère au renvoi
  /// qui atteint le seuil passé à [countHit].
  int get hitsSinceSpeedUp => _hitsCounter;

  /// La balle est-elle dans la largeur de contact de la raquette centrée en [paddleX] ?
  bool isOnPaddle(double paddleX) {
    double x1 = paddleX - paddleHalfWidth;
    double x2 = paddleX + paddleHalfWidth;
    return ballX >= x1 && ballX <= x2;
  }

  /// Compte un renvoi ; la balle accélère tous les [hitsPerSpeedUp] renvois.
  void countHit(int hitsPerSpeedUp) {
    _hitsCounter++;
    if (_hitsCounter >= hitsPerSpeedUp) {
      ballSpeedY += speedUpStep; // Augmenter la vitesse de la balle
      _hitsCounter = 0; // Reset le compteur de renvois
      speedUps++;
    }
  }

  /// Vitesses de départ, accélérations remises à zéro.
  void resetSpeed() {
    ballSpeedX = initialBallSpeed;
    ballSpeedY = initialBallSpeed;
    _hitsCounter = 0;
    speedUps = 0;
  }

  // Rebond angulaire basé sur la position de l'impact
  void bounceOffPaddle(double paddleX) {
    double hitOffset = (ballX - paddleX) / paddleHalfWidth; // -1 à 1
    ballSpeedX = hitOffset.abs() * ballSpeedY * bounceFactor;
    if (hitOffset > 0) {
      ballXDirection = BallDirection.right;
    } else if (hitOffset < 0) {
      ballXDirection = BallDirection.left;
    }
  }

  /// Rebond sur les murs latéraux.
  void bounceOffWalls() {
    if (ballX >= 1) {
      ballXDirection = BallDirection.left;
    } else if (ballX <= -1) {
      ballXDirection = BallDirection.right;
    }
  }

  void moveBall() {
    // update vertical move
    if (ballYDirection == BallDirection.down) {
      ballY += ballSpeedY;
    } else if (ballYDirection == BallDirection.up) {
      ballY -= ballSpeedY;
    }

    // update horizontal move
    if (ballXDirection == BallDirection.right) {
      ballX += ballSpeedX;
    } else if (ballXDirection == BallDirection.left) {
      ballX -= ballSpeedX;
    }

    // Clamp ball position to prevent skipping past paddles
    ballY = ballY.clamp(-1.0, 1.0);
    ballX = ballX.clamp(-1.0, 1.0);
  }
}
