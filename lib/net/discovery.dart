/// Découverte des parties sur le réseau local par broadcast UDP.
///
/// Deux mécanismes complémentaires, sur le port UDP [discoveryPort] :
/// 1. Le Host **annonce** sa partie toutes les secondes en broadcast.
/// 2. Le Client envoie une **sonde** en broadcast toutes les secondes ; le
///    Host y répond par une annonce **directe** (unicast) vers le Client.
///
/// Le second mécanisme rattrape les cas où le Client ne reçoit pas les
/// broadcasts (filtrage Wi-Fi du téléphone) : l'envoi d'un broadcast n'est
/// jamais filtré, et une réponse unicast passe toujours.
///
/// Chaque broadcast part vers 255.255.255.255 **et** vers l'adresse de
/// broadcast de chaque interface (a.b.c.255) : sur un téléphone en point
/// d'accès sans données mobiles, 255.255.255.255 peut partir sur la mauvaise
/// interface ou échouer.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'game_discovery.dart';
import 'multicast_lock.dart';
import 'net_constants.dart';
import 'net_log.dart';
import 'protocol.dart';

const String _app = 'pong_game';
const String _announceType = 'announce';
const String _probeType = 'probe';

/// Taille maximale d'un paquet de découverte accepté.
const int maxDiscoveryPacketLength = 1024;

/// Longueur maximale du nom d'une partie.
const int maxGameNameLength = 40;

/// Fournit les adresses vers lesquelles envoyer les broadcasts.
typedef BroadcastTargets = Future<List<InternetAddress>> Function();

/// Adresses de broadcast : 255.255.255.255 plus a.b.c.255 pour chaque
/// interface IPv4 (hors boucle locale et données mobiles).
///
/// Dart ne donne pas le masque de sous-réseau : on suppose un /24, ce qui
/// est le cas des points d'accès Android et de la quasi-totalité des box.
Future<List<InternetAddress>> defaultBroadcastTargets() async {
  final targets = <String>{'255.255.255.255'};
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      // Interfaces de données mobiles : inutile d'y diffuser.
      if (name.contains('rmnet') || name.startsWith('ccmni')) continue;
      for (final address in interface.addresses) {
        if (address.isLoopback || address.type != InternetAddressType.IPv4) continue;
        final parts = address.address.split('.');
        if (parts.length != 4) continue;
        targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
      }
    }
  } on Object catch (_) {
    // Liste des interfaces indisponible : 255.255.255.255 seul.
  }
  return [for (final t in targets) InternetAddress(t)];
}

/// Liste des adresses IPv4 locales (hors boucle locale), à afficher au Host
/// pour une saisie manuelle si la découverte échoue.
Future<List<String>> localIpv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses)
          if (!address.isLoopback) address.address,
    ];
  } on Object catch (_) {
    return const [];
  }
}

String _randomId() {
  final random = Random();
  return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
}

/// Envoie un paquet vers chaque cible, sans jamais lever d'exception (une
/// interface peut refuser, par exemple « Network is unreachable »).
void _sendToAll(RawDatagramSocket socket, List<int> data, List<InternetAddress> targets, int port, NetLogger log) {
  for (final target in targets) {
    try {
      socket.send(data, target, port);
    } on Object catch (e) {
      log('broadcast vers ${target.address} impossible : $e');
    }
  }
}

Map<String, dynamic>? _decodePacket(Datagram datagram) {
  if (datagram.data.length > maxDiscoveryPacketLength) return null;
  try {
    final raw = jsonDecode(utf8.decode(datagram.data));
    if (raw is! Map<String, dynamic> || raw['app'] != _app) return null;
    return raw;
  } on Object catch (_) {
    return null;
  }
}

/// Côté Host : annonce la partie et répond aux sondes.
class DiscoveryAnnouncer implements GameAdvertiser {
  DiscoveryAnnouncer({
    required String gameName,
    required this.gamePort,
    int players = 1,
    this.maxPlayers = 2,
    this.listenPort = discoveryPort,
    this.targetPort = discoveryPort,
    this.interval = const Duration(seconds: 1),
    BroadcastTargets? targets,
    MulticastLock? multicastLock,
    this.log = defaultNetLogger,
  })  : _gameName = _clip(gameName),
        _players = players,
        _targets = targets ?? defaultBroadcastTargets,
        _lock = multicastLock ?? platformMulticastLock();

