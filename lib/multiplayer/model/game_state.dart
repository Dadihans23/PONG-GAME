import 'duel_phase.dart';
import 'json_read.dart';
import 'player.dart';

/// Nombre de points pour gagner un duel.
const int duelPointsToWin = 5;

/// Photographie de la partie envoyée par le Host au Client.
///
/// Toujours en coordonnées du terrain du Host (-1 à 1, joueur 1 en bas) :
/// l'inversion pour le Client se fait à l'affichage (`DuelView`).
///
/// Format JSON :
/// ```json
/// {"tick": 1234, "phase": "playing",
///  "ball": {"x": 0.1, "y": -0.4, "vx": 0.002, "vy": -0.0025},
///  "paddles": {"p1": 0.3, "p2": -0.2},
///  "score": {"p1": 2, "p2": 1},
///  "serveMs": 1500, "lastScorer": "player1",
///  "rally": 0, "longestRally": 14, "hits": 37, "timeMs": 96000}
/// ```
///
/// Les six derniers champs ont été ajoutés après la première version : ils
/// sont **facultatifs** à la lecture (valeur par défaut s'ils manquent), mais
/// rejetés s'ils sont présents et invalides.
class GameState {
  const GameState({
    required this.tick,
    required this.phase,
    required this.ballX,
    required this.ballY,
    required this.ballVX,
    required this.ballVY,
    required this.paddle1X,
    required this.paddle2X,
    required this.score1,
    required this.score2,
    this.serveMs = 0,
    this.lastScorer,
    this.rally = 0,
    this.longestRally = 0,
    this.hits = 0,
    this.timeMs = 0,
  });

  /// Durée maximale acceptée pour la pause avant service, en millisecondes.
  static const int maxServeMs = 10000;

  /// Nombre maximal de renvois accepté à la lecture (borne de sécurité).
  static const int maxHits = 1000000;

  /// Vitesse de balle maximale acceptée à la lecture, par pas de moteur.
  /// Très au-dessus du jeu réel (0,002 au service, + 0,0005 par accélération,
  /// remise à zéro à chaque point) : elle ne sert qu'à rejeter un message absurde.
  static const double maxBallVelocity = 0.1;

  /// Numéro du pas de moteur du Host : permet d'ignorer un état plus ancien
  /// que le dernier reçu.
  final int tick;
  final DuelPhase phase;

  /// Position de la balle (-1 à 1) et vitesse signée par pas
  /// (vx > 0 vers la droite, vy > 0 vers le bas, c'est-à-dire vers le joueur 1).
  final double ballX;
  final double ballY;
  final double ballVX;
  final double ballVY;

  /// Centre des raquettes en X (-1 à 1) : joueur 1 en bas, joueur 2 en haut.
  final double paddle1X;
  final double paddle2X;

  final int score1;
  final int score2;

  /// Temps restant avant que la balle reparte, en millisecondes ; 0 quand la
  /// balle est en jeu. Pendant cette pause qui suit un point, l'écran
  /// affiche « Point pour X » et « Reprise dans n… ».
  final int serveMs;

  /// Auteur du dernier point, ou `null` avant le premier point.
  final PlayerSlot? lastScorer;

  /// Renvois de l'échange en cours (remis à zéro à chaque service).
  final int rally;

  /// Plus long échange de la partie, en renvois.
  final int longestRally;

  /// Renvois depuis le début de la partie, des deux joueurs : le Client y
  /// détecte un renvoi (son, vibration) quand ce nombre augmente.
  final int hits;

  /// Temps de jeu depuis le début de la partie, en millisecondes de moteur.
  final int timeMs;

  /// Pause avant service en cours ?
  bool get isServing => serveMs > 0;

  int scoreOf(PlayerSlot player) =>
      player == PlayerSlot.player1 ? score1 : score2;

  double paddleOf(PlayerSlot player) =>
      player == PlayerSlot.player1 ? paddle1X : paddle2X;

  /// Gagnant, ou `null` tant que personne n'a [duelPointsToWin] points.
  PlayerSlot? get winner {
    if (score1 >= duelPointsToWin) return PlayerSlot.player1;
    if (score2 >= duelPointsToWin) return PlayerSlot.player2;
    return null;
  }

