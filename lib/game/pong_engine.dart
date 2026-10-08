import 'dart:math';

import 'pong_physics.dart';

export 'pong_physics.dart' show BallDirection;

enum PongEvent { playerHit, enemyHit, enemyMissed, playerDead }

/// Logique du Pong, sans dépendance à Flutter.
/// Terrain vertical en coordonnées normalisées (-1 à 1) : joueur en bas, ennemi en haut.
/// La physique de la balle (déplacement, murs, rebond angulaire, accélération)
/// est partagée avec le duel dans [PongPhysics].
class PongEngine extends PongPhysics {
  PongEngine({required this.difficulty, Random? random}) : _random = random ?? Random();

  static const double initialBallSpeed = PongPhysics.initialBallSpeed;
  static const double paddleHitZone = PongPhysics.paddleHitZone;
  // Nombre de renvois du joueur entre deux accélérations de la balle
  static const int hitsPerSpeedUp = 4;

  final String difficulty;
  final Random _random;

  double playerX = 0;
  // Déplacement de la raquette du joueur à chaque pas (négatif vers la gauche),
  // fourni par l'appelant : la raquette suit la même horloge que la balle
  double playerSpeed = 0.0;
  double enemyX = 0;
  // Demi-largeur de la zone de contact des paddles, fournie par l'appelant
  @override
  double paddleHalfWidth = 0.3;

  int playerScore = 0;
  int currentStreak = 0;

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
    moveBall();
    if (isPlayerDead) {
      events.add(PongEvent.playerDead);
    }
    return events;
  }

  void reset() {
    ballX = 0.0;
    ballY = 0.0;
    playerScore = 0;
    ballXDirection = BallDirection.left;
    resetSpeed();
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
    // update vertical direction — use wider zone to prevent ball skipping past paddle at high speed
    if (ballY >= paddleHitZone && ballYDirection == BallDirection.down && isOnPaddle(playerX)) {
      if (!_ballChangedDirection) {
        ballYDirection = BallDirection.up;
        playerScore += 50; // Incrémenter le score du joueur de 50
        _ballChangedDirection = true;

        bounceOffPaddle(playerX);

        currentStreak++;
        countHit(hitsPerSpeedUp);

        events.add(PongEvent.playerHit);
      }
    } else if (ballY <= -paddleHitZone && ballYDirection == BallDirection.up) {
      // Check if enemy paddle is aligned with ball
      if (isOnPaddle(enemyX)) {
        // Enemy catches it, ball bounces back down
        ballYDirection = BallDirection.down;
        bounceOffPaddle(enemyX);
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
    bounceOffWalls();
  }
}
