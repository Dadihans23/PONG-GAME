import 'dart:async';

import 'net_constants.dart';
import 'net_log.dart';
import 'peer_link.dart';
import 'protocol.dart';
import 'session_events.dart';
import 'transport.dart';
import 'websocket_transport.dart';

/// Session réseau du Host : écoute sur un port, accepte un seul Client,
/// refuse proprement les suivants, détecte le départ du Client.
///
/// Après le départ du Client, la session reste en écoute : un autre joueur
/// peut rejoindre (retour au salon). Seul [close] arrête tout.
///
/// Écouter [events] avant d'appeler [start] : c'est un flux diffusé, un
/// événement émis sans auditeur est perdu.
class HostSession {
  HostSession({
    required this.hostName,
    NetTransport? transport,
    this.requestedPort = defaultGamePort,
    this.heartbeat = const HeartbeatConfig(),
    this.joinTimeout = const Duration(seconds: 3),
    this.log = defaultNetLogger,
  }) : _transport = transport ?? WebSocketTransport(log: log);

  /// Pseudo du joueur Host, envoyé au Client dans `welcome`.
  final String hostName;
  final int requestedPort;
  final HeartbeatConfig heartbeat;

  /// Délai laissé à une connexion entrante pour envoyer `join`.
  final Duration joinTimeout;
  final NetLogger log;
  final NetTransport _transport;

  /// Connexions en attente de `join` au maximum, pour ne pas se laisser
  /// saturer.
  static const int maxPendingConnections = 4;

  final StreamController<SessionEvent> _events = StreamController<SessionEvent>.broadcast();
  NetListener? _listener;
  StreamSubscription<NetConnection>? _listenerSubscription;
  final Map<PeerLink, Timer> _pending = {};
  PeerLink? _client;
  String? _clientName;
  int _stateSeq = 0;
  int _lastPaddleSeq = -1;
  double? _clientPaddleX;
  bool _closed = false;

  /// Événements : Client connecté, Client parti, messages du Client
  /// (`ready`, `paddle`, `rematch`).
  Stream<SessionEvent> get events => _events.stream;

  /// Port réellement ouvert (à annoncer par la découverte). 0 avant [start].
  int get port => _listener?.port ?? 0;

  bool get isRunning => _listener != null && !_closed;

  bool get hasClient => _client != null;

  /// Pseudo du Client connecté, ou `null`.
  String? get clientName => _clientName;

  /// Nombre de joueurs dans la partie, Host compris (1 ou 2).
  int get playerCount => hasClient ? 2 : 1;

  /// Dernière position reçue de la raquette du Client (-1 à 1), ou `null`
  /// tant qu'aucune n'est arrivée. Le moteur la lit à chaque pas.
  double? get clientPaddleX => _clientPaddleX;

  /// Aller-retour mesuré avec le Client.
  Duration? get roundTripTime => _client?.roundTripTime;

  /// Ouvre le serveur. Retourne le port réellement utilisé.
  Future<int> start() async {
    if (_listener != null || _closed) throw StateError('HostSession déjà démarrée ou fermée');
    final listener = await _transport.listen(port: requestedPort);
    if (_closed) {
      await listener.close();
      throw StateError('HostSession fermée pendant le démarrage');
    }
    _listener = listener;
    _listenerSubscription = listener.connections.listen(_onConnection);
    log('Host en écoute sur le port ${listener.port}');
    return listener.port;
  }

  void _onConnection(NetConnection connection) {
    if (_closed) {
      connection.close();
      return;
    }
    if (_client != null || _pending.length >= maxPendingConnections) {
      log('connexion de ${connection.remoteDescription} refusée : partie pleine');
      _rejectRaw(connection, RejectReason.full);
      return;
    }
    late final PeerLink link;
    link = PeerLink(
      connection,
      heartbeat: heartbeat,
      log: log,
      onMessage: (message) => _onMessage(link, message),
      onClosed: (reason) => _onLinkClosed(link, reason),
    );
    _pending[link] = Timer(joinTimeout, () {
      if (_pending.containsKey(link)) {
        log('${link.remoteDescription} : pas de join dans le délai');
        _reject(link, RejectReason.badRequest);
      }
    });
    link.start();
  }

