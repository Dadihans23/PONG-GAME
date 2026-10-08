import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pong_game/game/game_tuning.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';
import 'package:pong_game/game/tilt_control.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/multiplayer/controller/controller.dart';
import 'package:pong_game/multiplayer/screens/duel_result_screen.dart';
import 'package:pong_game/multiplayer/screens/duel_screen.dart';
import 'package:pong_game/multiplayer/screens/join_screen.dart';
import 'package:pong_game/multiplayer/screens/lobby_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_menu_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_view_data.dart';
import 'package:pong_game/multiplayer/widgets/duel_incident.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/ui/pong_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Crée le contrôleur du parcours (les tests passent un réseau en mémoire).
typedef MultiplayerControllerFactory = MultiplayerController Function(
    String playerName);

/// Hôte du parcours multijoueur, du menu (M1) à la revanche.
///
/// Il crée **un seul** [MultiplayerController] à l'entrée et le libère à la
/// sortie (la partie est alors fermée et l'autre téléphone prévenu). Il
/// affiche l'écran qui correspond à `controller.stage`, sans empiler de
/// routes : une seule route pour tout le multijoueur, qui ne peut donc pas
/// se désynchroniser du contrôleur.
///
/// | Étape                 | Écran                                       |
/// |-----------------------|---------------------------------------------|
/// | `idle`, `creating`    | M1 (`creating` : roue sur « Créer »)        |
/// | `browsing`, `connecting` | J1, J2, J3 (`connecting` : « Connexion… ») |
/// | `lobby`, `countdown`  | L1 à L4 (compte à rebours par-dessus)       |
/// | `playing`             | D1, D2 (+ confirmation de sortie)           |
/// | `finished`            | V1, V2                                      |
/// | `incident`            | X1, X2, X3, partie pleine, pas de Wi-Fi…    |
///
/// Il fait aussi tourner la boucle d'affichage du duel (`Ticker` →
/// `controller.onFrame`, pendant le compte à rebours et le duel), lit
/// l'accéléromètre comme le solo, transmet l'arrière-plan au contrôleur et
/// joue les sons et vibrations des [MultiplayerEvent].
class MultiplayerFlow extends StatefulWidget {
  const MultiplayerFlow({
    super.key,
    required this.playerName,
    this.createController,
  });

  final String playerName;

  /// Par défaut : WebSocket et découverte UDP du réseau local.
  final MultiplayerControllerFactory? createController;

  @override
  State<MultiplayerFlow> createState() => _MultiplayerFlowState();
}

