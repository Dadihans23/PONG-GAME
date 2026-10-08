import 'dart:async';

import 'net_log.dart';
import 'protocol.dart';
import 'transport.dart';

/// Réglages du battement de cœur.
///
/// Toute trame reçue (y compris `game_state` et `paddle` à 30 Hz) prouve que
/// le pair est vivant. En plus, un `ping` part toutes les [pingInterval] ; si
/// rien n'est reçu pendant [timeout], la connexion est déclarée perdue.
///
/// 1 s / 4 s : une coupure de Wi-Fi, un téléphone éteint ou une app gelée en
/// arrière-plan sont détectés en 4 à 4,25 s, sans faux positif sur les
/// micro-coupures habituelles du Wi-Fi (quelques centaines de ms).
class HeartbeatConfig {
  const HeartbeatConfig({
    this.pingInterval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 4),
    this.checkInterval = const Duration(milliseconds: 250),
  });

  final Duration pingInterval;
  final Duration timeout;
  final Duration checkInterval;
}

/// Pourquoi une connexion s'est terminée.
enum DisconnectReason {
  /// Le pair a envoyé `leave` (départ volontaire).
  left,

  /// La connexion s'est fermée sans `leave` (app tuée, socket fermé).
  closed,

  /// Plus rien reçu pendant le délai du battement de cœur (Wi-Fi perdu,
  /// téléphone en veille, app gelée en arrière-plan).
  timeout,

  /// Fermeture demandée de ce côté-ci.
  local,
}

/// Liaison avec un pair : décodage défensif, battement de cœur, fin de
/// connexion. Utilisée par les deux sessions ; ne connaît pas les rôles.
class PeerLink {
  PeerLink(
    this._connection, {
    required this.onMessage,
    required this.onClosed,
    this.heartbeat = const HeartbeatConfig(),
    this.log = defaultNetLogger,
  });

  final NetConnection _connection;
  final HeartbeatConfig heartbeat;
  final NetLogger log;

  /// Messages utiles reçus (hors `ping`, `pong` et `leave`).
  final void Function(NetMessage message) onMessage;

  /// Appelé une seule fois, à la fin de la liaison.
  final void Function(DisconnectReason reason) onClosed;

  final Stopwatch _clock = Stopwatch();
  StreamSubscription<String>? _subscription;
  Timer? _timer;
  Duration _lastReceived = Duration.zero;
  Duration _lastPing = Duration.zero;
  bool _closed = false;
  Duration? _rtt;

  String get remoteDescription => _connection.remoteDescription;

  bool get isOpen => !_closed;

  /// Dernier aller-retour mesuré par `ping`/`pong`.
  Duration? get roundTripTime => _rtt;

  void start() {
    _clock.start();
    _subscription = _connection.frames.listen(
      _onFrame,
      onDone: () => _finish(DisconnectReason.closed),
      onError: (Object _) => _finish(DisconnectReason.closed),
    );
    _timer = Timer.periodic(heartbeat.checkInterval, (_) => _checkHeartbeat());
  }

  void _onFrame(String frame) {
    if (_closed) return;
    _lastReceived = _clock.elapsed;
    final message = NetMessage.decode(frame, log: (m) => log('${_connection.remoteDescription} : $m'));
    if (message == null) return;
    switch (message) {
      case PingMessage(:final t):
        send(PongMessage(t));
      case PongMessage(:final t):
        final now = _clock.elapsedMilliseconds;
        if (t <= now) _rtt = Duration(milliseconds: now - t);
      case LeaveMessage():
        _finish(DisconnectReason.left);
      default:
        onMessage(message);
    }
  }

  void _checkHeartbeat() {
    if (_closed) return;
    final now = _clock.elapsed;
    // Après un gel de l'app (arrière-plan), ce test voit tout de suite que le
    // pair est silencieux depuis trop longtemps.
    if (now - _lastReceived > heartbeat.timeout) {
      log('${_connection.remoteDescription} : aucun message depuis ${(now - _lastReceived).inMilliseconds} ms, connexion perdue');
      _finish(DisconnectReason.timeout);
      return;
    }
    if (now - _lastPing >= heartbeat.pingInterval) {
      _lastPing = now;
      send(PingMessage(_clock.elapsedMilliseconds));
    }
  }

  /// Envoie un message. Retourne `false` si la liaison est fermée ou si le
  /// message n'est pas encodable (journalisé).
  bool send(NetMessage message) {
    if (_closed || !_connection.isOpen) return false;
    final String frame;
    try {
      frame = message.encode();
    } on NetEncodeException catch (e) {
      log('envoi annulé : ${e.message}');
      return false;
    }
    _connection.send(frame);
    return true;
  }

  /// Ferme la liaison. Avec [leave], envoie d'abord `leave` au pair pour
  /// qu'il sache que le départ est volontaire.
  Future<void> close({bool leave = true, String? reason}) async {
    if (_closed) return;
    if (leave) send(LeaveMessage(reason: reason));
    _finish(DisconnectReason.local);
  }

  void _finish(DisconnectReason reason) {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _clock.stop();
    _connection.close();
    onClosed(reason);
  }
}
