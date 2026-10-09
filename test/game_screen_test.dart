// Écran de jeu solo (maquette G1, G2, G3, P1, E1, E2), à 320 et 360 dp de
// large. Hive écrit dans un dossier temporaire ; sons et accéléromètre n'ont
// pas de plugin natif en test (erreurs ignorées par le jeu).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/game/pong_engine.dart';
import 'package:pong_game/game_ui/game_court.dart';
import 'package:pong_game/game_ui/game_hud.dart';
import 'package:pong_game/game_ui/game_over_card.dart';
import 'package:pong_game/game_ui/pause_overlay.dart';
import 'package:pong_game/hompage.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Largeurs vérifiées : le SM-A135F (320 dp) et la maquette (360 dp).
const List<Size> _screens = [Size(320, 640), Size(360, 800)];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpGame(WidgetTester tester, Size size) async {
  _setSize(tester, size);
  await tester.pumpWidget(MaterialApp(
    theme: PongTheme.dark(),
    home: const Scaffold(body: Center(child: Text('Accueil'))),
  ));
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  navigator.push(MaterialPageRoute(
    builder: (context) => const MyHomePage(
        title: 'Tilto', playerName: 'Léa', difficulty: 'Normal'),
  ));
  await tester.pumpAndSettle();
}

// Le jeu seul, sans écran autour, pour vérifier un état précis du moteur
Future<void> _pumpCourt(WidgetTester tester, Size size, Widget child) async {
  _setSize(tester, size);
  await tester.pumpWidget(MaterialApp(
    theme: PongTheme.dark(),
    home: Scaffold(
      backgroundColor: PongColors.background,
      body: SafeArea(
        child: Column(children: [
          const GameHud(
            hasStarted: true,
            difficulty: 'Normal',
            speedLevel: 3,
            hitsSinceSpeedUp: 2,
            hitsPerSpeedUp: 4,
            onPause: null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(GameCourt.sideMargin, 0,
                  GameCourt.sideMargin, GameCourt.bottomMargin),
              child: child,
            ),
          ),
        ]),
      ),
    ),
  ));
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('pong_game_screen_test');
    Hive.init(hiveDir.path);
    // Boîtes en mémoire : les écritures faites par le jeu pendant un test
    // (horloge simulée) ne laissent aucune écriture de fichier en suspens
    await Hive.openBox<int>('scores', bytes: Uint8List(0));
    await Hive.openBox('leaderboard', bytes: Uint8List(0));
    await Hive.openBox('stats', bytes: Uint8List(0));
    await Hive.openBox('settings', bytes: Uint8List(0));
  });

  setUp(() async {
    await Hive.box<int>('scores').clear();
    await Hive.box('leaderboard').clear();
    await Hive.box('stats').clear();
    await Hive.box('settings').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  for (final size in _screens) {
    final String w = '${size.width.toInt()} dp';

    testWidgets('G1 avant le début, puis partie perdue sans bouger (E1), $w',
        (tester) async {
      await tester.runAsync(() => Hive.box<int>('scores').put('topscore', 2400));
      await _pumpGame(tester, size);

      // G1 : mode, consigne et record, pas de score ni de jauge
      expect(find.text('SOLO · NORMAL'), findsOneWidget);
      expect(find.text("TAPE L'ÉCRAN"), findsOneWidget);
      expect(find.text('Incline le téléphone pour bouger'), findsOneWidget);
      expect(find.text('RECORD 2 400'), findsOneWidget);
      expect(find.byType(PongDotGauge), findsNothing);

      // Tap : la partie démarre, la consigne disparaît, la jauge apparaît
      await tester.tapAt(const Offset(40, 300));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text("TAPE L'ÉCRAN"), findsNothing);
      expect(find.text('Incline le téléphone pour bouger'), findsNothing);
      expect(find.text('VITESSE 1'), findsOneWidget);
      expect(find.text('LÉA'), findsOneWidget);
      expect(find.text('RECORD 2 400'), findsOneWidget);

      // Sans accéléromètre la raquette ne bouge pas : la balle passe à côté
      for (int i = 0; i < 200 && find.text('PARTIE TERMINÉE').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));

      // E1 : score nul, statistiques enregistrées, rien au classement
      expect(find.text('PARTIE TERMINÉE'), findsOneWidget);
      expect(find.text('points · record 2 400'), findsOneWidget);
      expect(find.text('vitesse max'), findsOneWidget);
      expect(find.text('REJOUER'), findsOneWidget);
      expect(find.text('Classement'), findsOneWidget);
      expect(find.text('Statistiques'), findsOneWidget);
      expect(find.text("Retour à l'accueil"), findsOneWidget);
      expect(Hive.box('stats').get('totalGames'), 1);
      expect(Hive.box('leaderboard').get('entries'), isNull);
      expect(Hive.box<int>('scores').get('topscore'), 2400);

      // Rejouer : retour à G1, une seule réinitialisation
      await tester.tap(find.text('REJOUER'));
      await tester.pumpAndSettle();
      expect(find.text("TAPE L'ÉCRAN"), findsOneWidget);
      expect(find.text('SOLO · NORMAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('P1 pause, reprendre, puis quitter sans rien enregistrer, $w',
        (tester) async {
      await _pumpGame(tester, size);

      // Pause inactive avant le début
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.text('PAUSE'), findsNothing);

      await tester.tapAt(const Offset(40, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('PAUSE'), findsOneWidget);
      expect(find.text('REPRENDRE'), findsOneWidget);
      expect(find.text('Quitter la partie'), findsOneWidget);

      await tester.tap(find.text('REPRENDRE'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('PAUSE'), findsNothing);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('Quitter la partie'));
      await tester.pumpAndSettle();

      // Retour à l'accueil : la partie quittée ne compte nulle part
      expect(find.text('Accueil'), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
      expect(Hive.box('stats').get('totalGames'), isNull);
      expect(Hive.box('leaderboard').get('entries'), isNull);
      expect(Hive.box<int>('scores').get('topscore'), isNull);
    });

    testWidgets('fin de partie : retour à l\'accueil, $w', (tester) async {
      await _pumpGame(tester, size);
      await tester.tapAt(const Offset(40, 300));
      for (int i = 0; i < 200 && find.text('PARTIE TERMINÉE').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text("Retour à l'accueil"));
      await tester.pumpAndSettle();
      expect(find.text('Accueil'), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
      expect(Hive.box('stats').get('totalGames'), 1);
    });

    testWidgets('G2 en partie, au renvoi, $w', (tester) async {
      final engine = PongEngine(difficulty: 'Normal', random: Random(1))
        ..playerScore = 1250
        ..ballX = -0.3
        ..ballY = 0.7
        ..playerX = -0.4;
      await _pumpCourt(
        tester,
        size,
        GameCourt(
          engine: engine,
          hasStarted: true,
          isLive: true,
          playerName: 'Léa',
          record: 2400,
          recordBeaten: false,
          effects: const CourtEffects(
              paddleFlash: true, popupProgress: 0.3, popupX: -0.4),
        ),
      );
      expect(find.text('VITESSE 3'), findsOneWidget);
      expect(find.text('RECORD 2 400'), findsOneWidget);
      expect(find.text('1 250'), findsOneWidget);
      expect(find.text('LÉA'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('G3 nouveau record battu, $w', (tester) async {
      final engine = PongEngine(difficulty: 'Normal', random: Random(1))
        ..playerScore = 2450;
      await _pumpCourt(
        tester,
        size,
        GameCourt(
          engine: engine,
          hasStarted: true,
          isLive: true,
          playerName: 'Un pseudo vraiment très long pour la largeur',
          record: 2400,
          recordBeaten: true,
          effects: const CourtEffects(gold: 1),
        ),
      );
      expect(find.text('NOUVEAU RECORD'), findsOneWidget);
      expect(find.text('RECORD 2 400'), findsNothing);
      expect(find.text('2 450'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('P1 voile de pause seul, $w', (tester) async {
      _setSize(tester, size);
      await tester.pumpWidget(MaterialApp(
        theme: PongTheme.dark(),
        home: Scaffold(
          body: PauseOverlay(
              score: 1250, record: 2400, onResume: () {}, onQuit: () {}),
        ),
      ));
      expect(find.text('Score 1 250 · Record 2 400'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('E2 fin de partie record, $w', (tester) async {
      _setSize(tester, size);
      GameOverAction? chosen;
      await tester.pumpWidget(MaterialApp(
        theme: PongTheme.dark(),
        home: Scaffold(
          backgroundColor: PongColors.background,
          body: Center(
            child: Padding(
              padding: PongSpacing.screenPadding,
              child: GameOverCard(
                summary: const GameSummary(
                  score: 2650,
                  previousRecord: 2400,
                  isNewRecord: true,
                  hits: 31,
                  duration: Duration(minutes: 2, seconds: 40),
                  maxSpeed: 8,
                  rank: 1,
                ),
                onAction: (action) => chosen = action,
              ),
            ),
          ),
        ),
      ));
      expect(find.text('NOUVEAU RECORD !'), findsOneWidget);
      expect(find.text('2 650'), findsOneWidget);
      expect(find.textContaining("+250 sur l'ancien record", findRichText: true),
          findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('2m 40s'), findsOneWidget);
      expect(find.text('1er'), findsOneWidget);
      expect(find.text('classement'), findsOneWidget);
      expect(find.text('vitesse max'), findsNothing);
      await tester.tap(find.text('Statistiques'));
      expect(chosen, GameOverAction.statistics);
      expect(tester.takeException(), isNull);
    });
  }

  test('formatRank', () {
    expect(formatRank(1), '1er');
    expect(formatRank(2), '2e');
    expect(formatRank(10), '10e');
  });

  test('GameSummary.record : le meilleur des deux scores', () {
    const beaten = GameSummary(
        score: 900, previousRecord: 400, isNewRecord: true, hits: 0,
        duration: Duration.zero, maxSpeed: 1);
    const notBeaten = GameSummary(
        score: 100, previousRecord: 400, isNewRecord: false, hits: 0,
        duration: Duration.zero, maxSpeed: 1);
    expect(beaten.record, 900);
    expect(notBeaten.record, 400);
  });
}