  final int gamePort;
  final int maxPlayers;

  /// Port UDP local, où arrivent les sondes des Clients.
  final int listenPort;

  /// Port UDP des Clients, destination des annonces.
  final int targetPort;
  final Duration interval;
  final NetLogger log;
  final BroadcastTargets _targets;
  final MulticastLock _lock;
  final String id = _randomId();

  String _gameName;
  int _players;
  RawDatagramSocket? _socket;
  Timer? _timer;
  List<InternetAddress> _targetList = const [];
  int _ticks = 0;
  bool _stopped = false;

  static String _clip(String name) {
    final trimmed = name.trim();
    return trimmed.length <= maxGameNameLength ? trimmed : trimmed.substring(0, maxGameNameLength);
  }

  bool get isRunning => _socket != null && !_stopped;

  /// Port UDP réellement ouvert (où arrivent les sondes).
  int get port => _socket?.port ?? 0;

  @override
  Future<void> start() async {
    if (_socket != null || _stopped) throw StateError('DiscoveryAnnouncer déjà démarré ou arrêté');
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort, reuseAddress: true);
    } on SocketException catch (e) {
      // Sans ce port, les sondes ne nous parviennent pas, mais les annonces
      // partent quand même.
      log('port de découverte $listenPort indisponible ($e), annonces seules');
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }
    if (_stopped) {
      socket.close();
      return;
    }
    socket.broadcastEnabled = true;
    _socket = socket;
    socket.listen(_onEvent, onError: (Object e) => log('découverte (Host) : $e'));
    await _lock.acquire();
    _targetList = await _targets();
    _announce();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    // Les interfaces changent (point d'accès activé, Wi-Fi rejoint) : on
    // recalcule les cibles toutes les 5 annonces.
    if (++_ticks % 5 == 0) {
      _targets().then((t) => _targetList = t);
    }
    _announce();
  }

  /// Met à jour le nombre de joueurs et l'annonce aussitôt.
  @override
  void update({int? players, String? gameName}) {
    if (players != null) _players = players;
    if (gameName != null) _gameName = _clip(gameName);
    _announce();
  }

  List<int> _packet() => utf8.encode(jsonEncode({
        'app': _app,
        'type': _announceType,
        'v': protocolVersion,
        'id': id,
        'name': _gameName,
        'port': gamePort,
        'players': _players,
        'max': maxPlayers,
      }));

  void _announce() {
    final socket = _socket;
    if (socket == null || _stopped) return;
    _sendToAll(socket, _packet(), _targetList, targetPort, log);
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final packet = _decodePacket(datagram!);
      if (packet == null || packet['type'] != _probeType) continue;
      try {
        socket.send(_packet(), datagram.address, datagram.port);
      } on Object catch (e) {
        log('réponse à la sonde de ${datagram.address.address} impossible : $e');
      }
    }
  }

  /// Arrête les annonces et ferme le socket. Idempotent.
  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
    await _lock.release();
  }
}

/// Côté Client : écoute les annonces, sonde le réseau, tient la liste des
/// parties et retire celles qui ne sont plus annoncées.
class DiscoveryBrowser implements GameFinder {
  DiscoveryBrowser({
    this.listenPort = discoveryPort,
    this.probePort = discoveryPort,
    this.probeInterval = const Duration(seconds: 1),
    this.expiry = const Duration(milliseconds: 3500),
    BroadcastTargets? targets,
    MulticastLock? multicastLock,
    this.log = defaultNetLogger,
  })  : _targets = targets ?? defaultBroadcastTargets,
        _lock = multicastLock ?? platformMulticastLock();

  /// Port UDP local, où arrivent les annonces.
  final int listenPort;

  /// Port UDP des Hosts, destination des sondes.
  final int probePort;
  final Duration probeInterval;