class _MultiplayerFlowState extends State<MultiplayerFlow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MultiplayerController _controller =
      widget.createController?.call(widget.playerName) ??
          MultiplayerController(
            playerName: widget.playerName,
            paddleSensitivity: _paddleSensitivity,
          );
  StreamSubscription<MultiplayerEvent>? _eventSubscription;

  // Réglages du joueur, lus une fois à l'entrée du multijoueur : la
  // sensibilité ne change pas pendant un duel
  final PongSettings _settings = PongSettings();
  late final bool _vibrate = _settings.vibrationEnabled;
  late final int _paddleSensitivity = _settings.paddleSensitivity;

  // Boucle d'affichage du duel et raquette, comme en solo
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  late final TiltControl _tilt =
      PaddleSensitivity.tiltControl(_paddleSensitivity);

  // Sons : un lecteur par son, chargé une fois, libéré à la sortie
  final GameSound _countdownSound = GameSound('sounds/shoot.mp3');
  final GameSound _hitballSound = GameSound('sounds/hitball.mp3');
  final GameSound _pointWonSound = GameSound('sounds/win1.mp3');
  final GameSound _pointLostSound = GameSound('sounds/lose1.mp3');
  final GameSound _winSound = GameSound('sounds/win.mp3');
  final GameSound _gameoverSound = GameSound('sounds/gameover.mp3');

  // Retour Android pendant le duel : confirmation par-dessus le terrain
  bool _confirmingLeave = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    _controller.addListener(_onControllerChanged);
    _eventSubscription = _controller.events.listen(_onEvent);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLoop();
    _ticker.dispose();
    _eventSubscription?.cancel();
    _controller.removeListener(_onControllerChanged);
    // Ferme la partie : l'autre téléphone reçoit `leave`
    _controller.dispose();
    _countdownSound.dispose();
    _hitballSound.dispose();
    _pointWonSound.dispose();
    _pointLostSound.dispose();
    _winSound.dispose();
    _gameoverSound.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleAppLifecycleState(state);
  }

  // ---------------------------------------------------------------------------
  // Boucle du duel
  // ---------------------------------------------------------------------------

  bool get _needsLoop =>
      _controller.stage == MultiplayerStage.countdown ||
      _controller.stage == MultiplayerStage.playing;

  void _onControllerChanged() {
    if (!mounted) return;
    if (_needsLoop) {
      _startLoop();
    } else {
      _stopLoop();
    }
    if (_controller.stage != MultiplayerStage.playing) _confirmingLeave = false;
    setState(() {});
  }

  void _startLoop() {
    if (_ticker.isActive) return;
    // Le capteur ne déplace rien : il mémorise la dernière inclinaison, que
    // la boucle lit à chaque image
    _accelSubscription ??=
        accelerometerEventStream(samplingPeriod: GameTuning.sensorPeriod)
            .listen(
      (event) => _tilt.setAcceleration(event.x, event.y, event.z),
      onError: (Object e) => debugPrint('Accéléromètre indisponible : $e'),
    );
    _lastElapsed = Duration.zero;
    _tilt.reset();
    _ticker.start();
  }

  void _stopLoop() {
    if (_ticker.isActive) _ticker.stop();
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void _onFrame(Duration elapsed) {
    final Duration dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    // Vitesse voulue en unités de terrain par seconde, comme en solo ; le
    // contrôleur rafraîchit l'écran par son notifyListeners
    final double speed = _tilt.update(dt.inMicroseconds / 1000000);
    _controller.onFrame(dt, speed);
  }

  // ---------------------------------------------------------------------------
  // Sons et vibrations
  // ---------------------------------------------------------------------------

  void _onEvent(MultiplayerEvent event) {
    switch (event) {
      case OpponentJoined():
        _haptic(HapticFeedback.mediumImpact);
      case CountdownTick():
        _countdownSound.play();
        _haptic(HapticFeedback.mediumImpact);
      case PaddleHit(:final mine):
        _hitballSound.play();
        if (mine) _haptic(HapticFeedback.lightImpact);
      case PointScored(:final mine):
        (mine ? _pointWonSound : _pointLostSound).play();
      case DuelEnded(:final won):
        (won ? _winSound : _gameoverSound).play();
        _haptic(HapticFeedback.vibrate);
      case OpponentLeft() || DuelStarted() || RematchRequested():
        break;
    }
  }

  void _haptic(Future<void> Function() feedback) {
    if (_vibrate) feedback();
  }

  // ---------------------------------------------------------------------------
  // Retour (bouton de l'en-tête et retour Android)
  // ---------------------------------------------------------------------------

  /// Retour sur les étapes sans `PopScope` propre (menu, recherche,
  /// incident). Le salon, le duel et l'écran de fin gèrent le leur.
  void _onBack() {
    switch (_controller.stage) {
      case MultiplayerStage.idle:
        Navigator.of(context).pop();
      case MultiplayerStage.creating ||
            MultiplayerStage.browsing ||
            MultiplayerStage.connecting:
        _controller.leave();
      case MultiplayerStage.incident:
        _controller.dismissIncident();
      case MultiplayerStage.lobby ||
            MultiplayerStage.countdown ||
            MultiplayerStage.playing ||
            MultiplayerStage.finished:
        break;
    }
  }

  void _onDuelBack() {
    // Second retour sur la confirmation : on reste (action la plus sûre)
    setState(() => _confirmingLeave = !_confirmingLeave);
  }

  // ---------------------------------------------------------------------------
  // Affichage
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final MultiplayerStage stage = _controller.stage;
    final bool ownPopScope = stage == MultiplayerStage.lobby ||
        stage == MultiplayerStage.countdown ||
        stage == MultiplayerStage.playing ||
        stage == MultiplayerStage.finished;
    return PopScope(
      // Au menu, le retour quitte le multijoueur ; ailleurs, il suit l'étape
      canPop: stage == MultiplayerStage.idle,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !ownPopScope) _onBack();
      },
      child: _buildStage(stage),
    );
  }

  Widget _buildStage(MultiplayerStage stage) {
    final c = _controller;
    switch (stage) {
      case MultiplayerStage.idle || MultiplayerStage.creating:
        return MultiplayerMenuScreen(
          playerName: c.playerName,
          creating: stage == MultiplayerStage.creating,
          onCreate: c.createGame,
          onJoin: c.startBrowsing,
          onBack: _onBack,
        );
      case MultiplayerStage.browsing || MultiplayerStage.connecting:
        return JoinScreen(
          data: _joinData(),
          onJoin: _joinById,
          onRefresh: c.refreshGames,
          onBack: _onBack,
        );
      case MultiplayerStage.lobby || MultiplayerStage.countdown:
        return LobbyScreen(
          data: _lobbyData(),
          onReadyChanged: c.setReady,
          onLeave: c.leave,
        );
      case MultiplayerStage.playing:
        return Stack(
          children: [
            DuelScreen(
              hud: _hudData(),
              field: c.view == null
                  ? DuelFieldData.initial
                  : DuelFieldData.fromView(c.view!),
              point: _pointData(),
              onLeaveRequested: _onDuelBack,
            ),
            if (_confirmingLeave)
              _IncidentLayer(
                scrim: true,
                incident: DuelIncident.leaveDuel(c.opponent?.name ?? ''),
                onAction: (action) {
                  if (action == DuelIncidentAction.secondary) {
                    c.leave();
                  } else {
                    setState(() => _confirmingLeave = false);
                  }
                },
              ),
          ],
        );
      case MultiplayerStage.finished:
        final DuelResultData? result = _resultData();
        if (result == null) return const _Blank();
        return DuelResultScreen(
          result: result,
          onRematch: c.requestRematch,
          onQuit: c.leave,
        );
      case MultiplayerStage.incident:
        return _incidentScreen();
    }
  }

  JoinViewData _joinData() {
    final c = _controller;
    return JoinViewData(
      searching: c.browseStatus == BrowseStatus.searching,
      games: [
        for (final game in c.games)
          DiscoveredGameViewData(
            id: game.id,
            hostName: hostNameOf(game.name),
            playerCount: game.players,
            maxPlayers: game.maxPlayers,
          ),
      ],
      joiningId: c.stage == MultiplayerStage.connecting
          ? c.joiningGame?.id
          : null,
    );
  }

  void _joinById(String id) {
    for (final game in _controller.games) {
      if (game.id == id) {
        _controller.joinGame(game);
        return;
      }
    }
  }

  LobbyViewData _lobbyData() {
    final c = _controller;
    final Player? me = c.me;
    final Player? other = c.opponent;
    return LobbyViewData(
      isHost: c.isHost,
      me: LobbyPlayerViewData(name: me?.name ?? c.playerName, ready: c.amReady),
      other: other == null
          ? null
          : LobbyPlayerViewData(
              name: other.name,
              ready: other.ready,
              // « Vient de rejoindre » tant que personne n'est prêt
              justJoined: c.isHost && !other.ready && !c.amReady,
            ),
      countdown: c.stage == MultiplayerStage.countdown
          ? (c.countdownValue ?? c.countdownSeconds)
          : null,
    );
  }

  DuelHudData _hudData() {
    final c = _controller;
    return DuelHudData(
      myName: c.me?.name ?? c.playerName,
      opponentName: c.opponent?.name ?? '',
      myScore: c.myScore,
      opponentScore: c.opponentScore,
      targetScore: MultiplayerController.pointsToWin,
      connection: c.connectionQuality == ConnectionQuality.degraded
          ? DuelConnection.weak
          : DuelConnection.good,
    );
  }

  DuelPointData? _pointData() {
    final PointInfo? info = _controller.pointInfo;
    if (info == null) return null;
    return DuelPointData(
      scorer: info.scoredByMe ? DuelSide.me : DuelSide.opponent,
      resumeIn: info.resumeIn > 0 ? info.resumeIn : null,
    );
  }

  DuelResultData? _resultData() {
    final c = _controller;
    final DuelResult? result = c.result;
    if (result == null) return null;
    return DuelResultData(
      myName: c.me?.name ?? c.playerName,
      opponentName: c.opponent?.name ?? '',
      myScore: result.myScore,
      opponentScore: result.opponentScore,
      duration: result.duration,
      longestRally: result.longestRally,
      rematch: switch (c.rematchStatus) {
        RematchStatus.none => RematchState.none,
        RematchStatus.waitingForOpponent => RematchState.iAsked,
        RematchStatus.opponentAsked => RematchState.opponentAsked,
      },
    );
  }

  Widget _incidentScreen() {
    final c = _controller;
    final String peer = c.incidentPeerName ?? '';
    final DuelIncident incident;
    VoidCallback primary = c.dismissIncident;
    VoidCallback? secondary;
    switch (c.incident) {
      case MultiplayerIncident.opponentLeft:
        incident = DuelIncident.opponentDisconnected(peer);
        primary = c.backToLobby;
      case MultiplayerIncident.hostLeft:
        incident = c.incidentReason == DisconnectReason.left
            ? DuelIncident.hostLeft(peer)
            : DuelIncident.connectionLost(peer);
        primary = c.leave;
      case MultiplayerIncident.joinFailed:
        switch (c.joinFailure) {
          case JoinFailure.full:
            incident = DuelIncident.gameFull(
                hostNameOf(c.joiningGame?.name ?? c.gameName ?? ''));
            primary = c.backToBrowsing;
          case JoinFailure.versionMismatch:
            incident = _versionMismatch;
            primary = c.backToBrowsing;
          case JoinFailure.unreachable || JoinFailure.refused || null:
            incident = const DuelIncident.connectionFailed();
            primary = c.retry;
            secondary = c.backToBrowsing;
        }
      case MultiplayerIncident.networkUnavailable:
        incident = const DuelIncident.noNetwork();
        primary = c.retry;
        secondary = c.leave;
      case MultiplayerIncident.closedInBackground:
        incident = _closedInBackground;
        primary = c.leave;
      case null:
        return const _Blank();
    }
    return _IncidentLayer(
      incident: incident,
      onAction: (action) => action == DuelIncidentAction.secondary
          ? secondary?.call()
          : primary(),
    );
  }

  /// L'hôte a une autre version de l'app.
  static const DuelIncident _versionMismatch = DuelIncident(
    icon: Icons.system_update_rounded,
    iconColor: PongColors.textBody,
    title: 'Versions différentes',
    message: "Installe la même version du jeu sur les deux téléphones, puis "
        "réessaie.",
    primaryLabel: 'Retour à la liste',
  );

  /// L'app est passée en arrière-plan : pas de pause en duel.
  static const DuelIncident _closedInBackground = DuelIncident(
    icon: Icons.pause_circle_outline_rounded,
    iconColor: PongColors.textBody,
    title: 'Partie fermée',
    message: "La partie s'arrête quand le jeu passe en arrière-plan. Tu peux "
        "en créer ou en rejoindre une autre.",
    primaryLabel: 'Retour au menu',
  );
}

/// Pseudo de l'hôte d'après le nom annoncé (« Partie de Tom » → « Tom »,
/// « Partie d'Inès » → « Inès »). Un nom d'une autre forme est gardé tel
/// quel.
String hostNameOf(String gameName) {
  const prefixes = ['Partie de ', "Partie d'", 'Partie d’'];
  for (final prefix in prefixes) {
    if (gameName.startsWith(prefix) && gameName.length > prefix.length) {
      return gameName.substring(prefix.length);
    }
  }
  return gameName;
}

/// Incident en plein écran (X1, X2, X3…), ou par-dessus le duel avec
/// [scrim] pour la confirmation de sortie.
class _IncidentLayer extends StatelessWidget {
  const _IncidentLayer({
    required this.incident,
    required this.onAction,
    this.scrim = false,
  });

  final DuelIncident incident;
  final ValueChanged<DuelIncidentAction> onAction;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scrim ? PongColors.scrim : PongColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: PongSpacing.screen, vertical: PongSpacing.lg),
            child: DuelIncidentCard(incident: incident, onAction: onAction),
          ),
        ),
      ),
    );
  }
}

/// Fond seul, pour une étape sans données (ne devrait pas durer).
class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: PongColors.background, child: SizedBox.expand());
}
