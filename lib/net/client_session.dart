import 'dart:async';

import 'net_log.dart';
import 'peer_link.dart';
import 'protocol.dart';
import 'session_events.dart';
import 'transport.dart';
import 'websocket_transport.dart';

/// Résultat de [ClientSession.connect].
sealed class JoinResult {
  const JoinResult();
}

/// Le Host a accepté : la session est connectée.
class JoinAccepted extends JoinResult {
  const JoinAccepted(this.hostName);

  final String hostName;
}

/// Le Host a refusé (partie pleine, version incompatible…).
class JoinRejected extends JoinResult {
  const JoinRejected(this.reason);

  final RejectReason reason;
}

/// Connexion impossible (Host injoignable, délai dépassé, coupure).
class JoinFailed extends JoinResult {
  const JoinFailed(this.message);

  final String message;
}

/// Session réseau du Client : se connecte à un Host, envoie sa raquette et
/// son statut Prêt, reçoit l'état du jeu, détecte la perte du Host.
///
/// Une session sert une seule connexion : après un échec ou une
/// déconnexion, en créer une nouvelle.
///
/// Écouter [events] avant [connect] : c'est un flux diffusé.
class ClientSession {
  ClientSession({
    required this.playerName,
    NetTransport? transport,
    this.heartbeat = const HeartbeatConfig(),
    this.connectTimeout = const Duration(seconds: 5),
    this.welcomeTimeout = const Duration(seconds: 3),
    this.log = defaultNetLogger,
  }) : _transport = transport ?? WebSocketTransport(log: log);

  final String playerName;
  final HeartbeatConfig heartbeat;
  final Duration connectTimeout;

  /// Délai d'attente de `welcome` (ou `reject`) après l'envoi de `join`.
  final Duration welcomeTimeout;
  final NetLogger log;
  final NetTransport _transport;

  final StreamController<SessionEvent> _events = StreamController<SessionEvent>.broadcast();
  PeerLink? _link;
  Completer<JoinResult>? _joining;
  Timer? _welcomeTimer;
  bool _connected = false;
  bool _used = false;
  bool _closed = false;
  String? _hostName;
  int _paddleSeq = 0;
  int _lastStateSeq = -1;
  GameStateMessage? _lastState;

  /// Événements : Host parti, messages du Host (`ready`, `start`,
  /// `game_state`, `game_over`, `rematch`).
  Stream<SessionEvent> get events => _events.stream;

  bool get isConnected => _connected;

  String? get hostName => _hostName;

  /// Dernier état de jeu reçu, ou `null`. Le Client l'affiche à chaque image.
  GameStateMessage? get lastState => _lastState;

  /// Aller-retour mesuré avec le Host.
  Duration? get roundTripTime => _link?.roundTripTime;

  /// Se connecte au Host et envoie `join`. Ne lève jamais d'exception.
  Future<JoinResult> connect(String host, int port) async {
    if (_used || _closed) throw StateError('ClientSession déjà utilisée : en créer une nouvelle');
    _used = true;
    final NetConnection connection;
    try {
      connection = await _transport.connect(host, port, timeout: connectTimeout);
    } on NetConnectException catch (e) {
      log(e.message);
      _closed = true;
      if (!_events.isClosed) _events.close();
      return JoinFailed(e.message);
    }
    if (_closed) {
      connection.close();
      return const JoinFailed('session fermée');
    }
    final joining = _joining = Completer<JoinResult>();
    final link = _link = PeerLink(
      connection,
      heartbeat: heartbeat,
      log: log,
      onMessage: _onMessage,
      onClosed: _onClosed,
    );
    link.start();
    link.send(JoinMessage(name: playerName));
    _welcomeTimer = Timer(welcomeTimeout, () {
      if (!joining.isCompleted) {
        _completeJoin(const JoinFailed('le Host ne répond pas'));
        link.close(leave: false);
      }
    });
    return joining.future;
  }

  void _completeJoin(JoinResult result) {
    _welcomeTimer?.cancel();
    _welcomeTimer = null;
    final joining = _joining;
    if (joining != null && !joining.isCompleted) joining.complete(result);
  }

  void _onMessage(NetMessage message) {
    if (!_connected) {
      switch (message) {
        case WelcomeMessage(:final hostName):
          _connected = true;
          _hostName = hostName;
          _completeJoin(JoinAccepted(hostName));
          _emit(PeerConnected(hostName));
        case RejectMessage(:final reason):
          log('refusé par le Host : ${reason.wire}');
          _completeJoin(JoinRejected(reason));
          _link?.close(leave: false);
        default:
          log('${message.type} reçu avant welcome, ignoré');
      }
      return;
    }
    switch (message) {
      case GameStateMessage(:final seq):
        if (seq <= _lastStateSeq) return;
        _lastStateSeq = seq;
        _lastState = message;
        _emit(MessageReceived(message));
      case ReadyMessage() || StartMessage() || GameOverMessage() || RematchMessage():
        _emit(MessageReceived(message));
      default:
        log('${message.type} reçu du Host, inattendu : ignoré');
    }
  }

  void _onClosed(DisconnectReason reason) {
    final wasConnected = _connected;
    _connected = false;
    _completeJoin(const JoinFailed('connexion fermée par le Host'));
    // Une fermeture demandée par ce côté n'est pas une perte du Host.
    if (wasConnected && reason != DisconnectReason.local) {
      log('Host perdu ($reason)');
      _emit(PeerDisconnected(reason));
    }
    _closed = true;
    _events.close();
  }

  void _emit(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Envoie la position de la raquette (-1 à 1, coordonnées du court, sans
  /// inversion). Appelé à 30 Hz. Une valeur non finie est ignorée.
  bool sendPaddle(double x) {
    if (!_connected || !x.isFinite) return false;
    return _link!.send(PaddleMessage(seq: _paddleSeq++, x: x.clamp(-1.0, 1.0)));
  }

  bool sendReady(bool ready) => _connected && _link!.send(ReadyMessage(ready: ready));

  bool sendRematch() => _connected && _link!.send(const RematchMessage());

  /// Quitte la partie : envoie `leave` puis ferme. Idempotent. À appeler
  /// aussi quand l'écran se ferme ou que l'app passe en arrière-plan.
  Future<void> close() async {
    if (_closed && _link == null) return;
    final link = _link;
    _link = null;
    _completeJoin(const JoinFailed('session fermée'));
    if (link != null) {
      await link.close(reason: 'client_left');
    } else {
      _closed = true;
      if (!_events.isClosed) await _events.close();
    }
  }
}
