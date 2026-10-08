import 'dart:math';

import 'package:pong_game/multiplayer/model/duel_phase.dart';
import 'package:pong_game/multiplayer/model/game_state.dart';
import 'package:pong_game/multiplayer/model/player.dart';

import 'pong_physics.dart';

export 'pong_physics.dart' show BallDirection;

enum DuelEventType {
  /// Le joueur a renvoyé la balle.
  paddleHit,

  /// Le joueur a marqué un point.
  pointScored,

  /// Le joueur a gagné la partie (émis juste après son dernier [pointScored]).
  gameWon,

  /// Fin de la pause avant le service : la balle part vers ce joueur.
  served,
}

/// Événement d'un pas du duel, et le joueur concerné.
class DuelEvent {
  const DuelEvent(this.type, this.player);

  const DuelEvent.paddleHit(this.player) : type = DuelEventType.paddleHit;
  const DuelEvent.pointScored(this.player) : type = DuelEventType.pointScored;
  const DuelEvent.gameWon(this.player) : type = DuelEventType.gameWon;
  const DuelEvent.served(this.player) : type = DuelEventType.served;

  final DuelEventType type;
  final PlayerSlot player;

  @override
  bool operator ==(Object other) => other is DuelEvent && other.type == type && other.player == player;

  @override
  int get hashCode => Object.hash(type, player);

  @override
  String toString() => 'DuelEvent(${type.name}, ${player.name})';
}

/// Moteur du duel, sans dépendance à Flutter ni au réseau. Tourne sur le
/// téléphone Host, qui fait autorité.
///
/// Même physique que le solo ([PongPhysics]) : balle, rebond angulaire,
/// accélération. Joueur 1 (Host) en bas, joueur 2 (Client) en haut ; les deux
/// raquettes sont pilotées par des entrées, sans IA :
/// - joueur 1 : vitesse par pas [player1Speed], comme `playerSpeed` en solo ;
/// - joueur 2 : position cible reçue du réseau ([setPlayer2Target]), rejointe
///   à vitesse plafonnée.
/// Chaque raquette a sa propre vitesse maximale, celle de la sensibilité de
/// son joueur ([setPaddleMaxSpeed]), comme au tennis : chacun garde son
/// réglage. Aucune ne dépasse le plafond commun [maxPaddleStep].
class DuelEngine extends PongPhysics {
  /// [stepsPerSecond] : pas de moteur par seconde, le même que le solo.
  /// [paddleMaxSpeed] : plafond commun des deux raquettes, en unités de
  /// terrain par seconde (`GameTuning.paddleSpeedCap`). Tant que
  /// [setPaddleMaxSpeed] n'est pas appelée, chaque raquette peut l'atteindre.
  DuelEngine({required this.stepsPerSecond, required double paddleMaxSpeed, Random? random})
      : assert(stepsPerSecond > 0),
        assert(paddleMaxSpeed > 0),
        serveDelayTicks = (stepsPerSecond * serveDelaySeconds).round(),
        maxPaddleStep = paddleMaxSpeed / stepsPerSecond,
        _random = random ?? Random() {
    _player1MaxStep = maxPaddleStep;
    _player2MaxStep = maxPaddleStep;
    reset();
  }

  /// Premier à ce nombre de points : gagnant.
  static const int pointsToWin = duelPointsToWin;

  /// Demi-largeur de contact des raquettes, en unités de terrain, identique
  /// sur tous les téléphones. Proche du solo sur le téléphone du propriétaire
  /// (raquette de 80 dp sur un terrain de 296 dp : 80 / 296 + 0,10 ≈ 0,37).
  static const double contactHalfWidth = 0.37;

  /// Tolérance de contact au-delà du bord dessiné (la même qu'en solo).
  static const double contactMargin = 0.10;

  /// Demi-largeur dessinée de la raquette, en unités de terrain : l'écran
  /// dessine une raquette de `visualHalfWidth × largeur du terrain` pixels.
  static const double visualHalfWidth = contactHalfWidth - contactMargin;

  /// Renvois (des deux joueurs confondus) entre deux accélérations : 8, soit
  /// 4 renvois de chaque joueur dans un échange, le même rythme qu'en solo
  /// (4 renvois du joueur, autant de l'IA).
  static const int hitsPerSpeedUp = 8;

