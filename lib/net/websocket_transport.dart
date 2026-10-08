import 'dart:async';
import 'dart:io';

import 'net_log.dart';
import 'transport.dart';

/// Chemin HTTP de la WebSocket du jeu. Toute autre requête reçoit un 404.
const String webSocketPath = '/pong';

/// Transport WebSocket réel, uniquement `dart:io` (aucune dépendance pub).
///
/// Host : `HttpServer` + `WebSocketTransformer`, en écoute sur toutes les
/// interfaces IPv4 (Wi-Fi et point d'accès). Client : `WebSocket.connect`.
class WebSocketTransport implements NetTransport {
  WebSocketTransport({this.log = defaultNetLogger});

  final NetLogger log;

  @override
  Future<NetListener> listen({required int port}) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException catch (e) {
      if (port == 0) rethrow;
      // Port occupé (ancienne instance pas encore libérée, autre app) : on
      // prend un port libre, il est annoncé par la découverte.
      log('port $port indisponible ($e), repli sur un port libre');
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    return _WebSocketListener(server, log);
  }

  @override
  Future<NetConnection> connect(String host, int port, {required Duration timeout}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final uri = Uri(scheme: 'ws', host: host, port: port, path: webSocketPath);
    try {
      final socket = await WebSocket.connect(uri.toString(), customClient: client).timeout(timeout);
      return WebSocketConnection(socket, '$host:$port');
    } on TimeoutException {
      client.close(force: true);
      throw NetConnectException('délai dépassé pour $host:$port');
    } on Object catch (e) {
      client.close(force: true);
      throw NetConnectException('connexion impossible à $host:$port ($e)');
    }
  }
}

class _WebSocketListener implements NetListener {
  _WebSocketListener(this._server, this._log) {
    _subscription = _server.listen(
      _onRequest,
      onError: (Object e) => _log('erreur du serveur HTTP : $e'),
      onDone: _closeController,
    );
  }

  final HttpServer _server;
  final NetLogger _log;
  late final StreamSubscription<HttpRequest> _subscription;
  final StreamController<NetConnection> _controller = StreamController<NetConnection>();
  bool _closed = false;

  @override
  Stream<NetConnection> get connections => _controller.stream;

  @override
  int get port => _server.port;

  Future<void> _onRequest(HttpRequest request) async {
    final remote = request.connectionInfo;
    final description = remote == null ? '?' : '${remote.remoteAddress.address}:${remote.remotePort}';
    if (request.uri.path != webSocketPath || !WebSocketTransformer.isUpgradeRequest(request)) {
      _log('requête HTTP refusée de $description : ${request.uri.path}');
      try {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      } on Object catch (_) {}
      return;
    }
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      if (_closed) {
        await socket.close(WebSocketStatus.goingAway);
        return;
      }
      _controller.add(WebSocketConnection(socket, description));
    } on Object catch (e) {
      _log('échec de la mise à niveau WebSocket de $description : $e');
    }
  }

  void _closeController() {
    if (!_controller.isClosed) _controller.close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    try {
      await _server.close(force: false);
    } on Object catch (_) {}
    _closeController();
  }
}

/// Une connexion WebSocket. Les trames binaires sont ignorées.
class WebSocketConnection implements NetConnection {
  WebSocketConnection(this._socket, this.remoteDescription) {
    _socket.listen(
      (dynamic data) {
        if (data is String && _open) {
          _frames.add(data);
        }
        // Trame binaire : le protocole est en texte, on l'ignore.
      },
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: true,
    );
  }

  final WebSocket _socket;
  final StreamController<String> _frames = StreamController<String>();
  final Completer<void> _done = Completer<void>();
  bool _open = true;

  @override
  final String remoteDescription;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String frame) {
    if (!_open) return;
    try {
      _socket.add(frame);
    } on Object catch (_) {
      // Socket déjà fermé côté système : la fin sera signalée par onDone.
    }
  }

  void _finish() {
    if (!_open) return;
    _open = false;
    _frames.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _finish();
    try {
      // Si le pair ne répond plus, dart:io détruit le socket après son propre
      // délai : on n'attend pas plus d'une seconde ici.
      await _socket.close(WebSocketStatus.normalClosure).timeout(const Duration(seconds: 1));
    } on Object catch (_) {}
  }
}
