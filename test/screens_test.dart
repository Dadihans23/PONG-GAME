// Écrans hors jeu (chargement exclu) : états importants, à 320 et 360 dp
// de large. La police Archivo de l'app est chargée pour que les textes aient
// leur vraie largeur. Hive écrit dans un dossier temporaire ; les sons n'ont
// pas de plugin natif en test, `GameSound` ignore donc leur chargement.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/aide.dart';
import 'package:pong_game/entername.dart';
import 'package:pong_game/leaderboard.dart';
import 'package:pong_game/statistics.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Écrans vérifiés : le SM-A135F (320 × 713 dp, dont 48 de barre de
/// navigation) et la maquette (360 × 800 dp).
const List<Size> _screens = [Size(320, 665), Size(360, 800)];

Future<void> _pump(WidgetTester tester, Widget page, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: PongTheme.dark(), home: page));
  await tester.pump();
}

Future<void> _loadArchivo() async {
  final loader = FontLoader(PongText.fontFamily);
  for (final weight in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ]) {
    final bytes = File('assets/fonts/Archivo-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Map<String, Object> _entry(String name, int score, String date) =>
    {'name': name, 'score': score, 'date': date};

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    await _loadArchivo();
    hiveDir = await Directory.systemTemp.createTemp('pong_screens_test');
    Hive.init(hiveDir.path);
    await Hive.openBox<int>('scores');
    await Hive.openBox('settings');
    await Hive.openBox('leaderboard');
    await Hive.openBox('stats');
  });

  setUp(() async {
    await Hive.box<int>('scores').clear();
    await Hive.box('settings').clear();
    await Hive.box('leaderboard').clear();
    await Hive.box('stats').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  group('accueil', () {
    for (final size in _screens) {
      testWidgets('premier lancement, ${size.width.toInt()} dp',
          (tester) async {
        await _pump(tester, const NamePage(), size);

        expect(find.text('Ton pseudo'), findsOneWidget);
        expect(find.text('Solo'), findsOneWidget);
        expect(find.text('Bientôt'), findsOneWidget);
        expect(find.text('JOUER'), findsOneWidget);
        // Pas encore de score : pas de ligne « Meilleur score »
        expect(find.text('Meilleur score'), findsNothing);
        // Réglages : icône en haut à droite, avec son nom pour TalkBack
        expect(find.byTooltip('Réglages'), findsOneWidget);

        // « Jouer » et les raccourcis tiennent sans défiler
        expect(tester.getBottomLeft(find.text('Aide')).dy,
            lessThan(size.height));

        // « Jouer » avec un pseudo vide : message en clair, rien d'enregistré
        await tester.tap(find.text('JOUER'));
        await tester.pump();
        expect(find.text('Choisis un pseudo pour jouer'), findsOneWidget);
        expect(Hive.box('settings').get('pseudo'), isNull);

        // Le message disparaît dès que le joueur écrit
        await tester.enterText(find.byType(TextField), 'Léa');
        await tester.pump();
        expect(find.text('Choisis un pseudo pour jouer'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('pseudo enregistré, ${size.width.toInt()} dp',
          (tester) async {
        await tester.runAsync(
            () => Hive.box<int>('scores').put('topscore', 2400));
        await _pump(tester, const NamePage(savedPseudo: 'Léa'), size);

        expect(find.text('Bonjour, Léa'), findsOneWidget);
        expect(tester.getBottomLeft(find.text('Aide')).dy,
            lessThan(size.height));
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Meilleur score'), findsOneWidget);
        expect(find.text('2${PongFormat.nbsp}400'), findsOneWidget);

        // « Modifier » ramène le champ, prérempli ; même vidé et en erreur,
        // l'écran tient sans défiler
        await tester.tap(find.text('Modifier'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Léa'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '  ');
        await tester.tap(find.text('JOUER'));
        await tester.pump();
        expect(find.text('Choisis un pseudo pour jouer'), findsOneWidget);
        expect(Hive.box('settings').get('pseudo'), isNull);
        expect(tester.getBottomLeft(find.text('Aide')).dy,
            lessThan(size.height));
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('la difficulté se choisit, le multijoueur est désactivé',
        (tester) async {
      await _pump(tester, const NamePage(savedPseudo: 'Léa'), _screens.first);

      bool selected(String label) => tester
          .widget<PongSelectableButton>(
              find.widgetWithText(PongSelectableButton, label))
          .selected;
      expect(selected('Normal'), isTrue);
      await tester.tap(find.text('Difficile'));
      await tester.pump();
      expect(selected('Difficile'), isTrue);
      expect(selected('Normal'), isFalse);

      final multi = tester.widget<PongChoiceCard>(
          find.widgetWithText(PongChoiceCard, 'Multijoueur'));
      expect(multi.onTap, isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('classement', () {
    for (final size in _screens) {
      testWidgets('vide, ${size.width.toInt()} dp', (tester) async {
        await _pump(tester, const LeaderboardPage(), size);
        expect(find.text('Aucun score enregistré'), findsOneWidget);
        expect(find.text('JOUER'), findsOneWidget);
      });

      testWidgets('rempli, ${size.width.toInt()} dp', (tester) async {
        await tester.runAsync(() => Hive.box('leaderboard').put('entries', [
              for (var i = 0; i < 12; i++)
                _entry(i == 3 ? 'Un pseudo vraiment très long' : 'Joueur $i',
                    100 * (i + 1),
                    '2026-09-${(i + 1).toString().padLeft(2, '0')}'),
            ]));
        await _pump(tester, const LeaderboardPage(), size);

        // Trié par score décroissant : le meilleur en tête, avec le trophée
        expect(find.text('Joueur 11'), findsOneWidget);
        expect(find.text('1${PongFormat.nbsp}200'), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events_rounded), findsNWidgets(3));
        expect(find.text('JOUER'), findsNothing);

        // Dix lignes au plus : le 11ᵉ et le 12ᵉ ne sont jamais affichés
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        expect(find.text('10'), findsOneWidget);
        expect(find.textContaining('Joueur 1 '), findsNothing);
        expect(find.textContaining('Joueur 0'), findsNothing);
      });
    }
  });

  group('statistiques et aide', () {
    for (final size in _screens) {
      testWidgets('statistiques, ${size.width.toInt()} dp', (tester) async {
        await tester.runAsync(() async {
          final stats = Hive.box('stats');
          await stats.put('totalGames', 148);
          await stats.put('totalPlayTimeMs', 4325000);
          await stats.put('bestStreak', 23);
          await Hive.box<int>('scores').put('topscore', 2650);
        });
        await _pump(tester, const StatisticsPage(), size);

        expect(find.text('SOLO'), findsOneWidget);
        expect(find.text('MULTIJOUEUR'), findsNothing);
        expect(find.text('148'), findsOneWidget);
        expect(find.text('2${PongFormat.nbsp}650'), findsOneWidget);
        expect(find.text('1h 12m 5s'), findsOneWidget);
        expect(find.text('23${PongFormat.nbsp}renvois'), findsOneWidget);
      });

      testWidgets('statistiques vides, ${size.width.toInt()} dp',
          (tester) async {
        await _pump(tester, const StatisticsPage(), size);
        expect(find.text('Joue ta première partie pour remplir ces chiffres.'),
            findsOneWidget);
        expect(find.text('0${PongFormat.nbsp}renvoi'), findsOneWidget);
      });

      testWidgets('aide, ${size.width.toInt()} dp', (tester) async {
        await _pump(tester, const AidePage(), size);
        for (final title in [
          'Contrôles',
          'Objectif',
          'Points',
          'Vitesse',
          'Pause',
        ]) {
          await tester.scrollUntilVisible(find.text(title), 100);
          expect(find.text(title), findsOneWidget);
        }
        expect(find.text('Multijoueur'), findsNothing);
      });
    }
  });

  test('mise en forme des chiffres', () {
    expect(PongFormat.number(0), '0');
    expect(PongFormat.number(950), '950');
    expect(PongFormat.number(2400), '2${PongFormat.nbsp}400');
    expect(PongFormat.number(1234567),
        '1${PongFormat.nbsp}234${PongFormat.nbsp}567');
    expect(PongFormat.duration(45000), '45s');
    expect(PongFormat.duration(200000), '3m 20s');
    expect(PongFormat.duration(4325000), '1h 12m 5s');
    expect(PongFormat.date(DateTime(2026, 9, 3)), '03/09/2026');
    expect(PongFormat.count(1, 'renvoi', 'renvois'), '1${PongFormat.nbsp}renvoi');
  });
}
