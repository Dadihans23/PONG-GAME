// Parcours multijoueur complet, écran par écran : deux `MultiplayerFlow`
// (hôte et invité) côte à côte, reliés par le transport et la découverte en
// mémoire. Le temps est celui du test (`tester.pump`) : le contrôleur lit
// l'horloge simulée du test, le Ticker du duel avance avec elle, et le
// battement de cœur a un délai très long. Aucune fenêtre de temps serrée :
// chaque attente est « pomper jusqu'à ce que », avec une limite large.
//
// Sons et accéléromètre n'ont pas de plugin natif en test (erreurs ignorées
// par le jeu) : les raquettes restent au centre et la balle, servie en
// diagonale, marque à chaque service. Le duel se joue donc jusqu'à 5 seul.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/multiplayer/controller/controller.dart';
import 'package:pong_game/multiplayer/multiplayer_flow.dart';
import 'package:pong_game/multiplayer/screens/duel_result_screen.dart';
import 'package:pong_game/multiplayer/screens/duel_screen.dart';
import 'package:pong_game/multiplayer/screens/join_screen.dart';
import 'package:pong_game/multiplayer/screens/lobby_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_menu_screen.dart';
import 'package:pong_game/multiplayer/widgets/duel_countdown.dart';
import 'package:pong_game/net/net.dart';
import 'package:pong_game/ui/pong_ui.dart';

const Key hostKey = ValueKey('hôte');
const Key guestKey = ValueKey('invité');

/// Battement de cœur sans délai réaliste : le test ne dépend pas du vrai
/// temps écoulé entre deux images.
const HeartbeatConfig patientHeartbeat = HeartbeatConfig(timeout: Duration(hours: 1));

/// Image du test : 50 ms de temps simulé.
const Duration frame = Duration(milliseconds: 50);

/// Pompe des images jusqu'à ce que [condition] soit vraie (300 s simulées
/// au plus).
///
/// À chaque image, les micro-tâches de la zone racine passent aussi : un
/// `await` sur un futur déjà terminé de la bibliothèque (`cancel()` d'un
/// abonnement à un flux diffusé, par exemple) reprend dans cette zone, que
/// le temps simulé du test ne fait pas avancer.
Future<void> pumpUntil(WidgetTester tester, bool Function() condition, {required String reason}) async {
  for (int i = 0; i < 6000; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (condition()) {
      // Une image de plus : l'écran affiche le nouvel état
      await tester.pump();
      return;
    }
    await tester.pump(frame);
  }
  fail('condition jamais remplie : $reason');
}

Finder on(Key side, Finder finder) => find.descendant(of: find.byKey(side), matching: finder);

/// Retour Android.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

/// Écran d'accueil minimal d'où l'on ouvre le multijoueur, comme `NamePage`.
Widget app(Key key, MultiplayerFlow Function() flow) => MaterialApp(
      key: key,
      theme: PongTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => flow())),
              child: const Text('Accueil'),
            ),
          ),
        ),
      ),
    );

/// Canaux de `sensors_plus` utilisés par l'accéléromètre.
const List<MethodChannel> sensorChannels = [
  MethodChannel('dev.fluttercommunity.plus/sensors/method'),
  MethodChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
];