  /// Pause avant chaque service qui suit un point : le temps d'afficher
  /// « Point pour X » et « Reprise dans 2… » (maquette D2).
  static const double serveDelaySeconds = 2.0;

  /// Pas de moteur par seconde.
  final int stepsPerSecond;

  /// Durée de la pause avant service, en pas de moteur.
  final int serveDelayTicks;

  /// Plafond commun : déplacement maximal d'une raquette par pas.
  final double maxPaddleStep;

  // Déplacement maximal par pas propre à chaque raquette (≤ maxPaddleStep)
  late double _player1MaxStep;
  late double _player2MaxStep;

  final Random _random;

  double player1X = 0;
  double player2X = 0;

  /// Déplacement voulu de la raquette du joueur 1 à chaque pas (négatif vers
  /// la gauche), plafonné à sa vitesse maximale ([maxStepOf]).
  double player1Speed = 0.0;
  double _player2Target = 0;

  int score1 = 0;
  int score2 = 0;

  /// Pas joués depuis [reset] (le numéro de pas de [GameState]).
  int tickCount = 0;

  /// Pas restants avant que la balle reparte ; 0 pendant le jeu.
  int serveTicksRemaining = 0;

  /// Renvois de l'échange en cours, remis à zéro à chaque service.
  int rally = 0;

  /// Plus long échange de la partie, en renvois.
  int longestRally = 0;

  /// Renvois des deux joueurs depuis [reset].
  int totalHits = 0;

  /// Auteur du dernier point, `null` avant le premier.
  PlayerSlot? lastScorer;

  PlayerSlot? _winner;

  @override
  double get paddleHalfWidth => contactHalfWidth;

  /// Gagnant, ou `null` tant que la partie continue.
  PlayerSlot? get winner => _winner;
  bool get isFinished => _winner != null;
  bool get isServing => serveTicksRemaining > 0;

  /// Temps de jeu depuis [reset], en temps de moteur (pauses de service
  /// comprises).
  Duration get elapsed => Duration(microseconds: tickCount * 1000000 ~/ stepsPerSecond);

  /// Temps restant de la pause avant service, en millisecondes (arrondi au
  /// supérieur : 0 seulement quand la balle est en jeu).
  int get serveRemainingMs => (serveTicksRemaining * 1000 + stepsPerSecond - 1) ~/ stepsPerSecond;

  /// Dernière position reçue pour la raquette du joueur 2.
  double get player2Target => _player2Target;

  int scoreOf(PlayerSlot player) => player == PlayerSlot.player1 ? score1 : score2;

  double paddleOf(PlayerSlot player) => player == PlayerSlot.player1 ? player1X : player2X;

  /// Déplacement maximal par pas de la raquette de [player].
  double maxStepOf(PlayerSlot player) => player == PlayerSlot.player1 ? _player1MaxStep : _player2MaxStep;

  /// Vitesse maximale de la raquette de [player], en unités de terrain par
  /// seconde (celle de la sensibilité du joueur). Bornée au plafond commun ;
  /// une valeur non finie ou ≤ 0 est ignorée. Gardée par [reset] : elle vaut
  /// pour toute la session, revanches comprises.
  void setPaddleMaxSpeed(PlayerSlot player, double unitsPerSecond) {
    if (!unitsPerSecond.isFinite || unitsPerSecond <= 0) return;
    final double step = min(unitsPerSecond / stepsPerSecond, maxPaddleStep);
    if (player == PlayerSlot.player1) {
      _player1MaxStep = step;
    } else {
      _player2MaxStep = step;
    }
  }

  /// Position de la raquette du joueur 2 reçue du réseau, en coordonnées du
  /// terrain. Bornée à -1..1 ; une valeur non finie est ignorée.
  void setPlayer2Target(double x) {
    if (!x.isFinite) return;
    _player2Target = x.clamp(-1.0, 1.0);
  }

  /// Nouvelle partie : scores à zéro, raquettes au centre, premier service
  /// tiré au sort et immédiat (le compte à rebours du salon le précède).
  void reset() {
    score1 = 0;
    score2 = 0;
    _winner = null;
    tickCount = 0;
    rally = 0;
    longestRally = 0;
    totalHits = 0;
    lastScorer = null;
    player1X = 0;
    player2X = 0;
    player1Speed = 0.0;
    _player2Target = 0;
    _serve(_random.nextBool() ? PlayerSlot.player1 : PlayerSlot.player2);
    serveTicksRemaining = 0;
  }