  /// Une partie non annoncée depuis ce délai est retirée (3 annonces
  /// manquées et demie).
  final Duration expiry;
  final NetLogger log;
  final BroadcastTargets _targets;
  final MulticastLock _lock;

  final StreamController<List<DiscoveredGame>> _games = StreamController<List<DiscoveredGame>>.broadcast();
  final Map<String, ({DiscoveredGame game, Duration seenAt})> _entries = {};
  final Stopwatch _clock = Stopwatch();
  RawDatagramSocket? _socket;
  Timer? _timer;
  List<InternetAddress> _targetList = const [];
  int _ticks = 0;
  bool _stopped = false;

  /// Liste des parties, émise à chaque changement (ajout, retrait, nombre
  /// de joueurs).
  @override
  Stream<List<DiscoveredGame>> get games => _games.stream;

  /// Liste actuelle, triée par nom.
  @override
  List<DiscoveredGame> get current {
    final list = [for (final e in _entries.values) e.game];
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Port UDP réellement ouvert.
  int get port => _socket?.port ?? 0;

  @override
  Future<void> start() async {
    if (_socket != null || _stopped) throw StateError('DiscoveryBrowser déjà démarré ou arrêté');
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort, reuseAddress: true);
    } on SocketException catch (e) {
      // Sans ce port, seules les réponses directes aux sondes arrivent.
      log('port de découverte $listenPort indisponible ($e), sondes seules');
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }
    if (_stopped) {
      socket.close();
      return;
    }
    socket.broadcastEnabled = true;
    _socket = socket;
    _clock.start();
    socket.listen(_onEvent, onError: (Object e) => log('découverte (Client) : $e'));
    await _lock.acquire();
    _targetList = await _targets();
    _probe();
    _timer = Timer.periodic(probeInterval, (_) => _tick());
  }

  void _tick() {
    if (++_ticks % 5 == 0) {
      _targets().then((t) => _targetList = t);
    }
    _expire();
    _probe();
  }

  /// Vide la liste et sonde aussitôt (bouton « Actualiser »).
  @override
  void refresh() {
    if (_entries.isNotEmpty) {
      _entries.clear();
      _emit();
    }
    _probe();
  }

  void _probe() {
    final socket = _socket;
    if (socket == null || _stopped) return;
    final data = utf8.encode(jsonEncode({'app': _app, 'type': _probeType, 'v': protocolVersion}));
    _sendToAll(socket, data, _targetList, probePort, log);
  }

  void _expire() {
    final now = _clock.elapsed;
    final before = _entries.length;
    _entries.removeWhere((_, e) => now - e.seenAt > expiry);
    if (_entries.length != before) _emit();
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final packet = _decodePacket(datagram!);
      if (packet == null || packet['type'] != _announceType) continue;
      final game = _parseAnnouncement(packet, datagram.address.address);
      if (game == null) {
        log('annonce invalide de ${datagram.address.address}, ignorée');
        continue;
      }
      final previous = _entries[game.id]?.game;
      _entries[game.id] = (game: game, seenAt: _clock.elapsed);
      if (previous != game) _emit();
    }
  }

  static DiscoveredGame? _parseAnnouncement(Map<String, dynamic> p, String address) {
    final id = p['id'];
    final name = p['name'];
    final port = p['port'];
    final players = p['players'];
    final max = p['max'];
    final version = p['v'];
    if (id is! String || id.isEmpty || id.length > 32) return null;
    if (name is! String || name.trim().isEmpty || name.length > maxGameNameLength) return null;
    if (port is! int || port < 1 || port > 65535) return null;
    if (max is! int || max < 1 || max > 8) return null;
    if (players is! int || players < 0 || players > max) return null;
    if (version is! int) return null;
    return DiscoveredGame(
      id: id,
      name: name.trim(),
      address: address,
      port: port,
      players: players,
      maxPlayers: max,
      version: version,
    );
  }

  void _emit() {
    if (!_games.isClosed) _games.add(current);
  }

  /// Arrête l'écoute et ferme le socket. Idempotent.
  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
    _clock.stop();
    await _lock.release();
    await _games.close();
  }
}
