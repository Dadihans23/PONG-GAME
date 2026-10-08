import 'dart:async';
import 'dart:math';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';

import '../../game/duel_engine.dart';
import '../../game/game_tuning.dart';
import '../../game/paddle_sensitivity.dart';
import '../../net/net.dart';
import '../duel_view.dart';
import '../model/duel_phase.dart';
import '../model/game_room.dart';
import '../model/game_state.dart';
import '../model/player.dart';
import 'duel_stats.dart';
import 'multiplayer_events.dart';
import 'multiplayer_network.dart';
import 'multiplayer_types.dart';
import 'state_interpolator.dart';

/// Horloge monotone (temps écoulé depuis un instant fixe). Injectable pour
/// les tests.
typedef MonotonicClock = Duration Function();

/// Contrôleur du duel en réseau local, de la création ou la recherche d'une
/// partie jusqu'à la revanche.
///
/// Il vit plus longtemps que les écrans : un seul contrôleur pour tout le
/// parcours multijoueur (menu, recherche, salon, duel, fin), créé à l'entrée
/// du multijoueur et libéré par [dispose] à la sortie. Les écrans le lisent
/// (c'est un [ChangeNotifier]) et appellent ses méthodes ; ils ne touchent
/// jamais au réseau.
///
/// - **Hôte** (joueur 1) : il ouvre la partie, l'annonce, tient le salon et
///   fait tourner [DuelEngine], qui fait autorité. Il envoie l'état 30 fois
///   par seconde.
/// - **Invité** (joueur 2) : il cherche, rejoint, envoie la position de sa
///   raquette 30 fois par seconde et affiche l'état reçu, interpolé.
///
/// Le contrôleur ne crée pas de `Ticker` : pendant le duel, l'écran appelle
/// [onFrame] une fois par image. Il ne joue aucun son : il émet des
/// [MultiplayerEvent] sur [events].
class MultiplayerController extends ChangeNotifier {
  MultiplayerController({
    required String playerName,
    MultiplayerNetwork network = const MultiplayerNetwork(),
    DuelStatsStore? stats,
    Random? random,
    MonotonicClock? clock,
    this.stepsPerSecond = GameTuning.stepsPerSecond,
    int paddleSensitivity = PaddleSensitivity.defaultValue,
    this.paddleMaxSpeed = GameTuning.paddleSpeedCap,
    this.maxStepsPerFrame = GameTuning.maxStepsPerFrame,
    this.countdownSeconds = 3,
    this.searchTimeout = const Duration(seconds: 5),
    this.degradedAfter = const Duration(seconds: 1),
  })  : assert(
            countdownSeconds >= 0 && countdownSeconds <= maxCountdownSeconds),
        paddleSensitivity = PaddleSensitivity.clamp(paddleSensitivity),
        _playerName = cleanPlayerName(playerName),
        _network = network,
        _stats = stats ?? HiveDuelStats(),
        _random = random ?? Random(),
        _clock = clock ?? _stopwatchClock();

  /// Pas de moteur par seconde (le même que le solo).
  final int stepsPerSecond;

  /// Sensibilité de raquette de ce joueur (0 à 100), lue à l'entrée du
  /// multijoueur et fixe pendant tout le parcours. L'invité l'annonce dans
  /// `join` ; l'hôte l'applique à sa propre raquette.
  final int paddleSensitivity;

  /// Plafond commun des raquettes, en unités de terrain par seconde (celui
  /// de la sensibilité 100). Chaque joueur garde sa propre vitesse maximale
  /// ([myPaddleMaxSpeed]), jamais au-delà de ce plafond.
  final double paddleMaxSpeed;

  /// Vitesse maximale de ma raquette, en unités de terrain par seconde :
  /// celle de ma sensibilité, bornée au plafond commun. L'hôte l'impose au
  /// moteur ; l'invité borne sa raquette affichée en local à cette vitesse.
  double get myPaddleMaxSpeed =>
      min(PaddleSensitivity.maxSpeed(paddleSensitivity), paddleMaxSpeed);

  /// Rattrapage plafonné, comme en solo.
  final int maxStepsPerFrame;

  /// Durée du compte à rebours avant le premier service (L4).
  final int countdownSeconds;

  /// Délai de recherche après lequel la liste vide affiche J3.
  final Duration searchTimeout;

  /// Silence de l'autre téléphone au-delà duquel l'indicateur réseau passe
  /// au rouge.
  final Duration degradedAfter;

  /// Demi-largeur dessinée d'une raquette, en unités de terrain : la
  /// raquette fait `paddleHalfWidth × largeur du terrain` pixels de part et
  /// d'autre de son centre.
  static const double paddleHalfWidth = DuelEngine.visualHalfWidth;

  /// Points pour gagner (« DUEL · PREMIER À 5 »).
  static const int pointsToWin = DuelEngine.pointsToWin;

  /// Aller-retour au-delà duquel la connexion est jugée dégradée.
  static const Duration slowRoundTrip = Duration(milliseconds: 400);

  /// Compensation maximale de la latence au départ du compte à rebours.
  static const Duration maxLatencyCompensation = Duration(milliseconds: 150);

  static const String _hostId = 'host';
  static const String _guestId = 'guest';

  final MultiplayerNetwork _network;
  final DuelStatsStore _stats;
  final Random _random;
  final MonotonicClock _clock;
  final StreamController<MultiplayerEvent> _events =
      StreamController<MultiplayerEvent>.broadcast();

  String _playerName;
  MultiplayerStage _stage = MultiplayerStage.idle;
  MultiplayerRole? _role;
  GameRoom? _room;
  String? _gameName;