  Map<String, dynamic> toJson() => {
        'tick': tick,
        'phase': phase.name,
        'ball': {'x': ballX, 'y': ballY, 'vx': ballVX, 'vy': ballVY},
        'paddles': {'p1': paddle1X, 'p2': paddle2X},
        'score': {'p1': score1, 'p2': score2},
        'serveMs': serveMs,
        'lastScorer': lastScorer?.name,
        'rally': rally,
        'longestRally': longestRally,
        'hits': hits,
        'timeMs': timeMs,
      };

  /// Lève une [FormatException] si [json] est invalide : champ manquant,
  /// mauvais type, valeur hors du terrain, score impossible.
  factory GameState.fromJson(Object? json) {
    final map = readObject(json, 'État de partie');
    final ball = readObject(map['ball'], 'Balle');
    final paddles = readObject(map['paddles'], 'Raquettes');
    final score = readObject(map['score'], 'Score');

    final int score1 = readInt(score, 'p1', min: 0, max: duelPointsToWin);
    final int score2 = readInt(score, 'p2', min: 0, max: duelPointsToWin);
    if (score1 == duelPointsToWin && score2 == duelPointsToWin) {
      throw const FormatException(
          'Score impossible : les deux joueurs ont gagné');
    }

    return GameState(
      // 2^53 : plus grand entier exact en JavaScript, borne prudente pour le réseau
      tick: readInt(map, 'tick', min: 0, max: 9007199254740992),
      phase: readEnum(map, 'phase', DuelPhase.values),
      ballX: readDouble(ball, 'x', min: -1, max: 1),
      ballY: readDouble(ball, 'y', min: -1, max: 1),
      ballVX:
          readDouble(ball, 'vx', min: -maxBallVelocity, max: maxBallVelocity),
      ballVY:
          readDouble(ball, 'vy', min: -maxBallVelocity, max: maxBallVelocity),
      paddle1X: readDouble(paddles, 'p1', min: -1, max: 1),
      paddle2X: readDouble(paddles, 'p2', min: -1, max: 1),
      score1: score1,
      score2: score2,
      serveMs: _optionalInt(map, 'serveMs', max: maxServeMs),
      lastScorer: map['lastScorer'] == null
          ? null
          : readEnum(map, 'lastScorer', PlayerSlot.values),
      rally: _optionalInt(map, 'rally', max: maxHits),
      longestRally: _optionalInt(map, 'longestRally', max: maxHits),
      hits: _optionalInt(map, 'hits', max: maxHits),
      timeMs: _optionalInt(map, 'timeMs', max: 9007199254740992),
    );
  }

  /// Champ entier facultatif : 0 s'il est absent (état d'une version
  /// antérieure), [FormatException] s'il est présent mais invalide.
  static int _optionalInt(Map<dynamic, dynamic> map, String key,
          {required int max}) =>
      map[key] == null ? 0 : readInt(map, key, min: 0, max: max);

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.tick == tick &&
      other.phase == phase &&
      other.ballX == ballX &&
      other.ballY == ballY &&
      other.ballVX == ballVX &&
      other.ballVY == ballVY &&
      other.paddle1X == paddle1X &&
      other.paddle2X == paddle2X &&
      other.score1 == score1 &&
      other.score2 == score2 &&
      other.serveMs == serveMs &&
      other.lastScorer == lastScorer &&
      other.rally == rally &&
      other.longestRally == longestRally &&
      other.hits == hits &&
      other.timeMs == timeMs;

  @override
  int get hashCode => Object.hash(
      tick,
      phase,
      ballX,
      ballY,
      ballVX,
      ballVY,
      paddle1X,
      paddle2X,
      score1,
      score2,
      serveMs,
      lastScorer,
      rally,
      longestRally,
      hits,
      timeMs);

  @override
  String toString() => 'GameState(tick $tick, $phase, balle ($ballX, $ballY), '
      'raquettes ($paddle1X, $paddle2X), score $score1-$score2, service ${serveMs}ms, échange $rally)';
}
