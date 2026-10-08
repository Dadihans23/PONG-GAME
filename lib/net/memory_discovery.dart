import 'dart:async';

import 'game_discovery.dart';
import 'protocol.dart';

/// Découverte en mémoire, pour les tests : aucun socket UDP.
///
/// Une instance représente un réseau local. Les annonceurs créés par
/// [advertiser] apparaissent dans la liste de chaque chercheur créé par
/// [finder] tant qu'ils annoncent. Les listes sont émises de façon
/// asynchrone (micro-tâche), comme sur le vrai réseau.
class MemoryDiscovery {
  final Set<MemoryAdvertiser> _advertisers = {};
  final Set<MemoryFinder> _finders = {};
  int _nextId = 1;

  /// Parties ajoutées à la main (version incompatible, partie pleine…).
  final Map<String, DiscoveredGame> _extra = {};

  /// Annonceurs actifs.
  Iterable<MemoryAdvertiser> get advertisers => _advertisers;

  MemoryAdvertiser advertiser({
    required String gameName,
    required int gamePort,
    int players = 1,
    int maxPlayers = 2,
    int version = protocolVersion,
  }) =>
      MemoryAdvertiser._(this, 'mem${_nextId++}', gameName, gamePort, players, maxPlayers, version);

  MemoryFinder finder() => MemoryFinder._(this);

  /// Ajoute une partie fictive à la liste (sans Host derrière).
  void addGame(DiscoveredGame game) {
    _extra[game.id] = game;
    _changed();
  }

  void removeGame(String id) {
    if (_extra.remove(id) != null) _changed();
  }

  List<DiscoveredGame> _list() {
    final list = [
      for (final a in _advertisers)
        if (a._running) a._game,
      ..._extra.values,
    ];
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _changed() {
    for (final finder in _finders.toList()) {
      finder._schedule();
    }
  }
}

class MemoryAdvertiser implements GameAdvertiser {
  MemoryAdvertiser._(this._network, this.id, this._name, this.gamePort, this._players, this.maxPlayers, this._version);

  final MemoryDiscovery _network;
  final String id;
  final int gamePort;
  final int maxPlayers;
  final int _version;
  String _name;
  int _players;
  bool _running = false;
  bool _stopped = false;

  /// Nombre de joueurs actuellement annoncé.
  int get players => _players;

  String get gameName => _name;

  bool get isRunning => _running;

  DiscoveredGame get _game => DiscoveredGame(
        id: id,
        name: _name,
        address: 'memory',
        port: gamePort,
        players: _players,
        maxPlayers: maxPlayers,
        version: _version,
      );

  @override
  Future<void> start() async {
    if (_stopped || _running) return;
    _running = true;
    _network._advertisers.add(this);
    _network._changed();
  }

  @override
  void update({int? players, String? gameName}) {
    if (players != null) _players = players;
    if (gameName != null) _name = gameName;
    if (_running) _network._changed();
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _running = false;
    _network._advertisers.remove(this);
    _network._changed();
  }
}

class MemoryFinder implements GameFinder {
  MemoryFinder._(this._network);

  final MemoryDiscovery _network;
  final StreamController<List<DiscoveredGame>> _games = StreamController<List<DiscoveredGame>>.broadcast();
  List<DiscoveredGame> _current = const [];
  bool _running = false;
  bool _scheduled = false;

  @override
  Stream<List<DiscoveredGame>> get games => _games.stream;

  @override
  List<DiscoveredGame> get current => _current;

  @override
  Future<void> start() async {
    if (_running || _games.isClosed) return;
    _running = true;
    _network._finders.add(this);
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_running) return;
      final next = _network._list();
      if (_sameList(next, _current)) return;
      _current = List.unmodifiable(next);
      _games.add(_current);
    });
  }

  static bool _sameList(List<DiscoveredGame> a, List<DiscoveredGame> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void refresh() {
    if (!_running) return;
    if (_current.isNotEmpty) {
      _current = const [];
      _games.add(_current);
    }
    _schedule();
  }

  @override
  Future<void> stop() async {
    if (_games.isClosed) return;
    _running = false;
    _network._finders.remove(this);
    await _games.close();
  }
}
