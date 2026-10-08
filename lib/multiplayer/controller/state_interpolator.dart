import '../../net/net_constants.dart';
import '../model/game_state.dart';

/// Interpolation légère des états reçus par l'invité, sans prédiction.
///
/// L'hôte envoie l'état 30 fois par seconde ; l'écran s'affiche à 60 Hz ou
/// plus. Sans interpolation, la balle avancerait par sauts de 33 ms.
///
/// Principe : à chaque état reçu, l'affichage part de **ce qui est affiché à
/// cet instant** et rejoint le nouvel état en ligne droite en [duration]
/// (un intervalle d'envoi). Il n'y a jamais de saut quand un état arrive en
/// avance ou en retard, et jamais d'extrapolation : si l'état suivant tarde,
/// l'affichage s'arrête sur le dernier état reçu.
///
/// Retard ajouté : en mouvement régulier, l'affichage suit le dernier état
/// reçu avec **un intervalle de retard, soit 33 ms** (en plus de la latence
/// du réseau, quelques ms sur un réseau local). La balle, qui parcourt au
/// plus ~0,13 unité en 33 ms, coupe à peine les angles de ses rebonds.
///
/// Discontinuités : après un point (score changé, balle remise au centre) ou
/// un écart de balle supérieur à [snapDistance], l'affichage saute
/// directement au nouvel état au lieu de faire glisser la balle à travers le
/// terrain.
///
/// Seules les positions (balle, raquettes) sont interpolées ; tout le reste
/// (score, vitesses, pause de service, échanges) vient du dernier état reçu.
class StateInterpolator {
  StateInterpolator({this.duration = netSendInterval, this.snapDistance = 0.5})
      : assert(duration > Duration.zero);

  final Duration duration;
  final double snapDistance;

  GameState? _from;
  GameState? _to;
  Duration _start = Duration.zero;

  /// Dernier état reçu, ou `null`.
  GameState? get latest => _to;

  /// Oublie tout (nouvelle partie).
  void clear() {
    _from = null;
    _to = null;
  }

  /// Ajoute l'état [state] reçu à l'instant [now].
  void push(GameState state, Duration now) {
    final current = sample(now);
    _from =
        (current == null || _isDiscontinuous(current, state)) ? state : current;
    _to = state;
    _start = now;
  }

  /// État à afficher à l'instant [now], ou `null` si rien n'a été reçu.
  GameState? sample(Duration now) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    if (identical(from, to)) return to;
    final double t = (now - _start).inMicroseconds / duration.inMicroseconds;
    if (t >= 1) return to;
    if (t <= 0) return from;
    double lerp(double a, double b) => a + (b - a) * t;
    return GameState(
      tick: to.tick,
      phase: to.phase,
      ballX: lerp(from.ballX, to.ballX),
      ballY: lerp(from.ballY, to.ballY),
      ballVX: to.ballVX,
      ballVY: to.ballVY,
      paddle1X: lerp(from.paddle1X, to.paddle1X),
      paddle2X: lerp(from.paddle2X, to.paddle2X),
      score1: to.score1,
      score2: to.score2,
      serveMs: to.serveMs,
      lastScorer: to.lastScorer,
      rally: to.rally,
      longestRally: to.longestRally,
      hits: to.hits,
      timeMs: to.timeMs,
    );
  }

  bool _isDiscontinuous(GameState a, GameState b) {
    if (a.score1 != b.score1 || a.score2 != b.score2) return true;
    // Début de la pause de service : balle remise au centre
    if (b.isServing && !a.isServing) return true;
    final dx = a.ballX - b.ballX;
    final dy = a.ballY - b.ballY;
    return dx * dx + dy * dy > snapDistance * snapDistance;
  }
}