  MultiplayerIncident? _incident;
  String? _incidentPeerName;
  DisconnectReason? _incidentReason;
  JoinFailure? _joinFailure;

  // Hôte
  HostSession? _host;
  int? _guestSensitivity; // sensibilité annoncée par l'invité
  GameAdvertiser? _advertiser;
  DuelEngine? _engine;
  int _pendingSteps = 0;

  // Invité
  ClientSession? _client;
  GameFinder? _finder;
  StreamSubscription<List<DiscoveredGame>>? _finderSubscription;
  List<DiscoveredGame> _games = const [];
  BrowseStatus _browseStatus = BrowseStatus.searching;
  Timer? _searchTimer;
  DiscoveredGame? _target;
  bool _browsingSuspended = false;
  final StateInterpolator _interpolator = StateInterpolator();
  double _localPaddleX = 0; // invité : ma raquette, à l'écran

  StreamSubscription<SessionEvent>? _sessionSubscription;

  // Compte à rebours
  Duration? _countdownEnd;
  int? _countdownValue;
  Timer? _countdownTimer;

  // Duel
  GameState? _state; // dernier état (hôte : moteur ; invité : reçu)
  DuelView? _view;
  final NetRateLimiter _sendLimiter = NetRateLimiter();
  Duration _lastPeerMessage = Duration.zero;
  ConnectionQuality _quality = ConnectionQuality.good;
  DuelResult? _result;
  bool _iWantRematch = false;
  bool _opponentWantsRematch = false;

  // Chaque démarrage et chaque fermeture change d'époque : une opération
  // asynchrone qui revient d'une époque passée est abandonnée.
  int _epoch = 0;
  bool _disposed = false;

  static MonotonicClock _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  // ---------------------------------------------------------------------------
  // État lisible
  // ---------------------------------------------------------------------------

  /// Événements ponctuels (sons, vibrations). Flux diffusé.
  Stream<MultiplayerEvent> get events => _events.stream;

  /// Étape du parcours : l'écran à afficher.
  MultiplayerStage get stage => _stage;

  /// Rôle de ce téléphone, `null` au menu.
  MultiplayerRole? get role => _role;
  bool get isHost => _role == MultiplayerRole.host;

  /// Ma place dans le duel : joueur 1 pour l'hôte, joueur 2 pour l'invité.
  PlayerSlot? get mySlot => switch (_role) {
        MultiplayerRole.host => PlayerSlot.player1,
        MultiplayerRole.guest => PlayerSlot.player2,
        null => null,
      };

  /// Mon pseudo (nettoyé : sans espaces aux bords, 20 caractères au plus).
  String get playerName => _playerName;

  /// Change le pseudo. Pris en compte à la prochaine création ou connexion.
  set playerName(String value) {
    _playerName = cleanPlayerName(value);
    _notify();
  }

  /// Nom de la partie : « Partie de Léa » (la mienne, ou celle rejointe).
  String? get gameName => _gameName;

  /// Salon (phase, joueurs, statut Prêt). `null` hors partie.
  GameRoom? get room => _room;
  DuelPhase? get phase => _room?.phase;

  /// Moi et l'autre joueur, d'après le salon.
  Player? get me => _slotPlayer(mySlot);
  Player? get opponent => _slotPlayer(mySlot?.opponent);

  /// Hôte : sensibilité de raquette de l'invité (annoncée, ou la valeur par
  /// défaut s'il ne l'a pas annoncée), `null` sans invité. Invité : `null`.
  int? get opponentPaddleSensitivity => _guestSensitivity;

  Player? _slotPlayer(PlayerSlot? slot) =>
      slot == null ? null : _room?.playerIn(slot);

  bool get amReady => me?.ready ?? false;
  bool get opponentReady => opponent?.ready ?? false;

  /// Le bouton Prêt est-il actif ? (Salon, avec deux joueurs.)
  bool get canSetReady =>
      _stage == MultiplayerStage.lobby && (_room?.phase.isLobby ?? false);

  /// Parties trouvées (J2), triées par nom, pleines comprises.
  List<DiscoveredGame> get games => _games;
  BrowseStatus get browseStatus => _browseStatus;

  /// Partie en cours de connexion, ou dernière tentée (pour « Réessayer »).
  DiscoveredGame? get joiningGame => _target;

  /// Chiffre du compte à rebours (3, 2, 1), `null` hors compte à rebours.
  int? get countdownValue => _countdownValue;

  /// Positions à dessiner, déjà dans le repère de ce téléphone (ma raquette
  /// en bas, y = 1). `null` avant le premier état.
  DuelView? get view => _view;

  /// Faux pendant la pause qui suit un point (D2 : « sans balle »).
  bool get ballVisible {
    final state = _state;
    return state != null && !(state.isServing && state.lastScorer != null);
  }

  int get myScore => _view?.myScore ?? 0;
  int get opponentScore => _view?.opponentScore ?? 0;

  /// Pause qui suit un point (D2), ou `null` pendant le jeu.
  PointInfo? get pointInfo {
    final state = _state;
    final slot = mySlot;
    if (state == null || slot == null || _stage != MultiplayerStage.playing) {
      return null;
    }
    final scorer = state.lastScorer;
    if (!state.isServing || scorer == null) return null;
    final mine = scorer == slot;
    return PointInfo(
      scoredByMe: mine,
      scorerName: _slotPlayer(scorer)?.name ?? '',
      exitEdge: mine ? ScreenEdge.top : ScreenEdge.bottom,
      resumeIn: (state.serveMs + 999) ~/ 1000,
    );
  }

