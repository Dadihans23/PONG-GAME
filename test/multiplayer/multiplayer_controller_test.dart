// Deux contrôleurs (hôte et invité) reliés par le transport et la découverte
// en mémoire : duel complet, revanche, incidents, arrière-plan.
//
// Le temps du jeu (compte à rebours, envoi à 30 Hz, interpolation,
// indicateur réseau) suit une horloge simulée que le test avance lui-même :
// aucune fenêtre de temps serrée. Seuls le battement de cœur (coupure
// silencieuse) et le délai de recherche utilisent le vrai temps, avec des
// marges larges ; les attentes se font par `until`, qui scrute une condition
// jusqu'à 10 s.
import 'dart:async';
import 'dart:math';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/game_tuning.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';
import 'package:pong_game/multiplayer/controller/controller.dart';
import 'package:pong_game/net/net.dart';

class FakeClock {
  Duration now = Duration.zero;

  Duration call() => now;

  void advance(Duration d) => now += d;
}

/// Attend que [condition] soit vraie (vrai temps, 10 s au plus).
Future<void> until(bool Function() condition, {String? reason}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      fail('condition jamais remplie${reason == null ? '' : ' : $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// Laisse passer les messages en mémoire (micro-tâches et événements).
Future<void> flush() async {
  for (int i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class Side {
  Side(this.controller) {
    controller.events.listen(events.add);
  }

  final MultiplayerController controller;
  final List<MultiplayerEvent> events = [];

  int count<T extends MultiplayerEvent>([bool Function(T)? test]) =>
      events.whereType<T>().where((e) => test == null || test(e)).length;
}

const frame = Duration(milliseconds: 100);

void main() {
  late MemoryTransport transport;
  late MemoryDiscovery discovery;
  late FakeClock clock;
  final created = <MultiplayerController>[];
  final logs = <String>[];

  MultiplayerController newController(
    String name, {
    DuelStatsStore? stats,
    HeartbeatConfig heartbeat = const HeartbeatConfig(),
    int seed = 1,
    int sensitivity = PaddleSensitivity.defaultValue,
    MultiplayerNetwork? network,
  }) {
    final controller = MultiplayerController(
      playerName: name,
      paddleSensitivity: sensitivity,
      network: network ??
          MultiplayerNetwork.memory(transport: transport, discovery: discovery, heartbeat: heartbeat, log: logs.add),
      stats: stats ?? MemoryDuelStats(),
      random: Random(seed),
      clock: clock.call,
      searchTimeout: const Duration(milliseconds: 300),
    );
    created.add(controller);
    return controller;
  }

  setUp(() {
    transport = MemoryTransport();
    discovery = MemoryDiscovery();
    clock = FakeClock();
    logs.clear();
  });

  tearDown(() async {
    for (final controller in created) {
      controller.dispose();
    }
    created.clear();
    await flush();
  });

  /// Hôte qui ouvre sa partie, invité qui la trouve et la rejoint.
  Future<(Side, Side)> joined({
    String hostName = 'Léa',
    String guestName = 'Tom',
    DuelStatsStore? hostStats,
    DuelStatsStore? guestStats,
    HeartbeatConfig heartbeat = const HeartbeatConfig(),
    int hostSensitivity = PaddleSensitivity.defaultValue,
    int guestSensitivity = PaddleSensitivity.defaultValue,
  }) async {
    final host = Side(newController(hostName,
        stats: hostStats, heartbeat: heartbeat, seed: 11, sensitivity: hostSensitivity));
    final guest = Side(newController(guestName,
        stats: guestStats, heartbeat: heartbeat, seed: 22, sensitivity: guestSensitivity));
    await host.controller.createGame();
    await guest.controller.startBrowsing();
    await until(() => guest.controller.games.isNotEmpty, reason: 'partie trouvée');
    await guest.controller.joinGame(guest.controller.games.first);
    await until(() => host.controller.opponent != null, reason: 'invité arrivé chez l\'hôte');
    return (host, guest);
  }

  /// Les deux joueurs appuient sur Prêt, puis le compte à rebours s'écoule.
  Future<void> readyAndCountdown(Side host, Side guest) async {
    guest.controller.setReady(true);
    await until(() => host.controller.opponentReady, reason: 'invité prêt');
    host.controller.setReady(true);
    await until(() => guest.controller.stage == MultiplayerStage.countdown, reason: 'compte à rebours invité');
    for (int i = 0; i < 3; i++) {
      clock.advance(const Duration(seconds: 1));
      host.controller.onFrame(Duration.zero, 0);
      guest.controller.onFrame(Duration.zero, 0);
    }
    await until(() =>
        host.controller.stage == MultiplayerStage.playing && guest.controller.stage == MultiplayerStage.playing);
    await flush(); // premier état de l'hôte reçu par l'invité
  }

  /// Joue des images jusqu'à la fin du duel. L'hôte suit la balle avec un
  /// décalage (renvois en biais), l'invité colle sa raquette à un bord : il
  /// perd presque tous les points, sans que le test en dépende.
  Future<void> playToEnd(Side host, Side guest, {void Function()? onFrame}) async {
    for (int i = 0; i < 20000; i++) {
      if (host.controller.stage == MultiplayerStage.finished && guest.controller.stage == MultiplayerStage.finished) {
        return;
      }
      clock.advance(frame);
      final view = host.controller.view;
      double hostSpeed = 0;
      if (view != null) {
        hostSpeed = ((view.ballX + 0.2 - view.myPaddleX) * 50).clamp(-2.0, 2.0);
      }
      host.controller.onFrame(frame, hostSpeed);
      guest.controller.onFrame(frame, 5.0);
      onFrame?.call();
      await flush();
    }
    fail('le duel ne se termine pas');
  }

  group('Recherche et connexion', () {
    test('liste : rien, puis la partie de Léa, pleine une fois rejointe', () async {
      final guest = newController('Tom');
      await guest.startBrowsing();
      expect(guest.stage, MultiplayerStage.browsing);
      expect(guest.role, MultiplayerRole.guest);
      expect(guest.browseStatus, BrowseStatus.searching);
      await until(() => guest.browseStatus == BrowseStatus.empty, reason: 'J3 après le délai');

      final host = newController('Léa');
      await host.createGame();
      expect(host.stage, MultiplayerStage.lobby);
      expect(host.gameName, 'Partie de Léa');
      expect(host.phase, DuelPhase.waiting);
      expect(host.canSetReady, isFalse);
      await until(() => guest.browseStatus == BrowseStatus.found);
      expect(guest.games.single.name, 'Partie de Léa');
      expect(guest.games.single.isFull, isFalse);

      // Un troisième téléphone voit la partie pleine une fois Tom entré
      final watcher = newController('Inès');
      await watcher.startBrowsing();
      await guest.joinGame(guest.games.single);
      expect(guest.stage, MultiplayerStage.lobby);
      await until(() => watcher.games.isNotEmpty && watcher.games.single.isFull, reason: 'partie grisée');
      expect(watcher.games.single.isJoinable, isFalse);
    });

    test('Actualiser vide la liste puis la retrouve', () async {
      final host = newController('Léa');
      await host.createGame();
      final guest = newController('Tom');
      await guest.startBrowsing();
      await until(() => guest.games.isNotEmpty);
      guest.refreshGames();
      expect(guest.games, isEmpty);
      expect(guest.browseStatus, BrowseStatus.searching);
      await until(() => guest.browseStatus == BrowseStatus.found);
    });

    test('noms de partie et pseudos nettoyés', () {
      expect(MultiplayerController.gameNameFor('Tom'), 'Partie de Tom');
      expect(MultiplayerController.gameNameFor('Inès'), "Partie d'Inès");
      expect(MultiplayerController.gameNameFor('Éva'), "Partie d'Éva");
      expect(MultiplayerController.cleanPlayerName('   '), 'Joueur');
      expect(MultiplayerController.cleanPlayerName(' Tom '), 'Tom');
      expect(MultiplayerController.cleanPlayerName('a' * 30).length, 20);
    });

    test('partie pleine : refus « full » pour le troisième joueur', () async {
      final (host, _) = await joined();
      final third = newController('Inès');
      await third.startBrowsing();
      await until(() => third.games.isNotEmpty);
      await third.joinGame(third.games.single);
      expect(third.stage, MultiplayerStage.incident);
      expect(third.incident, MultiplayerIncident.joinFailed);
      expect(third.joinFailure, JoinFailure.full);
      // Rien ne change pour les deux autres
      expect(host.controller.opponent?.name, 'Tom');

      await third.backToBrowsing();
      expect(third.stage, MultiplayerStage.browsing);
      expect(third.incident, isNull);
    });

    test('hôte injoignable : X3, Réessayer, Retour', () async {
      final guest = newController('Tom');
      await guest.startBrowsing();
      const ghost = DiscoveredGame(
          id: 'x', name: 'Partie de Fantôme', address: 'memory', port: 1, players: 1, maxPlayers: 2, version: 1);
      await guest.joinGame(ghost);
      expect(guest.incident, MultiplayerIncident.joinFailed);
      expect(guest.joinFailure, JoinFailure.unreachable);
      expect(guest.joiningGame, ghost);

      await guest.retry();
      expect(guest.incident, MultiplayerIncident.joinFailed);

      await guest.dismissIncident();
      expect(guest.stage, MultiplayerStage.browsing);
    });

    test('réseau indisponible pour chercher : X3, puis retour au menu', () async {
      final guest = newController('Tom',
          network: MultiplayerNetwork(transport: transport, finderFactory: _BrokenFinder.new, log: logs.add));
      await guest.startBrowsing();
      expect(guest.stage, MultiplayerStage.incident);
      expect(guest.incident, MultiplayerIncident.networkUnavailable);
      await guest.dismissIncident();
      expect(guest.stage, MultiplayerStage.idle);
      expect(guest.role, isNull);
    });
  });

  group('Duel complet', () {
    test('arrivée, Prêt, 3-2-1, duel à 5, revanche, nouvelle partie', () async {
      final hostStats = MemoryDuelStats();
      final guestStats = MemoryDuelStats();
      final (host, guest) = await joined(hostStats: hostStats, guestStats: guestStats);
      final h = host.controller;
      final g = guest.controller;

      // Salon : L2 côté hôte, L3 côté invité
      expect(host.events.whereType<OpponentJoined>().single.name, 'Tom');
      expect(h.isHost, isTrue);
      expect(h.mySlot, PlayerSlot.player1);
      expect(g.mySlot, PlayerSlot.player2);
      expect(g.gameName, 'Partie de Léa');
      expect(h.me?.name, 'Léa');
      expect(h.opponent?.name, 'Tom');
      expect(g.me?.name, 'Tom');
      expect(g.opponent?.name, 'Léa');
      expect(h.canSetReady, isTrue);
      expect(g.canSetReady, isTrue);

      // Prêt, plus prêt, prêt
      g.setReady(true);
      await until(() => h.opponentReady);
      expect(g.amReady, isTrue);
      g.toggleReady();
      await until(() => !h.opponentReady);
      g.setReady(true);
      await until(() => h.opponentReady);
      expect(h.stage, MultiplayerStage.lobby);

      // L'hôte est prêt : compte à rebours synchronisé
      h.setReady(true);
      expect(h.stage, MultiplayerStage.countdown);
      expect(h.countdownValue, 3);
      await until(() => g.stage == MultiplayerStage.countdown);
      expect(g.countdownValue, 3);
      expect(g.opponentReady, isTrue);
      for (final expected in [2, 1]) {
        clock.advance(const Duration(seconds: 1));
        h.onFrame(Duration.zero, 0);
        g.onFrame(Duration.zero, 0);
        expect(h.countdownValue, expected);
        expect(g.countdownValue, expected);
      }
      clock.advance(const Duration(seconds: 1));
      h.onFrame(Duration.zero, 0);
      g.onFrame(Duration.zero, 0);
      expect(h.stage, MultiplayerStage.playing);
      expect(g.stage, MultiplayerStage.playing);
      await flush();
      for (final side in [host, guest]) {
        expect(side.events.whereType<CountdownTick>().map((e) => e.value), [3, 2, 1]);
        expect(side.count<DuelStarted>(), 1);
      }
      expect(h.connectionQuality, ConnectionQuality.good);

      // Duel
      final pointInfos = <(PointInfo, PointInfo?)>[];
      await playToEnd(host, guest, onFrame: () {
        final info = h.pointInfo;
        if (info != null) pointInfos.add((info, g.pointInfo));
        expect(h.connectionQuality, ConnectionQuality.good);
      });

      final hr = h.result!;
      final gr = g.result!;
      expect(hr.won, isNot(gr.won));
      expect(hr.myScore, gr.opponentScore);
      expect(hr.opponentScore, gr.myScore);
      expect(max(hr.myScore, hr.opponentScore), 5);
      expect(hr.winnerName, gr.winnerName);
      expect(hr.winnerName, hr.won ? 'Léa' : 'Tom');
      expect(hr.duration, gr.duration);
      expect(hr.duration, greaterThan(Duration.zero));
      expect(hr.longestRally, gr.longestRally);
      expect(h.myScore, hr.myScore);
      expect(g.myScore, gr.myScore);

      // Mêmes événements des deux côtés, vus de chaque joueur
      final totalPoints = hr.myScore + hr.opponentScore;
      expect(host.count<PointScored>(), totalPoints);
      expect(guest.count<PointScored>(), totalPoints);
      expect(host.count<PointScored>((e) => e.mine), hr.myScore);
      expect(guest.count<PointScored>((e) => e.mine), gr.myScore);
      expect(guest.count<PaddleHit>(), host.count<PaddleHit>());
      expect(guest.count<PaddleHit>((e) => e.mine), host.count<PaddleHit>((e) => !e.mine));
      expect(host.count<PaddleHit>(), greaterThan(0));
      expect(host.events.whereType<DuelEnded>().single.won, hr.won);
      expect(guest.events.whereType<DuelEnded>().single.won, gr.won);

      // Pause après un point (D2) : même lecture des deux côtés, en miroir
      expect(pointInfos, isNotEmpty);
      expect(pointInfos.where((p) => p.$2 != null), isNotEmpty, reason: "D2 vu aussi par l'invité");
      for (final (hi, gi) in pointInfos) {
        expect(hi.resumeIn, inInclusiveRange(1, 2));
        expect(hi.exitEdge, hi.scoredByMe ? ScreenEdge.top : ScreenEdge.bottom);
        expect(hi.scorerName, hi.scoredByMe ? 'Léa' : 'Tom');
        if (gi != null) {
          expect(gi.scoredByMe, !hi.scoredByMe);
          expect(gi.scorerName, hi.scorerName);
          expect(gi.exitEdge, gi.scoredByMe ? ScreenEdge.top : ScreenEdge.bottom);
        }
      }

      // Statistiques
      expect(hostStats.wins + hostStats.losses, 1);
      expect(guestStats.wins + guestStats.losses, 1);
      expect(hostStats.wins, guestStats.losses);
      expect(h.duelWins, hostStats.wins);

      // Revanche demandée par l'invité, puis acceptée par l'hôte
      expect(h.rematchStatus, RematchStatus.none);
      g.requestRematch();
      expect(g.rematchStatus, RematchStatus.waitingForOpponent);
      await until(() => h.rematchStatus == RematchStatus.opponentAsked);
      expect(host.events.whereType<RematchRequested>().single.name, 'Tom');
      expect(h.stage, MultiplayerStage.finished);
      h.requestRematch();
      expect(h.stage, MultiplayerStage.countdown);
      await until(() => g.stage == MultiplayerStage.countdown);
      expect(g.result, isNull);
      expect(g.rematchStatus, RematchStatus.none);
      for (int i = 0; i < 3; i++) {
        clock.advance(const Duration(seconds: 1));
        h.onFrame(Duration.zero, 0);
        g.onFrame(Duration.zero, 0);
      }
      expect(h.stage, MultiplayerStage.playing);
      expect(g.stage, MultiplayerStage.playing);
      expect(h.myScore + h.opponentScore, 0);

      await playToEnd(host, guest);
      expect(hostStats.wins + hostStats.losses, 2);
      expect(guestStats.wins + guestStats.losses, 2);
      expect(hostStats.wins, guestStats.losses);
      expect(hostStats.losses, guestStats.wins);
      expect(host.count<DuelEnded>(), 2);

      // Quitter depuis l'écran de fin
      await g.leave();
      expect(g.stage, MultiplayerStage.idle);
      await until(() => h.stage == MultiplayerStage.incident);
      expect(h.incident, MultiplayerIncident.opponentLeft);
      expect(h.incidentPeerName, 'Tom');
      expect(h.incidentReason, DisconnectReason.left);
    });

    test('positions : raquette de l\'invité locale, vues en miroir, conversion vers le terrain', () async {
      final (host, guest) = await joined();
      await readyAndCountdown(host, guest);
      final h = host.controller;
      final g = guest.controller;

      // L'invité incline à droite : sa raquette bouge aussitôt à l'écran,
      // bornée à la vitesse maximale de sa sensibilité (2,1 unités/s à 50)
      final double vmax = PaddleSensitivity.maxSpeed(PaddleSensitivity.defaultValue);
      expect(g.myPaddleMaxSpeed, vmax);
      g.onFrame(frame, 1.0);
      expect(g.view!.myPaddleX, closeTo(0.1, 1e-9));
      g.onFrame(frame, 100.0);
      final double afterMax = 0.1 + vmax * 0.1;
      expect(g.view!.myPaddleX, closeTo(afterMax, 1e-9));
      g.onFrame(frame, double.nan);
      expect(g.view!.myPaddleX, closeTo(afterMax, 1e-9));
      // Image très longue : plafonnée comme en solo (50 pas = 0,111 s)
      g.onFrame(const Duration(seconds: 5), -vmax);
      expect(g.view!.myPaddleX, closeTo(afterMax - vmax * 50 / 450, 1e-9));
      final guestScreenX = g.view!.myPaddleX;

      // L'hôte joue : il reçoit la position (inversée sur le terrain) et sa
      // raquette la rejoint
      for (int i = 0; i < 5; i++) {
        clock.advance(frame);
        g.onFrame(Duration.zero, 0);
        await flush();
        h.onFrame(frame, 0);
        await flush();
      }
      expect(h.view!.opponentPaddleX, closeTo(-guestScreenX, 1e-9));

      // L'hôte bouge à droite ; l'invité, qui le voit en face, le voit à gauche
      for (int i = 0; i < 3; i++) {
        clock.advance(frame);
        h.onFrame(frame, 1.0);
        await flush();
      }
      clock.advance(const Duration(seconds: 1)); // fin de l'interpolation
      g.onFrame(Duration.zero, 0);
      final hv = h.view!;
      final gv = g.view!;
      expect(hv.myPaddleX, greaterThan(0.2));
      expect(gv.opponentPaddleX, closeTo(-hv.myPaddleX, 1e-9));
      expect(gv.ballX, closeTo(-hv.ballX, 1e-9));
      expect(gv.ballY, closeTo(-hv.ballY, 1e-9));
      expect(g.ballVisible, isTrue);
    });
  });

  group('Sensibilité de la raquette', () {
    test("l'invité annonce sa sensibilité : l'hôte la reçoit", () async {
      final (host, guest) = await joined(hostSensitivity: 20, guestSensitivity: 85);
      expect(host.controller.opponentPaddleSensitivity, 85);
      expect(guest.controller.opponentPaddleSensitivity, isNull);
      expect(host.controller.paddleSensitivity, 20);
      expect(guest.controller.paddleSensitivity, 85);
    });

    test('chacun sa vitesse, comme au tennis, sous le plafond commun', () async {
      final (host, guest) = await joined(hostSensitivity: 0, guestSensitivity: 100);
      await readyAndCountdown(host, guest);
      final h = host.controller;
      final g = guest.controller;
      final double hostMax = PaddleSensitivity.maxSpeed(0);
      final double guestMax = PaddleSensitivity.maxSpeed(100);
      expect(h.myPaddleMaxSpeed, hostMax);
      expect(g.myPaddleMaxSpeed, guestMax);
      expect(guestMax, GameTuning.paddleSpeedCap);

      // Hôte : demande 10 unités/s, n'avance qu'à sa propre vitesse
      final double before = h.view!.myPaddleX;
      h.onFrame(frame, 10.0);
      // 45 pas de moteur en 100 ms
      expect(h.view!.myPaddleX - before, closeTo(hostMax * 45 / 450, 1e-9));

      // Invité : sa raquette locale va à sa vitesse, plus vite que l'hôte
      g.onFrame(frame, 10.0);
      g.onFrame(frame, 10.0);
      expect(g.view!.myPaddleX, closeTo(guestMax * 0.2, 1e-9));

      // L'hôte fait rejoindre la position reçue à la vitesse de l'invité :
      // ni plus vite, ni bridé à la vitesse de l'hôte
      clock.advance(frame);
      g.onFrame(Duration.zero, 0); // envoi de la position
      await flush();
      final double start = h.view!.opponentPaddleX;
      h.onFrame(frame, 0);
      final double moved = (h.view!.opponentPaddleX - start).abs();
      expect(moved, closeTo(guestMax * 45 / 450, 1e-9));
      expect(moved, greaterThan(hostMax * 45 / 450));
    });

    test('invité sans sensibilité annoncée (app plus ancienne) : valeur par défaut', () async {
      final host = newController('Léa', sensitivity: 30);
      await host.createGame();
      final finder = newController('Tom');
      await finder.startBrowsing();
      await until(() => finder.games.isNotEmpty, reason: 'partie trouvée');
      final game = finder.games.first;
      // Client brut, comme une version qui n'annonce pas le champ
      final old = ClientSession(playerName: 'Ancien', transport: transport, log: logs.add);
      addTearDown(old.close);
      final result = await old.connect(game.address, game.port);
      expect(result, isA<JoinAccepted>());
      await until(() => host.opponent != null, reason: 'ancien client arrivé');
      expect(host.opponentPaddleSensitivity, PaddleSensitivity.defaultValue);
    });
  });

  group('Incidents', () {
    test('l\'invité quitte le salon : l\'hôte revient en attente, sans écran X1', () async {
      final (host, guest) = await joined();
      guest.controller.setReady(true);
      await until(() => host.controller.opponentReady);
      await guest.controller.leave();
      expect(guest.controller.stage, MultiplayerStage.idle);
      await until(() => host.controller.opponent == null);
      expect(host.controller.stage, MultiplayerStage.lobby);
      expect(host.controller.phase, DuelPhase.waiting);
      expect(host.controller.incident, isNull);
      expect(host.events.whereType<OpponentLeft>().single.name, 'Tom');
      expect(discovery.advertisers.single.players, 1);
    });

    test('l\'invité quitte en plein duel : X1, retour au salon, un autre peut rejoindre', () async {
      final (host, guest) = await joined();
      await readyAndCountdown(host, guest);
      expect(discovery.advertisers.single.players, 2);
      await guest.controller.leave();
      await until(() => host.controller.stage == MultiplayerStage.incident);
      expect(host.controller.incident, MultiplayerIncident.opponentLeft);
      expect(host.controller.incidentPeerName, 'Tom');
      expect(host.controller.incidentReason, DisconnectReason.left);
      expect(host.controller.result, isNull);
      expect(discovery.advertisers.single.players, 1);

      host.controller.backToLobby();
      expect(host.controller.stage, MultiplayerStage.lobby);
      expect(host.controller.phase, DuelPhase.waiting);

      final other = newController('Inès');
      await other.startBrowsing();
      await until(() => other.games.isNotEmpty);
      await other.joinGame(other.games.single);
      await until(() => host.controller.opponent?.name == 'Inès');
      expect(other.stage, MultiplayerStage.lobby);
    });

    test('un duel abandonné ne compte pas dans les statistiques', () async {
      final hostStats = MemoryDuelStats();
      final guestStats = MemoryDuelStats();
      final (host, guest) = await joined(hostStats: hostStats, guestStats: guestStats);
      await readyAndCountdown(host, guest);
      await guest.controller.leave();
      await until(() => host.controller.stage == MultiplayerStage.incident);
      expect(hostStats.wins + hostStats.losses, 0);
      expect(guestStats.wins + guestStats.losses, 0);
    });

    test('l\'hôte quitte le salon : X2 chez l\'invité, puis retour au menu', () async {
      final (host, guest) = await joined();
      await host.controller.leave();
      expect(host.controller.stage, MultiplayerStage.idle);
      expect(discovery.advertisers, isEmpty);
      await until(() => guest.controller.stage == MultiplayerStage.incident);
      expect(guest.controller.incident, MultiplayerIncident.hostLeft);
      expect(guest.controller.incidentPeerName, 'Léa');
      expect(guest.controller.incidentReason, DisconnectReason.left);
      await guest.controller.dismissIncident();
      expect(guest.controller.stage, MultiplayerStage.idle);
    });

    test('l\'hôte quitte en plein duel : X2', () async {
      final (host, guest) = await joined();
      await readyAndCountdown(host, guest);
      await host.controller.leave();
      await until(() => guest.controller.stage == MultiplayerStage.incident);
      expect(guest.controller.incident, MultiplayerIncident.hostLeft);
      expect(guest.events.whereType<OpponentLeft>().single.name, 'Léa');
    });

    test('coupure silencieuse : indicateur rouge après 1 s, puis déconnexion des deux côtés', () async {
      const heartbeat = HeartbeatConfig(
        pingInterval: Duration(milliseconds: 50),
        timeout: Duration(milliseconds: 800),
        checkInterval: Duration(milliseconds: 20),
      );
      final (host, guest) = await joined(heartbeat: heartbeat);
      await readyAndCountdown(host, guest);
      final h = host.controller;
      final g = guest.controller;

      // Échanges normaux : tout est vert
      for (int i = 0; i < 5; i++) {
        clock.advance(frame);
        h.onFrame(frame, 0);
        g.onFrame(frame, 0);
        await flush();
      }
      expect(h.connectionQuality, ConnectionQuality.good);
      expect(g.connectionQuality, ConnectionQuality.good);

      transport.clientEnds.last.cutSilently();
      for (int i = 0; i < 12; i++) {
        clock.advance(frame);
        h.onFrame(frame, 0);
        g.onFrame(frame, 0);
        await flush();
        if (h.stage != MultiplayerStage.playing || g.stage != MultiplayerStage.playing) break;
      }
      // Plus d'une seconde (simulée) sans message
      if (h.stage == MultiplayerStage.playing) expect(h.connectionQuality, ConnectionQuality.degraded);
      if (g.stage == MultiplayerStage.playing) expect(g.connectionQuality, ConnectionQuality.degraded);

      // Le battement de cœur finit par déclarer la connexion perdue
      await until(() => h.stage == MultiplayerStage.incident && g.stage == MultiplayerStage.incident);
      expect(h.incident, MultiplayerIncident.opponentLeft);
      expect(h.incidentReason, DisconnectReason.timeout);
      expect(g.incident, MultiplayerIncident.hostLeft);
      expect(g.incidentReason, DisconnectReason.timeout);
    });

    test('message invalide de l\'hôte : ignoré, sans plantage', () async {
      final (host, guest) = await joined();
      await readyAndCountdown(host, guest);
      final hostEnd = transport.hostEnds.last;
      hostEnd.send('{"v":1,"type":"game_state","seq":999999,"state":{"tick":1}}');
      hostEnd.send('{"v":1,"type":"game_over","winner":"host","state":{"score":"5-0"}}');
      await flush();
      // L'état final illisible est ignoré, le gagnant est quand même appliqué
      expect(guest.controller.stage, MultiplayerStage.finished);
      expect(guest.controller.result!.won, isFalse);
      expect(logs.where((l) => l.contains('invalide')), isNotEmpty);
    });
  });

  group('Arrière-plan', () {
    test('en duel : la partie est fermée, l\'autre voit le départ', () async {
      final (host, guest) = await joined();
      await readyAndCountdown(host, guest);
      host.controller.handleAppLifecycleState(AppLifecycleState.inactive);
      expect(host.controller.stage, MultiplayerStage.playing);
      host.controller.handleAppLifecycleState(AppLifecycleState.paused);
      expect(host.controller.stage, MultiplayerStage.incident);
      expect(host.controller.incident, MultiplayerIncident.closedInBackground);
      await until(() => guest.controller.stage == MultiplayerStage.incident);
      expect(guest.controller.incident, MultiplayerIncident.hostLeft);
      expect(discovery.advertisers, isEmpty);
      await host.controller.dismissIncident();
      expect(host.controller.stage, MultiplayerStage.idle);
    });

    test('invité en arrière-plan : l\'hôte voit X1', () async {
      final (host, guest) = await joined();
      await readyAndCountdown(host, guest);
      guest.controller.onAppPaused();
      expect(guest.controller.incident, MultiplayerIncident.closedInBackground);
      await until(() => host.controller.stage == MultiplayerStage.incident);
      expect(host.controller.incident, MultiplayerIncident.opponentLeft);
    });

    test('pendant la recherche : suspendue puis reprise', () async {
      final host = newController('Léa');
      await host.createGame();
      final guest = newController('Tom');
      await guest.startBrowsing();
      await until(() => guest.games.isNotEmpty);
      guest.onAppPaused();
      expect(guest.stage, MultiplayerStage.browsing);
      guest.onAppResumed();
      await until(() => guest.games.isNotEmpty && guest.browseStatus == BrowseStatus.found);
    });
  });

  test('dispose ferme tout et prévient l\'autre téléphone', () async {
    final (host, guest) = await joined();
    host.controller.dispose();
    await until(() => guest.controller.stage == MultiplayerStage.incident);
    expect(discovery.advertisers, isEmpty);
    // Appels après dispose : sans effet, sans exception
    host.controller.onFrame(frame, 1);
    host.controller.setReady(true);
    await host.controller.leave();
  });
}

class _BrokenFinder implements GameFinder {
  @override
  Stream<List<DiscoveredGame>> get games => const Stream.empty();

  @override
  List<DiscoveredGame> get current => const [];

  @override
  Future<void> start() async => throw StateError('Wi-Fi coupé');

  @override
  void refresh() {}

  @override
  Future<void> stop() async {}
}
