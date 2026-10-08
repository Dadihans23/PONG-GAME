import 'dart:async';

import 'transport.dart';

/// Transport en mémoire, pour les tests : aucun socket.
///
/// Une instance représente un réseau. Le Host et le Client utilisent la
/// même instance : `listen` enregistre un port, `connect` crée une paire de
/// connexions reliées.
///
/// Les trames sont livrées de façon asynchrone (micro-tâche), dans l'ordre,
/// comme sur un vrai socket.
class MemoryTransport implements NetTransport {
  final Map<int, _MemoryListener> _listeners = {};
  int _nextPort = 40000;

  /// Toutes les connexions créées, côté Client (utile pour simuler une
  /// coupure dans un test).
  final List<MemoryConnection> clientEnds = [];

  /// Toutes les connexions créées, côté Host.
  final List<MemoryConnection> hostEnds = [];

  @override
  Future<NetListener> listen({required int port}) async {
    var actual = port;
    if (actual == 0 || _listeners.containsKey(actual)) {
      while (_listeners.containsKey(_nextPort)) {
        _nextPort++;
      }
      actual = _nextPort++;
    }
    final listener = _MemoryListener(actual, () => _listeners.remove(actual));
    _listeners[actual] = listener;
    return listener;
  }

  @override
  Future<NetConnection> connect(String host, int port, {required Duration timeout}) async {
    final listener = _listeners[port];
    if (listener == null || listener._closed) {
      throw NetConnectException('aucun Host sur le port $port');
    }
    final clientEnd = MemoryConnection._('host:$port');
    final hostEnd = MemoryConnection._('client#${hostEnds.length + 1}');
    clientEnd._peer = hostEnd;
    hostEnd._peer = clientEnd;
    clientEnds.add(clientEnd);
    hostEnds.add(hostEnd);
    listener._controller.add(hostEnd);
    return clientEnd;
  }
}

class _MemoryListener implements NetListener {
  _MemoryListener(this.port, this._onClose);

  @override
  final int port;
  final void Function() _onClose;
  final StreamController<NetConnection> _controller = StreamController<NetConnection>();
  bool _closed = false;

  @override
  Stream<NetConnection> get connections => _controller.stream;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _onClose();
    _controller.close();
  }
}

/// Une extrémité de connexion en mémoire.
class MemoryConnection implements NetConnection {
  MemoryConnection._(this.remoteDescription);

  @override
  final String remoteDescription;

  late MemoryConnection _peer;
  final StreamController<String> _incoming = StreamController<String>();
  final Completer<void> _done = Completer<void>();
  bool _open = true;
  bool _cut = false;

  /// Trames envoyées par cette extrémité (pour les tests).
  final List<String> sent = [];

  @override
  Stream<String> get frames => _incoming.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String frame) {
    if (!_open || _cut) return;
    sent.add(frame);
    final peer = _peer;
    scheduleMicrotask(() => peer._deliver(frame));
  }

  void _deliver(String frame) {
    if (!_open || _cut) return;
    _incoming.add(frame);
  }

  /// Simule une perte de réseau sans fermeture propre (Wi-Fi coupé,
  /// téléphone gelé) : plus rien ne passe dans les deux sens, mais aucune
  /// des deux extrémités n'est prévenue. Seul le battement de cœur peut
  /// détecter la coupure.
  void cutSilently() {
    _cut = true;
    _peer._cut = true;
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _shutdown();
    // Fermeture propre : le pair voit sa connexion se terminer, sauf si le
    // réseau est coupé (il ne le saura que par le battement de cœur).
    if (!_cut) {
      final peer = _peer;
      scheduleMicrotask(peer._shutdown);
    }
  }

  void _shutdown() {
    if (!_open) return;
    _open = false;
    _incoming.close();
    if (!_done.isCompleted) _done.complete();
  }
}