  /// Indicateur réseau du duel.
  ConnectionQuality get connectionQuality => _quality;

  /// Dernier aller-retour mesuré avec l'autre téléphone.
  Duration? get roundTripTime => _host?.roundTripTime ?? _client?.roundTripTime;

  /// Résultat du dernier duel (V1, V2).
  DuelResult? get result => _result;

  RematchStatus get rematchStatus {
    if (_iWantRematch) return RematchStatus.waitingForOpponent;
    if (_opponentWantsRematch) return RematchStatus.opponentAsked;
    return RematchStatus.none;
  }

  /// Incident à afficher (étape [MultiplayerStage.incident]).
  MultiplayerIncident? get incident => _incident;

  /// Pseudo de l'autre joueur, pour « Tom s'est déconnecté ».
  String? get incidentPeerName => _incidentPeerName;

  /// Départ volontaire (`left`) ou connexion perdue (`timeout`, `closed`).
  DisconnectReason? get incidentReason => _incidentReason;

  /// Cause d'un échec de connexion (X3).
  JoinFailure? get joinFailure => _joinFailure;

  /// Statistiques des duels (« Victoires / Défaites »).
  int get duelWins => _stats.wins;
  int get duelLosses => _stats.losses;

  // ---------------------------------------------------------------------------
  // Utilitaires publics
  // ---------------------------------------------------------------------------

