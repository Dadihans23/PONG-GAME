import 'dart:math';

enum BallDirection { up, down, left, right }

enum PongEvent { playerHit, enemyHit, enemyMissed, playerDead }

/// Logique du Pong, sans dépendance à Flutter.
/// Terrain vertical en coordonnées normalisées (-1 à 1) : joueur en bas, ennemi en haut.
class PongEngine {
  PongEngine({required this.difficulty, Random? random}) : _random = random ?? Random();

  static const double initialBallSpeed = 0.002;
  static const double paddleHitZone = 0.85;

  final String difficulty;
  final Random _random;

  double ballX = 0.0;
  double ballY = 0.0;
  double ballSpeedX = initialBallSpeed;
  double ballSpeedY = initialBallSpeed;
  BallDirection ballYDirection = BallDirection.down;
  BallDirection ballXDirection = BallDirection.left;

  double playerX = 0;
  // Déplacement de la raquette du joueur à chaque pas (négatif vers la gauche),
  // fourni par l'appelant : la raquette suit la même horloge que la balle
  double playerSpeed = 0.0;
  double enemyX = 0;
  // Demi-largeur de la zone de contact des paddles, fournie par l'appelant
  double paddleHalfWidth = 0.3;

  int playerScore = 0;
  int currentStreak = 0;

  int _hitsCounter = 0; // Compteur pour le nombre de fois que le joueur renvoie la balle
  double _enemyOffset = 0.0;
  bool _ballChangedDirection = false;

  bool get isPlayerDead => ballY >= 1;

  void movePlayer(double movement) {
    playerX = (playerX + movement).clamp(-1.0, 1.0);
  }

  /// Avance le jeu d'un tick et retourne ce qui s'est passé pendant ce tick.
  List<PongEvent> tick() {
    final events = <PongEvent>[];
    if (playerSpeed != 0) {
      movePlayer(playerSpeed);
    }
    _moveEnemy();
    _updateDirection(events);
    _moveBall();
    if (isPlayerDead) {
      events.add(PongEvent.playerDead);
    }
    return events;
  }

  void reset() {
    ballX = 0.0;
    ballY = 0.0;
    playerScore = 0;
    _hitsCounter = 0;
    ballXDirection = BallDirection.left;
    ballSpeedX = initialBallSpeed;
    ballSpeedY = initialBallSpeed;
    playerX = 0;
    playerSpeed = 0.0;
    _enemyOffset = 0.0;
    currentStreak = 0;
  }

  void _moveEnemy() {
    double targetX = ballX + _enemyOffset;

    if (difficulty == 'Facile') {
      // Slow speed, large random offset that changes occasionally
      _trackBall(targetX, maxSpeed: 0.01, rerollChance: 60, offsetRange: 0.6);
    } else if (difficulty == 'Normal') {
      // Medium speed, small random offset
      _trackBall(targetX, maxSpeed: 0.03, rerollChance: 40, offsetRange: 0.3);
    } else {
      // Difficile: near-perfect tracking with tiny offset
      _trackBall(targetX, maxSpeed: 0.05, rerollChance: 100, offsetRange: 0.08);
    }

    enemyX = enemyX.clamp(-1.0, 1.0);
  }

  void _trackBall(double targetX, {required double maxSpeed, required int rerollChance, required double offsetRange}) {
    if (_random.nextInt(rerollChance) == 0) {
      _enemyOffset = (_random.nextDouble() - 0.5) * offsetRange;
    }
    double diff = targetX - enemyX;
    if (diff.abs() > maxSpeed) {
      enemyX += diff > 0 ? maxSpeed : -maxSpeed;
    } else {
      enemyX = targetX;
    }
  }

  void _updateDirection(List<PongEvent> events) {
    double x1 = playerX - paddleHalfWidth;
    double x2 = playerX + paddleHalfWidth;

    // update vertical direction — use wider zone to prevent ball skipping past paddle at high speed
    if (ballY >= paddleHitZone && ballYDirection == BallDirection.down && ballX >= x1 && ballX <= x2) {
      if (!_ballChangedDirection) {
        ballYDirection = BallDirection.up;
        playerScore += 50; // Incrémenter le score du joueur de 50
        _ballChangedDirection = true;

        _applyAngularBounce(playerX);

        currentStreak++;
        _hitsCounter++;
        if (_hitsCounter > 3) {
          ballSpeedY += 0.0005; // Augmenter la vitesse de la balle
          _hitsCounter = 0; // Reset le compteur de renvois
        }

        events.add(PongEvent.playerHit);
      }
    } else if (ballY <= -paddleHitZone && ballYDirection == BallDirection.up) {
      // Check if enemy paddle is aligned with ball
      double enemyX1 = enemyX - paddleHalfWidth;
      double enemyX2 = enemyX + paddleHalfWidth;

      if (ballX >= enemyX1 && ballX <= enemyX2) {
        // Enemy catches it, ball bounces back down
        ballYDirection = BallDirection.down;
        _applyAngularBounce(enemyX);
        events.add(PongEvent.enemyHit);
      } else {
        // Enemy missed! Player scores, reset ball
        playerScore += 100;
        ballX = 0.0;
        ballY = 0.0;
        ballSpeedX = initialBallSpeed;
        ballYDirection = BallDirection.down;
        _enemyOffset = 0.0;
        events.add(PongEvent.enemyMissed);
      }
    } else {
      _ballChangedDirection = false; // Reset when the ball is not hitting the player's paddle
    }

    // update horizontal direction
    if (ballX >= 1) {
      ballXDirection = BallDirection.left;
    } else if (ballX <= -1) {
      ballXDirection = BallDirection.right;
    }
  }

  // Rebond angulaire basé sur la position de l'impact
  void _applyAngularBounce(double paddleX) {
    double hitOffset = (ballX - paddleX) / paddleHalfWidth; // -1 à 1
    ballSpeedX = hitOffset.abs() * ballSpeedY * 1.5;
    if (hitOffset > 0) {
      ballXDirection = BallDirection.right;
    } else if (hitOffset < 0) {
      ballXDirection = BallDirection.left;
    }
  }

  void _moveBall() {
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