  void _onMessage(PeerLink link, NetMessage message) {
    if (identical(link, _client)) {
      _onClientMessage(message);
      return;
    }
    if (!_pending.containsKey(link)) return;
    if (message is! JoinMessage) {
      log('${link.remoteDescription} : ${message.type} reçu avant join, ignoré');
      return;
    }
    if (message.version != protocolVersion) {
      log('${link.remoteDescription} : version ${message.version} incompatible');
      _reject(link, RejectReason.version);
      return;
    }
    if (_client != null) {
      _reject(link, RejectReason.full);
      return;
    }
    _pending.remove(link)?.cancel();
    _client = link;
    _clientName = message.name;
    _lastPaddleSeq = -1;
    _clientPaddleX = null;
    link.send(WelcomeMessage(hostName: hostName));
    log('${message.name} a rejoint depuis ${link.remoteDescription}');
    _emit(PeerConnected(message.name));
  }

  void _onClientMessage(NetMessage message) {
    switch (message) {
      case PaddleMessage(:final seq, :final x):
        // TCP garde l'ordre ; ce test protège d'un futur transport qui ne
        // le garderait pas.
        if (seq <= _lastPaddleSeq) return;
        _lastPaddleSeq = seq;
        _clientPaddleX = x;
        _emit(MessageReceived(message));
      case ReadyMessage() || RematchMessage():
        _emit(MessageReceived(message));
      default:
        log('${message.type} reçu du Client, réservé au Host : ignoré');
    }
  }

  void _onLinkClosed(PeerLink link, DisconnectReason reason) {
    _pending.remove(link)?.cancel();
    if (!identical(link, _client)) return;
    log('$_clientName parti ($reason)');
    _client = null;
    _clientName = null;
    _clientPaddleX = null;
    _emit(PeerDisconnected(reason));
  }

  void _reject(PeerLink link, RejectReason reason) {
    link.send(RejectMessage(reason));
    link.close(leave: false);
  }

  void _rejectRaw(NetConnection connection, RejectReason reason) {
    connection.send(RejectMessage(reason).encode());
    connection.close();
  }

  void _emit(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Envoie un message au Client. Retourne `false` s'il n'y a pas de Client
  /// ou si le message n'est pas encodable.
  bool send(NetMessage message) => _client?.send(message) ?? false;

  /// Envoie l'état du jeu (`toJson()` du modèle). Appelé à [netSendRateHz].
  bool sendGameState(Map<String, dynamic> state) {
    if (_client == null) return false;
    return send(GameStateMessage(seq: _stateSeq++, state: state));
  }

  bool sendReady(bool ready) => send(ReadyMessage(ready: ready));

  bool sendStart(int countdownSeconds) =>
      send(StartMessage(countdown: countdownSeconds.clamp(0, maxCountdownSeconds)));

  bool sendGameOver(PlayerSide winner, {Map<String, dynamic>? state}) =>
      send(GameOverMessage(winner: winner, state: state));

  bool sendRematch() => send(const RematchMessage());

  /// Renvoie le Client (il reçoit `leave`) sans fermer la partie.
  Future<void> kickClient({String? reason}) async {
    await _client?.close(reason: reason);
  }

  /// Ferme tout : prévient le Client (`leave`), ferme sa connexion, les
  /// connexions en attente et le serveur. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _listenerSubscription?.cancel();
    _listenerSubscription = null;
    await _listener?.close();
    for (final link in _pending.keys.toList()) {
      _reject(link, RejectReason.closing);
    }
    _pending.clear();
    final client = _client;
    _client = null;
    _clientName = null;
    await client?.close(reason: 'host_closed');
    await _events.close();
  }
}