  /// Pseudo nettoyé : sans espaces aux bords, [Player.maxNameLength]
  /// caractères au plus, « Joueur » s'il est vide.
  static String cleanPlayerName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Joueur';
    return trimmed.length <= Player.maxNameLength
        ? trimmed
        : trimmed.substring(0, Player.maxNameLength).trim();
  }

  /// « Partie de Tom », « Partie d'Inès ».
  static String gameNameFor(String pseudo) {
    final name = cleanPlayerName(pseudo);
    const vowels = 'aeiouyàâäéèêëîïôöùûüœæAEIOUYÀÂÄÉÈÊËÎÏÔÖÙÛÜŒÆ';
    return vowels.contains(name[0]) ? "Partie d'$name" : 'Partie de $name';
  }

  // ---------------------------------------------------------------------------
  // Hôte
  // ---------------------------------------------------------------------------

  /// M1 « Créer une partie » : ouvre la partie et l'annonce. Étape
  /// `creating`, puis `lobby` (L1), ou l'incident `networkUnavailable`.
  Future<void> createGame() async {
    if (_disposed) return;
    await _teardown();
    final epoch = _epoch;
    _role = MultiplayerRole.host;
    _clearIncident();
    final name = _playerName;
    _gameName = gameNameFor(name);
    _room = GameRoom(id: _randomId(), host: Player(id: _hostId, name: name));
    _setStage(MultiplayerStage.creating);

    final session = _network.createHostSession(name);
    _host = session;
    _sessionSubscription = session.events.listen(_onHostEvent);
    final int port;
    try {
      port = await session.start();
    } on Object catch (e) {
      if (epoch != _epoch) return;
      _log('ouverture de la partie impossible : $e');
      await _teardown();
      _role = MultiplayerRole.host;
      _showIncident(MultiplayerIncident.networkUnavailable);
      return;
    }
    if (epoch != _epoch) return;

    final advertiser =
        _network.createAdvertiser(gameName: _gameName!, gamePort: port);
    _advertiser = advertiser;
    try {
      await advertiser.start();
    } on Object catch (e) {
      // La partie reste ouverte ; elle ne sera simplement pas annoncée.
      _log('annonce de la partie impossible : $e');
    }
    if (epoch != _epoch) return;
    _setStage(MultiplayerStage.lobby);
  }

  void _onHostEvent(SessionEvent event) {
    if (_disposed) return;
    switch (event) {
      case PeerConnected(:final name, :final sensitivity):
        _hostGuestJoined(name, sensitivity);
      case PeerDisconnected(:final reason):
        _hostGuestLeft(reason);
      case MessageReceived(:final message):
        _lastPeerMessage = _clock();
        _hostMessage(message);
    }
  }

  void _hostGuestJoined(String rawName, int? sensitivity) {
    final room = _room;
    if (room == null) return;
    // Un joueur arrive pendant l'écran X1 : retour au salon avec lui
    if (room.phase == DuelPhase.disconnected) room.reopen();
    if (room.phase != DuelPhase.waiting) {
      _log(
          'arrivée de $rawName inattendue en phase ${room.phase.name}, renvoyé');
      _host?.kickClient(reason: 'busy');
      return;
    }
    final name = cleanPlayerName(rawName);
    room.join(Player(id: _guestId, name: name));
    // Invité sans sensibilité annoncée (app plus ancienne) : valeur par défaut
    _guestSensitivity =
        PaddleSensitivity.clamp(sensitivity ?? PaddleSensitivity.defaultValue);
    _advertiser?.update(players: 2);
    _clearIncident();
    _setStage(MultiplayerStage.lobby, notify: false);
    _emit(OpponentJoined(name));
    _notify();
  }

  void _hostGuestLeft(DisconnectReason reason) {
    final room = _room;
    final guest = room?.guest;
    _advertiser?.update(players: 1);
    if (room == null || guest == null) return;
    _guestSensitivity = null;
    final wasLobby = room.phase.isLobby;
    room.guestLeft();
    _stopCountdown();
    _resetDuel();
    _emit(OpponentLeft(guest.name));
    if (wasLobby) {
      _setStage(MultiplayerStage.lobby);
    } else {
      _showIncident(MultiplayerIncident.opponentLeft,
          peerName: guest.name, reason: reason);
    }
  }

  void _hostMessage(NetMessage message) {
    final room = _room;
    if (room == null) return;
    switch (message) {
      case ReadyMessage(:final ready):
        if (_stage != MultiplayerStage.lobby || !room.phase.isLobby) return;
        room.setReady(_guestId, ready);
        _notify();
        _hostMaybeStart();
      case PaddleMessage(:final x):
        if (_stage == MultiplayerStage.countdown ||
            _stage == MultiplayerStage.playing) {
          _engine?.setPlayer2Target(x);
        }
      case RematchMessage():
        if (_stage != MultiplayerStage.finished || _opponentWantsRematch) {
          return;
        }
        _opponentWantsRematch = true;
        _emit(RematchRequested(room.guest?.name ?? ''));
        _notify();
        _hostMaybeRematch();
      default:
        break;
    }
  }

  void _hostMaybeStart() {
    final room = _room;
    if (room == null || room.phase != DuelPhase.ready) return;
    room.startCountdown();
    final engine = _engine ??= DuelEngine(
        stepsPerSecond: stepsPerSecond,
        paddleMaxSpeed: paddleMaxSpeed,
        random: _random);
    // Chacun sa vitesse maximale, sous le plafond commun du moteur
    engine.setPaddleMaxSpeed(PlayerSlot.player1, myPaddleMaxSpeed);
    engine.setPaddleMaxSpeed(
        PlayerSlot.player2,
        PaddleSensitivity.maxSpeed(
            _guestSensitivity ?? PaddleSensitivity.defaultValue));
    engine.reset();
    _host?.sendStart(countdownSeconds);
    _resetDuel();
    _state = engine.snapshot();
    _updateView();
    _beginCountdown(_clock() + Duration(seconds: countdownSeconds));
  }

  void _hostMaybeRematch() {
    final room = _room;
    if (room == null || !_iWantRematch || !_opponentWantsRematch) return;
    if (room.phase != DuelPhase.finished) return;
    room.rematch();
    // Demander la revanche vaut « Prêt » : la partie repart aussitôt
    room.setReady(_hostId, true);
    room.setReady(_guestId, true);
    _hostMaybeStart();
  }

  // ---------------------------------------------------------------------------
  // Invité
  // ---------------------------------------------------------------------------

  /// M1 « Rejoindre une partie », J3 « Actualiser » après une erreur, ou
  /// retour à la liste : lance la recherche. Étape `browsing`.
  Future<void> startBrowsing() async {
    if (_disposed) return;
    await _teardown();
    final epoch = _epoch;
    _role = MultiplayerRole.guest;
    _clearIncident();
    _games = const [];
    _browseStatus = BrowseStatus.searching;
    _setStage(MultiplayerStage.browsing);

    final finder = _network.createFinder();
    _finder = finder;
    _finderSubscription = finder.games.listen(_onGames);
    try {
      await finder.start();
    } on Object catch (e) {
      if (epoch != _epoch) return;
      _log('recherche impossible : $e');
      await _teardown();
      _role = MultiplayerRole.guest;
      _showIncident(MultiplayerIncident.networkUnavailable);
      return;
    }
    if (epoch != _epoch) return;
    _armSearchTimer();
  }

  /// J2/J3 « Actualiser » : vide la liste et relance la recherche.
  void refreshGames() {
    final finder = _finder;
    if (finder == null || _stage != MultiplayerStage.browsing) return;
    _games = const [];
    _browseStatus = BrowseStatus.searching;
    finder.refresh();
    _armSearchTimer();
    _notify();
  }

  void _armSearchTimer() {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchTimeout, () {
      if (_disposed || _finder == null) return;
      if (_browseStatus == BrowseStatus.searching && _games.isEmpty) {
        _browseStatus = BrowseStatus.empty;
        _notify();
      }
    });
  }

  void _onGames(List<DiscoveredGame> games) {
    if (_disposed) return;
    _games = List.unmodifiable(games);
    if (games.isNotEmpty) {
      _browseStatus = BrowseStatus.found;
      _searchTimer?.cancel();
    } else if (_browseStatus == BrowseStatus.found) {
      // Les parties ont disparu (Hôte parti, Wi-Fi changé)
      _browseStatus = BrowseStatus.empty;
    }
    _notify();
  }

  /// J2 « Rejoindre » : se connecte à [game]. Étape `connecting`, puis
  /// `lobby` (L3), ou l'incident `joinFailed` avec [joinFailure].
  Future<void> joinGame(DiscoveredGame game) async {
    if (_disposed || _role != MultiplayerRole.guest) return;
    if (_stage != MultiplayerStage.browsing &&
        _stage != MultiplayerStage.incident) {
      return;
    }
    await _closeClient();
    final epoch = _epoch;
    _target = game;
    _gameName = game.name;
    _clearIncident();
    _setStage(MultiplayerStage.connecting);

    final session = _network.createClientSession(_playerName,
        paddleSensitivity: paddleSensitivity);
    _client = session;
    _sessionSubscription =
        session.events.listen((event) => _onGuestEvent(session, event));
    final result = await session.connect(game.address, game.port);
    if (epoch != _epoch || !identical(_client, session) || _disposed) {
      await session.close();
      return;
    }
    switch (result) {
      case JoinAccepted(:final hostName):
        final room = GameRoom(
          id: game.id.length <= GameRoom.maxIdLength
              ? game.id
              : game.id.substring(0, GameRoom.maxIdLength),
          host: Player(id: _hostId, name: cleanPlayerName(hostName)),
        );
        room.join(Player(id: _guestId, name: _playerName));
        _room = room;
        _gameName = gameNameFor(room.host.name);
        _stopFinder();
        _setStage(MultiplayerStage.lobby);
      case JoinRejected(:final reason):
        await _closeClient();
        _showIncident(MultiplayerIncident.joinFailed,
            joinFailure: switch (reason) {
              RejectReason.full => JoinFailure.full,
              RejectReason.version => JoinFailure.versionMismatch,
              _ => JoinFailure.refused,
            });
      case JoinFailed():
        await _closeClient();
        _showIncident(MultiplayerIncident.joinFailed,
            joinFailure: JoinFailure.unreachable);
    }
  }

  /// X3 « Réessayer » : retente la dernière partie (ou relance la création
  /// ou la recherche après `networkUnavailable`).
  Future<void> retry() async {
    if (_disposed) return;
    if (_incident == MultiplayerIncident.networkUnavailable) {
      return isHost ? createGame() : startBrowsing();
    }
    final target = _target;
    if (_incident == MultiplayerIncident.joinFailed && target != null) {
      await joinGame(target);
    }
  }

  /// X3 « Retour » : revient à la liste des parties.
  Future<void> backToBrowsing() async {
    if (_disposed) return;
    if (_role == MultiplayerRole.guest &&
        _finder != null &&
        _stage == MultiplayerStage.incident) {
      _clearIncident();
      _setStage(MultiplayerStage.browsing);
      return;
    }
    await startBrowsing();
  }

  void _onGuestEvent(ClientSession session, SessionEvent event) {
    if (_disposed || !identical(session, _client)) return;
    switch (event) {
      case PeerConnected():
        break; // traité par le résultat de connect()
      case PeerDisconnected(:final reason):
        _guestHostLeft(reason);
      case MessageReceived(:final message):
        _lastPeerMessage = _clock();
        _guestMessage(message);
    }
  }

  void _guestHostLeft(DisconnectReason reason) {
    final hostName = _room?.host.name;
    final wasInGame = _room != null;
    _client = null;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _stopCountdown();
    _resetDuel();
    _room?.disconnect();
    _room = null;
    if (!wasInGame) return;
    _emit(OpponentLeft(hostName ?? ''));
    _showIncident(MultiplayerIncident.hostLeft,
        peerName: hostName, reason: reason);
  }

  void _guestMessage(NetMessage message) {
    final room = _room;
    if (room == null) return;
    switch (message) {
      case ReadyMessage(:final ready):
        if (!room.phase.isLobby) return;
        room.setReady(_hostId, ready);
        _notify();
      case StartMessage(:final countdown):
        _guestStart(room, countdown);
      case GameStateMessage(:final state):
        _guestState(state);
      case GameOverMessage(:final winner, :final state):
        _guestGameOver(winner, state);
      case RematchMessage():
        if (_stage != MultiplayerStage.finished || _opponentWantsRematch) {
          return;
        }
        _opponentWantsRematch = true;
        _emit(RematchRequested(room.host.name));
        _notify();
      default:
        break;
    }
  }

  void _guestStart(GameRoom room, int countdown) {
    // L'hôte fait autorité : son « start » l'emporte sur un « plus prêt »
    // envoyé au même instant.
    try {
      if (room.phase == DuelPhase.finished) room.rematch();
      if (!room.phase.isLobby) {
        _log('start reçu en phase ${room.phase.name}, ignoré');
        return;
      }
      room.setReady(_hostId, true);
      room.setReady(_guestId, true);
      room.startCountdown();
    } on StateError catch (e) {
      _log('start ignoré : ${e.message}');
      return;
    }
    _resetDuel();
    _interpolator.clear();
    _localPaddleX = 0;
    // Le « start » a mis une demi-aller-retour à arriver : le compte à
    // rebours finit en même temps que celui de l'hôte.
    final rtt = _client?.roundTripTime ?? Duration.zero;
    var compensation = rtt ~/ 2;
    if (compensation > maxLatencyCompensation) {
      compensation = maxLatencyCompensation;
    }
    _beginCountdown(_clock() + Duration(seconds: countdown) - compensation);
  }

  void _guestState(Map<String, dynamic> json) {
    if (_stage != MultiplayerStage.countdown &&
        _stage != MultiplayerStage.playing) {
      return;
    }
    final GameState state;
    try {
      state = GameState.fromJson(json);
    } on FormatException catch (e) {
      _log('game_state invalide ignoré : ${e.message}');
      return;
    }
    // L'hôte joue déjà : fin du compte à rebours sans attendre
    if (_stage == MultiplayerStage.countdown &&
        state.phase == DuelPhase.playing) {
      _finishCountdown();
    }
    if (_stage != MultiplayerStage.playing) return;
    final previous = _state;
    if (previous != null && state.tick < previous.tick) {
      return; // état plus ancien
    }
    final changedScore = _emitStateEvents(previous, state);
    _state = state;
    _interpolator.push(state, _clock());
    _updateView();
    if (changedScore) _notify();
  }

  // Sons et vibrations côté invité, déduits de deux états successifs.
  // Retourne vrai si le score a changé.
  bool _emitStateEvents(GameState? previous, GameState state) {
    if (previous == null) return false;
    if (state.hits > previous.hits) {
      // Après un renvoi du joueur 2 (en haut), la balle descend (vy > 0)
      _emit(PaddleHit(mine: state.ballVY > 0));
    }
    var changed = false;
    if (state.score2 > previous.score2) {
      _emit(const PointScored(mine: true));
      changed = true;
    }
    if (state.score1 > previous.score1) {
      _emit(const PointScored(mine: false));
      changed = true;
    }
    return changed;
  }

  void _guestGameOver(PlayerSide side, Map<String, dynamic>? json) {
    final room = _room;
    if (room == null) return;
    if (_stage != MultiplayerStage.playing &&
        _stage != MultiplayerStage.countdown) {
      return;
    }
    GameState? state;
    if (json != null) {
      try {
        state = GameState.fromJson(json);
      } on FormatException catch (e) {
        _log('état final invalide ignoré : ${e.message}');
      }
    }
    final winner =
        side == PlayerSide.host ? PlayerSlot.player1 : PlayerSlot.player2;
    final previous = _state;
    state ??= previous;
    if (state != null) _emitStateEvents(previous, state);
    _stopCountdown();
    try {
      if (room.phase == DuelPhase.countdown) room.startPlaying();
      room.finish();
    } on StateError catch (e) {
      _log('fin de partie : ${e.message}');
    }
    _finishDuel(state, winner);
  }

  // ---------------------------------------------------------------------------
  // Salon, revanche, départ
  // ---------------------------------------------------------------------------

  /// L2/L3 « Prêt » / « Je ne suis plus prêt ».
  void setReady(bool ready) {
    final room = _room;
    final slot = mySlot;
    if (!canSetReady || room == null || slot == null) return;
    if (amReady == ready) return;
    room.setReady(slot == PlayerSlot.player1 ? _hostId : _guestId, ready);
    if (isHost) {
      _host?.sendReady(ready);
      _notify();
      _hostMaybeStart();
    } else {
      _client?.sendReady(ready);
      _notify();
    }
  }

  void toggleReady() => setReady(!amReady);

  /// V1/V2 « Rejouer ». Le duel repart quand les deux l'ont demandé, sans
  /// recréer la partie.
  void requestRematch() {
    if (_stage != MultiplayerStage.finished || _iWantRematch) return;
    _iWantRematch = true;
    if (isHost) {
      _host?.sendRematch();
      _notify();
      _hostMaybeRematch();
    } else {
      _client?.sendRematch();
      _notify();
    }
  }

  /// X1 « Retour au salon » (hôte) : le salon attend un nouveau joueur.
  void backToLobby() {
    final room = _room;
    if (!isHost || room == null || _host == null) return;
    if (room.phase == DuelPhase.disconnected) room.reopen();
    _clearIncident();
    _setStage(MultiplayerStage.lobby);
  }

  /// « Annuler la partie », « Quitter », X2 « Retour au menu » : quitte
  /// proprement à tout moment. L'autre téléphone reçoit `leave` ; session,
  /// annonce et recherche sont fermées. Étape `idle`.
  Future<void> leave() async {
    if (_disposed) return;
    await _teardown();
    _role = null;
    _clearIncident();
    _setStage(MultiplayerStage.idle);
  }

  /// Ferme l'incident affiché avec l'action par défaut de son écran.
  Future<void> dismissIncident() async {
    switch (_incident) {
      case MultiplayerIncident.opponentLeft:
        backToLobby();
      case MultiplayerIncident.joinFailed:
        await backToBrowsing();
      case MultiplayerIncident.hostLeft ||
            MultiplayerIncident.networkUnavailable ||
            MultiplayerIncident.closedInBackground:
        await leave();
      case null:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Arrière-plan
  // ---------------------------------------------------------------------------

  /// À appeler à chaque changement d'état de l'app (voir [onAppPaused]).
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        onAppPaused();
      case AppLifecycleState.resumed:
        onAppResumed();
      default:
        break;
    }
  }

  /// L'app passe en arrière-plan : pas de pause en duel, la partie est
  /// fermée (l'autre téléphone reçoit `leave`) et l'incident
  /// `closedInBackground` sera affiché au retour. Pendant la recherche, la
  /// découverte est seulement suspendue (socket UDP et verrou multicast
  /// rendus) et reprend au retour.
  void onAppPaused() {
    if (_disposed) return;
    switch (_stage) {
      case MultiplayerStage.browsing:
        _browsingSuspended = true;
        _stopFinder();
        _searchTimer?.cancel();
      case MultiplayerStage.creating ||
            MultiplayerStage.connecting ||
            MultiplayerStage.lobby ||
            MultiplayerStage.countdown ||
            MultiplayerStage.playing ||
            MultiplayerStage.finished:
        _closeInBackground();
      case MultiplayerStage.incident:
        // X1 : la partie de l'hôte est encore ouverte
        if (_host != null) _closeInBackground();
      case MultiplayerStage.idle:
        break;
    }
  }

  void _closeInBackground() {
    final role = _role;
    unawaited(_teardown());
    _role = role;
    _showIncident(MultiplayerIncident.closedInBackground);
  }

  /// L'app revient au premier plan : la recherche suspendue reprend.
  void onAppResumed() {
    if (_disposed || !_browsingSuspended) return;
    _browsingSuspended = false;
    if (_stage == MultiplayerStage.browsing) unawaited(startBrowsing());
  }

  // ---------------------------------------------------------------------------
  // Compte à rebours
  // ---------------------------------------------------------------------------

  void _beginCountdown(Duration end) {
    _countdownEnd = end;
    _countdownValue = null;
    _iWantRematch = false;
    _opponentWantsRematch = false;
    _result = null;
    _setStage(MultiplayerStage.countdown, notify: false);
    _countdownTimer?.cancel();
    // Vérification fréquente plutôt qu'un minuteur par chiffre : un chiffre
    // s'affiche au plus 10 ms après l'instant prévu, sur les deux téléphones.
    _countdownTimer = Timer.periodic(
        const Duration(milliseconds: 10), (_) => _pollCountdown());
    _pollCountdown();
    _notify();
  }

  void _pollCountdown() {
    final end = _countdownEnd;
    if (_disposed || end == null || _stage != MultiplayerStage.countdown) {
      return;
    }
    final remaining = end - _clock();
    if (remaining <= Duration.zero) {
      _finishCountdown();
      return;
    }
    final value = (remaining.inMicroseconds + 999999) ~/ 1000000;
    if (value != _countdownValue) {
      _countdownValue = value;
      _emit(CountdownTick(value));
      _notify();
    }
  }

  void _finishCountdown() {
    _stopCountdown();
    final room = _room;
    if (room == null) return;
    try {
      room.startPlaying();
    } on StateError catch (e) {
      _log('début du duel : ${e.message}');
      return;
    }
    _pendingSteps = 0;
    _sendLimiter.reset();
    _lastPeerMessage = _clock();
    _quality = ConnectionQuality.good;
    _setStage(MultiplayerStage.playing, notify: false);
    _emit(const DuelStarted());
    if (isHost) {
      final engine = _engine;
      if (engine != null) {
        _state = engine.snapshot();
        _host?.sendGameState(_state!.toJson());
      }
    }
    _updateView();
    _notify();
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownEnd = null;
    _countdownValue = null;
  }

  // ---------------------------------------------------------------------------
  // Boucle de jeu
  // ---------------------------------------------------------------------------

  /// À appeler une fois par image par l'écran du duel (et, sans effet,
  /// pendant le compte à rebours), avec le temps écoulé depuis l'image
  /// précédente et la vitesse voulue de ma raquette en unités de terrain par
  /// seconde, dans le repère de l'écran (positive vers la droite) : celle de
  /// `TiltControl.update(dt)` réglée sur ma sensibilité, comme en solo. Elle
  /// est bornée à [myPaddleMaxSpeed].
  ///
  /// Hôte : joue `stepsPerSecond` pas de moteur par seconde écoulée (au plus
  /// [maxStepsPerFrame] par image) et envoie l'état à 30 Hz.
  /// Invité : déplace sa raquette en local, l'envoie à 30 Hz, interpole
  /// l'état reçu.
  void onFrame(Duration dt, double localPaddleSpeed) {
    if (_disposed) return;
    if (_stage == MultiplayerStage.countdown) _pollCountdown();
    if (_stage != MultiplayerStage.playing) return;
    final now = _clock();
    final double maxSpeed = myPaddleMaxSpeed;
    final double speed = localPaddleSpeed.isFinite
        ? localPaddleSpeed.clamp(-maxSpeed, maxSpeed).toDouble()
        : 0.0;
    final int micros = dt.isNegative ? 0 : dt.inMicroseconds;
    if (isHost) {
      _hostFrame(micros, speed, now);
    } else {
      _guestFrame(micros, speed, now);
    }
    _updateQuality(now);
    _notify();
  }

  void _hostFrame(int micros, double speed, Duration now) {
    final engine = _engine;
    if (engine == null) return;
    _pendingSteps += micros * stepsPerSecond;
    int steps = _pendingSteps ~/ 1000000;
    _pendingSteps %= 1000000;
    if (steps > maxStepsPerFrame) steps = maxStepsPerFrame;

    // Vitesse en unités par pas, comme `playerSpeed` en solo
    engine.player1Speed = speed / stepsPerSecond;
    for (int i = 0; i < steps; i++) {
      for (final event in engine.tick()) {
        switch (event.type) {
          case DuelEventType.paddleHit:
            _emit(PaddleHit(mine: event.player == PlayerSlot.player1));
          case DuelEventType.pointScored:
            _emit(PointScored(mine: event.player == PlayerSlot.player1));
          case DuelEventType.gameWon || DuelEventType.served:
            break;
        }
      }
      if (engine.isFinished) break;
    }
    final state = engine.snapshot();
    _state = state;
    if (engine.isFinished) {
      _hostFinish(engine, state);
      return;
    }
    if (_sendLimiter.shouldSend(now)) _host?.sendGameState(state.toJson());
    _updateView();
  }

  void _hostFinish(DuelEngine engine, GameState state) {
    final winner = engine.winner!;
    try {
      _room?.finish();
    } on StateError catch (e) {
      _log('fin de partie : ${e.message}');
    }
    _host?.sendGameOver(
        winner == PlayerSlot.player1 ? PlayerSide.host : PlayerSide.client,
        state: state.toJson());
    _finishDuel(state, winner);
  }

  void _guestFrame(int micros, double speed, Duration now) {
    // Ma raquette bouge tout de suite à l'écran, à la vitesse que le moteur
    // de l'hôte lui permettra : il la suit avec la seule latence du réseau.
    // Image très longue : plafonnée comme le rattrapage du moteur
    final double maxSeconds = maxStepsPerFrame / stepsPerSecond;
    final double dt = min(micros / 1000000, maxSeconds);
    _localPaddleX = (_localPaddleX + speed * dt).clamp(-1.0, 1.0).toDouble();
    if (_sendLimiter.shouldSend(now)) {
      _client?.sendPaddle(
          DuelView.courtXFromScreen(_localPaddleX, PlayerSlot.player2));
    }
    _updateView(now);
  }

  void _updateView([Duration? now]) {
    final slot = mySlot;
    if (slot == null) return;
    if (isHost) {
      final state = _state;
      _view = state == null ? null : DuelView.of(state, slot);
      return;
    }
    final sample = _interpolator.sample(now ?? _clock()) ?? _state;
    if (sample == null) {
      // Pas encore d'état de l'hôte : terrain au repos, ma raquette locale
      _view = _stage == MultiplayerStage.playing
          ? DuelView(
              ballX: 0,
              ballY: 0,
              ballVX: 0,
              ballVY: 0,
              myPaddleX: _localPaddleX,
              opponentPaddleX: 0,
              myScore: 0,
              opponentScore: 0,
            )
          : null;
      return;
    }
    final v = DuelView.of(sample, slot);
    final latest = _state ?? sample;
    _view = DuelView(
      ballX: v.ballX,
      ballY: v.ballY,
      ballVX: v.ballVX,
      ballVY: v.ballVY,
      myPaddleX:
          _stage == MultiplayerStage.playing ? _localPaddleX : v.myPaddleX,
      opponentPaddleX: v.opponentPaddleX,
      myScore: latest.scoreOf(slot),
      opponentScore: latest.scoreOf(slot.opponent),
    );
  }

  void _updateQuality(Duration now) {
    final silent = now - _lastPeerMessage > degradedAfter;
    final rtt = roundTripTime;
    final slow = rtt != null && rtt > slowRoundTrip;
    _quality =
        (silent || slow) ? ConnectionQuality.degraded : ConnectionQuality.good;
  }

  void _finishDuel(GameState? state, PlayerSlot winner) {
    final slot = mySlot!;
    final won = winner == slot;
    final myScore = state?.scoreOf(slot) ?? (won ? pointsToWin : 0);
    final opponentScore =
        state?.scoreOf(slot.opponent) ?? (won ? 0 : pointsToWin);
    if (state != null) _state = state;
    _result = DuelResult(
      won: won,
      winnerName: _slotPlayer(winner)?.name ?? '',
      myScore: myScore,
      opponentScore: opponentScore,
      duration: Duration(milliseconds: state?.timeMs ?? 0),
      longestRally: state?.longestRally ?? 0,
    );
    _iWantRematch = false;
    _opponentWantsRematch = false;
    _stats.recordDuel(won: won);
    if (!isHost) _interpolator.clear();
    _updateView();
    _setStage(MultiplayerStage.finished, notify: false);
    _emit(DuelEnded(won: won));
    _notify();
  }

  void _resetDuel() {
    _state = null;
    _view = null;
    _result = null;
    _iWantRematch = false;
    _opponentWantsRematch = false;
    _pendingSteps = 0;
    _quality = ConnectionQuality.good;
  }

  // ---------------------------------------------------------------------------
  // Fermeture
  // ---------------------------------------------------------------------------

  Future<void> _closeClient() async {
    final client = _client;
    _client = null;
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    await client?.close();
  }

  void _stopFinder() {
    final finder = _finder;
    _finder = null;
    _finderSubscription?.cancel();
    _finderSubscription = null;
    _searchTimer?.cancel();
    _searchTimer = null;
    if (finder != null) unawaited(finder.stop());
  }

  // Ferme tout ce qui est ouvert. Les champs sont remis à zéro tout de
  // suite (de façon synchrone) ; seules les fermetures sont attendues.
  Future<void> _teardown() async {
    _epoch++;
    _stopCountdown();
    _stopFinder();
    _browsingSuspended = false;
    final subscription = _sessionSubscription;
    _sessionSubscription = null;
    final host = _host;
    final client = _client;
    final advertiser = _advertiser;
    _host = null;
    _client = null;
    _advertiser = null;
    _engine = null;
    _guestSensitivity = null;
    _room = null;
    _gameName = null;
    _target = null;
    _games = const [];
    _interpolator.clear();
    _localPaddleX = 0;
    _resetDuel();
    await subscription?.cancel();
    await Future.wait([
      if (advertiser != null) _quietly(advertiser.stop()),
      if (host != null) _quietly(host.close()),
      if (client != null) _quietly(client.close()),
    ]);
  }

  Future<void> _quietly(Future<void> future) async {
    try {
      await future;
    } on Object catch (e) {
      _log('fermeture : $e');
    }
  }

  /// Ferme la partie (l'autre téléphone reçoit `leave`), l'annonce, la
  /// recherche et les minuteurs. À appeler quand on quitte le multijoueur.
  @override
  void dispose() {
    if (_disposed) return;
    unawaited(_teardown());
    _disposed = true;
    _events.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Divers
  // ---------------------------------------------------------------------------

  void _setStage(MultiplayerStage stage, {bool notify = true}) {
    _stage = stage;
    if (notify) _notify();
  }

  void _showIncident(
    MultiplayerIncident incident, {
    String? peerName,
    DisconnectReason? reason,
    JoinFailure? joinFailure,
  }) {
    _incident = incident;
    _incidentPeerName = peerName;
    _incidentReason = reason;
    _joinFailure = joinFailure;
    _setStage(MultiplayerStage.incident);
  }

  void _clearIncident() {
    _incident = null;
    _incidentPeerName = null;
    _incidentReason = null;
    _joinFailure = null;
  }

  void _emit(MultiplayerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _log(String message) => _network.log('multijoueur : $message');

  String _randomId() =>
      List.generate(8, (_) => _random.nextInt(16).toRadixString(16)).join();
}