class BrokenFinder implements GameFinder {
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

void main() {
  late Directory hiveDir;
  late MemoryTransport transport;
  late MemoryDiscovery discovery;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('pong_flow_test');
    Hive.init(hiveDir.path);
    await Hive.openBox('settings', bytes: Uint8List(0));
    await Hive.openBox('stats', bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() {
    transport = MemoryTransport();
    discovery = MemoryDiscovery();
    // Accéléromètre muet : le capteur répond mais n'envoie aucune mesure
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in sensorChannels) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in sensorChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  /// Contrôleur sur le réseau en mémoire, à l'horloge simulée du test.
  MultiplayerController controllerFor(
    WidgetTester tester,
    String name, {
    required int seed,
    MultiplayerNetwork? network,
    List<MultiplayerController>? created,
  }) {
    final controller = MultiplayerController(
      playerName: name,
      network: network ??
          MultiplayerNetwork.memory(transport: transport, discovery: discovery, heartbeat: patientHeartbeat),
      stats: MemoryDuelStats(),
      random: Random(seed),
      clock: () => Duration(microseconds: tester.binding.clock.now().microsecondsSinceEpoch),
      searchTimeout: const Duration(seconds: 2),
    );
    created?.add(controller);
    return controller;
  }

  /// Ferme les écrans (et donc les contrôleurs) et laisse finir les
  /// fermetures.
  Future<void> closeAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (int i = 0; i < 10; i++) {
      await tester.pump(frame);
    }
  }

  testWidgets('deux téléphones : créer, rejoindre, Prêt ×2, 3-2-1, duel, fin, revanche, quitter', (tester) async {
    tester.view.physicalSize = const Size(720, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late MultiplayerController h;
    late MultiplayerController g;
    final hostEvents = <MultiplayerEvent>[];
    final guestEvents = <MultiplayerEvent>[];
    await tester.pumpWidget(Row(textDirection: TextDirection.ltr, children: [
      SizedBox(
        width: 360,
        child: app(
            hostKey,
            () => MultiplayerFlow(
                  playerName: 'Léa',
                  createController: (name) => h = controllerFor(tester, name, seed: 11)..events.listen(hostEvents.add),
                )),
      ),
      SizedBox(
        width: 360,
        child: app(
            guestKey,
            () => MultiplayerFlow(
                  playerName: 'Tom',
                  createController: (name) => g = controllerFor(tester, name, seed: 22)..events.listen(guestEvents.add),
                )),
      ),
    ]));

    // Accueil → M1 des deux côtés
    await tester.tap(on(hostKey, find.text('Accueil')));
    await tester.tap(on(guestKey, find.text('Accueil')));
    await tester.pumpAndSettle();
    expect(on(hostKey, find.byType(MultiplayerMenuScreen)), findsOneWidget);
    expect(on(guestKey, find.byType(MultiplayerMenuScreen)), findsOneWidget);
    expect(on(hostKey, find.textContaining('Léa', findRichText: true)), findsOneWidget);

    // L'hôte crée : salon L1, place vide
    await tester.tap(on(hostKey, find.text('Créer une partie')));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.lobby, reason: 'salon de l\'hôte');
    await tester.pump();
    expect(on(hostKey, find.byType(LobbyScreen)), findsOneWidget);
    expect(on(hostKey, find.text('Partie de Léa')), findsOneWidget);
    expect(on(hostKey, find.text("En attente d'un joueur…")), findsOneWidget);

    // L'invité cherche, trouve la partie de Léa et la rejoint
    await tester.tap(on(guestKey, find.text('Rejoindre une partie')));
    await pumpUntil(tester, () => on(guestKey, find.text('Rejoindre')).evaluate().isNotEmpty,
        reason: 'partie de Léa listée');
    expect(on(guestKey, find.byType(JoinScreen)), findsOneWidget);
    await tester.tap(on(guestKey, find.text('Rejoindre')));
    await pumpUntil(tester, () => g.stage == MultiplayerStage.lobby && h.opponent != null,
        reason: 'invité dans le salon');
    await tester.pump();
    expect(on(guestKey, find.byType(LobbyScreen)), findsOneWidget);
    expect(on(hostKey, find.text('Tom')), findsOneWidget);
    expect(on(hostKey, find.text('Vient de rejoindre')), findsOneWidget);
    expect(on(guestKey, find.text('Léa')), findsOneWidget);
    expect(hostEvents.whereType<OpponentJoined>().single.name, 'Tom');

    // Prêt des deux côtés → compte à rebours plein écran, puis duel
    await tester.tap(on(guestKey, find.text('PRÊT')));
    await pumpUntil(tester, () => h.opponentReady, reason: 'invité prêt chez l\'hôte');
    expect(on(guestKey, find.text('Je ne suis plus prêt')), findsOneWidget);
    await tester.tap(on(hostKey, find.text('PRÊT')));
    await tester.pump();
    expect(h.stage, MultiplayerStage.countdown);
    expect(on(hostKey, find.byType(DuelCountdownOverlay)), findsOneWidget);
    await pumpUntil(tester, () => on(guestKey, find.byType(DuelCountdownOverlay)).evaluate().isNotEmpty,
        reason: 'compte à rebours chez l\'invité');
    await pumpUntil(tester, () => h.stage == MultiplayerStage.playing && g.stage == MultiplayerStage.playing,
        reason: 'duel lancé des deux côtés');
    await tester.pump();
    expect(on(hostKey, find.byType(DuelScreen)), findsOneWidget);
    expect(on(guestKey, find.byType(DuelScreen)), findsOneWidget);
    for (final events in [hostEvents, guestEvents]) {
      expect(events.whereType<CountdownTick>().map((e) => e.value), [3, 2, 1]);
      expect(events.whereType<DuelStarted>(), hasLength(1));
    }

    // Le duel se joue à 5, le Ticker de chaque écran fait avancer la partie
    await pumpUntil(tester, () => h.stage == MultiplayerStage.finished && g.stage == MultiplayerStage.finished,
        reason: 'fin du duel');
    await tester.pump();
    expect(on(hostKey, find.byType(DuelResultScreen)), findsOneWidget);
    expect(on(guestKey, find.byType(DuelResultScreen)), findsOneWidget);
    expect(h.result!.won, isNot(g.result!.won));
    expect(max(h.result!.myScore, h.result!.opponentScore), 5);
    expect(hostEvents.whereType<PointScored>().length, h.result!.myScore + h.result!.opponentScore);
    expect(guestEvents.whereType<PointScored>().length, hostEvents.whereType<PointScored>().length);
    expect(hostEvents.whereType<DuelEnded>().single.won, h.result!.won);

    // Revanche : l'invité demande, l'hôte accepte, nouveau 3-2-1
    await tester.tap(on(guestKey, find.text('REJOUER')));
    await pumpUntil(tester, () => on(hostKey, find.text('Tom veut rejouer')).evaluate().isNotEmpty,
        reason: 'demande de revanche reçue');
    expect(on(guestKey, find.text("Tu veux rejouer · Léa n'a pas encore répondu")), findsOneWidget);
    await tester.tap(on(hostKey, find.text('REJOUER')));
    await tester.pump();
    expect(on(hostKey, find.byType(DuelCountdownOverlay)), findsOneWidget);
    await pumpUntil(tester, () => h.stage == MultiplayerStage.playing && g.stage == MultiplayerStage.playing,
        reason: 'revanche lancée');
    await pumpUntil(tester, () => h.stage == MultiplayerStage.finished && g.stage == MultiplayerStage.finished,
        reason: 'fin de la revanche');
    await tester.pump();
    expect(hostEvents.whereType<DuelEnded>(), hasLength(2));

    // L'invité quitte depuis l'écran de fin : il revient au menu, l'hôte
    // voit X1 puis retourne au salon, toujours ouvert
    await tester.tap(on(guestKey, find.text('Quitter')));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.incident, reason: 'X1 chez l\'hôte');
    await tester.pump();
    expect(on(guestKey, find.byType(MultiplayerMenuScreen)), findsOneWidget);
    expect(on(hostKey, find.text('Connexion perdue avec Tom')), findsOneWidget);
    await tester.tap(on(hostKey, find.text('RETOUR AU SALON')));
    await tester.pump();
    expect(on(hostKey, find.byType(LobbyScreen)), findsOneWidget);
    expect(on(hostKey, find.text("En attente d'un joueur…")), findsOneWidget);

    // L'hôte annule : retour au menu, puis à l'accueil (contrôleur libéré)
    await tester.tap(on(hostKey, find.text('Annuler la partie')));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.idle, reason: 'partie annulée');
    expect(on(hostKey, find.byType(MultiplayerMenuScreen)), findsOneWidget);
    await tester.tap(on(hostKey, find.byTooltip('Retour')));
    await tester.pumpAndSettle();
    expect(on(hostKey, find.byType(MultiplayerFlow)), findsNothing);
    expect(on(hostKey, find.text('Accueil')), findsOneWidget);

    await closeAll(tester);
  });

  testWidgets('retour Android, confirmation en duel, arrière-plan et Wi-Fi absent (hôte seul à l\'écran)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late MultiplayerController h;
    final created = <MultiplayerController>[];
    await tester.pumpWidget(app(
        hostKey,
        () => MultiplayerFlow(
              playerName: 'Léa',
              createController: (name) => h = controllerFor(tester, name, seed: 11),
            )));
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    // Invité piloté directement, sans écran
    final g = controllerFor(tester, 'Tom', seed: 22, created: created);
    addTearDown(() => g.dispose());
    Future<void> guestJoins() async {
      await g.startBrowsing();
      await pumpUntil(tester, () => g.games.any((game) => game.isJoinable), reason: 'partie visible');
      await g.joinGame(g.games.firstWhere((game) => game.isJoinable));
      await pumpUntil(tester, () => h.opponent != null, reason: 'invité arrivé');
    }

    // Retour Android dans le salon : la partie est annulée, l'invité voit X2
    await tester.tap(find.text('Créer une partie'));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.lobby, reason: 'salon');
    await guestJoins();
    await pressBack(tester);
    await pumpUntil(tester, () => h.stage == MultiplayerStage.idle, reason: 'partie annulée');
    expect(find.byType(MultiplayerMenuScreen), findsOneWidget);
    await pumpUntil(tester, () => g.incident == MultiplayerIncident.hostLeft, reason: 'X2 chez l\'invité');
    await g.leave();

    // Retour Android en duel : confirmation ; « Continuer » (ou un second
    // retour) referme ; « Quitter » ferme la partie
    await tester.tap(find.text('Créer une partie'));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.lobby, reason: 'salon');
    await guestJoins();
    g.setReady(true);
    await pumpUntil(tester, () => h.opponentReady, reason: 'invité prêt');
    await tester.tap(find.text('PRÊT'));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.playing, reason: 'duel');
    await pressBack(tester);
    expect(find.text('Quitter le duel ?'), findsOneWidget);
    await pressBack(tester);
    expect(find.text('Quitter le duel ?'), findsNothing);
    expect(h.stage, MultiplayerStage.playing);
    await pressBack(tester);
    await tester.tap(find.text('CONTINUER LE DUEL'));
    await tester.pump();
    expect(find.text('Quitter le duel ?'), findsNothing);
    await pressBack(tester);
    await tester.tap(find.text('Quitter'));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.idle, reason: 'duel quitté');
    expect(find.byType(MultiplayerMenuScreen), findsOneWidget);
    await pumpUntil(tester, () => g.incident == MultiplayerIncident.hostLeft, reason: 'X2 après abandon');
    await g.leave();

    // Arrière-plan dans le salon : partie fermée, écran dédié au retour
    await tester.tap(find.text('Créer une partie'));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.lobby, reason: 'salon');
    await guestJoins();
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(h.incident, MultiplayerIncident.closedInBackground);
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(find.text('Partie fermée'), findsOneWidget);
    await pumpUntil(tester, () => g.incident == MultiplayerIncident.hostLeft, reason: 'X2 après arrière-plan');
    await tester.tap(find.text('RETOUR AU MENU'));
    await pumpUntil(tester, () => h.stage == MultiplayerStage.idle, reason: 'retour au menu');

    // Recherche : retour Android → menu ; retour au menu → accueil
    await tester.tap(find.text('Rejoindre une partie'));
    await tester.pump();
    expect(find.byType(JoinScreen), findsOneWidget);
    await pressBack(tester);
    await pumpUntil(tester, () => h.stage == MultiplayerStage.idle, reason: 'recherche arrêtée');
    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MultiplayerMenuScreen), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);

    await closeAll(tester);
  });

  testWidgets('Wi-Fi absent : X3 « Pas de Wi‑Fi », Réessayer puis Retour au menu', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late MultiplayerController c;
    await tester.pumpWidget(app(
        guestKey,
        () => MultiplayerFlow(
              playerName: 'Tom',
              createController: (name) => c = controllerFor(tester, name,
                  seed: 3, network: MultiplayerNetwork(transport: transport, finderFactory: BrokenFinder.new)),
            )));
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejoindre une partie'));
    await pumpUntil(tester, () => c.stage == MultiplayerStage.incident, reason: 'X3');
    await tester.pump();
    expect(find.text('Pas de Wi‑Fi'), findsOneWidget);
    await tester.tap(find.text('RÉESSAYER'));
    await pumpUntil(tester, () => c.stage == MultiplayerStage.incident, reason: 'X3 encore');
    await tester.pump();
    // Retour Android = action par défaut : retour au menu
    await pressBack(tester);
    await pumpUntil(tester, () => c.stage == MultiplayerStage.idle, reason: 'retour au menu');
    expect(find.byType(MultiplayerMenuScreen), findsOneWidget);

    await closeAll(tester);
  });
}
