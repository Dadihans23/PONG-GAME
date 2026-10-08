import 'net_constants.dart';

/// Limite un envoi à une cadence donnée, depuis la boucle d'images.
///
/// La boucle de jeu tourne à la fréquence de l'écran (60, 90 ou 120 Hz) ;
/// on n'envoie l'état (Host) ou la raquette (Client) que 30 fois par
/// seconde :
///
/// ```dart
/// if (_sendLimiter.shouldSend(elapsed)) session.sendGameState(state.toJson());
/// ```
///
/// [shouldSend] prend le temps écoulé depuis le début (celui du `Ticker`).
/// Pas de rattrapage : après une image longue, un seul envoi part.
class NetRateLimiter {
  NetRateLimiter({this.interval = netSendInterval});

  final Duration interval;
  Duration? _next;

  bool shouldSend(Duration now) {
    final next = _next;
    // Tolérance d'un quart d'intervalle : à 60 images/s, l'image qui tombe
    // 1 µs avant l'échéance doit partir, sinon on n'enverrait que 20 fois
    // par seconde.
    if (next != null && now < next - interval ~/ 4) return false;
    // On vise une grille régulière ; si on a pris du retard, on repart
    // de maintenant.
    _next = (next == null || now - next >= interval) ? now + interval : next + interval;
    return true;
  }

  /// Le prochain appel à [shouldSend] renverra `true`.
  void reset() => _next = null;
}