  /// Avance le duel d'un pas et retourne ce qui s'est passé. Ne fait plus
  /// rien une fois la partie gagnée.
  List<DuelEvent> tick() {
    final events = <DuelEvent>[];
    if (isFinished) {
      return events;
    }
    tickCount++;
    _movePaddles();

    // Pause avant le service : balle immobile au centre, raquettes libres
    if (serveTicksRemaining > 0) {
      serveTicksRemaining--;
      if (serveTicksRemaining == 0) {
        events.add(DuelEvent.served(_receiver));
      }
      return events;
    }

    _updateDirection(events);
    moveBall();
    _checkPoint(events);
    return events;
  }

  /// État à envoyer au Client.
  GameState snapshot() => GameState(
        tick: tickCount,
        phase: isFinished ? DuelPhase.finished : DuelPhase.playing,
        ballX: ballX,
        ballY: ballY,
        ballVX: ballXDirection == BallDirection.right ? ballSpeedX : -ballSpeedX,
        ballVY: ballYDirection == BallDirection.down ? ballSpeedY : -ballSpeedY,
        paddle1X: player1X,
        paddle2X: player2X,
        score1: score1,
        score2: score2,
        serveMs: serveRemainingMs,
        lastScorer: lastScorer,
        rally: rally,
        longestRally: longestRally,
        hits: totalHits,
        timeMs: elapsed.inMilliseconds,
      );

  // Joueur vers qui la balle se dirige
  PlayerSlot get _receiver => ballYDirection == BallDirection.down ? PlayerSlot.player1 : PlayerSlot.player2;

  void _movePaddles() {
    final double step = player1Speed.clamp(-_player1MaxStep, _player1MaxStep);
    player1X = (player1X + step).clamp(-1.0, 1.0);

    // Le joueur 2 rejoint sa position reçue sans dépasser sa vitesse maximale :
    // pas de téléportation, mouvement continu entre deux messages
    final double diff = _player2Target - player2X;
    if (diff.abs() > _player2MaxStep) {
      player2X += diff > 0 ? _player2MaxStep : -_player2MaxStep;
    } else {
      player2X = _player2Target;
    }
  }

  void _updateDirection(List<DuelEvent> events) {
    if (ballY >= PongPhysics.paddleHitZone && ballYDirection == BallDirection.down && isOnPaddle(player1X)) {
      ballYDirection = BallDirection.up;
      bounceOffPaddle(player1X);
      _countRally();
      events.add(const DuelEvent.paddleHit(PlayerSlot.player1));
    } else if (ballY <= -PongPhysics.paddleHitZone && ballYDirection == BallDirection.up && isOnPaddle(player2X)) {
      ballYDirection = BallDirection.down;
      bounceOffPaddle(player2X);
      _countRally();
      events.add(const DuelEvent.paddleHit(PlayerSlot.player2));
    }
    bounceOffWalls();
  }

  void _countRally() {
    countHit(hitsPerSpeedUp);
    rally++;
    totalHits++;
    if (rally > longestRally) {
      longestRally = rally;
    }
  }

  // La balle a passé une raquette : point pour l'adversaire
  void _checkPoint(List<DuelEvent> events) {
    final PlayerSlot scorer;
    if (ballY >= 1) {
      scorer = PlayerSlot.player2;
    } else if (ballY <= -1) {
      scorer = PlayerSlot.player1;
    } else {
      return;
    }

    if (scorer == PlayerSlot.player1) {
      score1++;
    } else {
      score2++;
    }
    lastScorer = scorer;
    events.add(DuelEvent.pointScored(scorer));

    if (scoreOf(scorer) >= pointsToWin) {
      // La balle reste derrière la raquette du perdant
      _winner = scorer;
      events.add(DuelEvent.gameWon(scorer));
      return;
    }
    _serve(scorer.opponent);
  }

  // Balle au centre, vitesse de départ, direction vers [receiver], côté
  // gauche ou droit tiré au sort, puis pause avant le service
  void _serve(PlayerSlot receiver) {
    ballX = 0.0;
    ballY = 0.0;
    resetSpeed();
    rally = 0;
    ballYDirection = receiver == PlayerSlot.player1 ? BallDirection.down : BallDirection.up;
    ballXDirection = _random.nextBool() ? BallDirection.left : BallDirection.right;
    serveTicksRemaining = serveDelayTicks;
  }
}
