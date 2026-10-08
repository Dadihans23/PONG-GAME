// Réglages : la classe PongSettings (valeurs par défaut, enregistrement,
// valeurs illisibles), les catégories de GameSound et l'écran Réglages à
// 320 et 360 dp. Hive écrit dans un dossier temporaire ; les sons n'ont pas
// de plugin natif en test, `GameSound` ignore donc leur chargement.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/settings/settings_page.dart';
import 'package:pong_game/ui/pong_ui.dart';

const List<Size> _screens = [Size(320, 665), Size(360, 800)];

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

Future<void> _pump(WidgetTester tester, Size size, Box<dynamic> box) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      theme: PongTheme.dark(),
      home: SettingsPage(settings: PongSettings(box))));
  await tester.pump();
}

void main() {
  late Directory hiveDir;
  late Box<dynamic> box;
  // Écran : boîte en mémoire. Une écriture sur disque lancée pendant un
  // testWidgets (horloge simulée) ne se termine jamais, et Hive.close() ou
  // clear() l'attendraient sans fin.
  late Box<dynamic> memoryBox;

  setUpAll(() async {
    await _loadArchivo();
    hiveDir = await Directory.systemTemp.createTemp('pong_settings_test');
    Hive.init(hiveDir.path);
    box = await Hive.openBox(PongSettings.boxName);
    memoryBox = await Hive.openBox('settings_memory', bytes: Uint8List(0));
  });

  setUp(() async {
    await box.clear();
    await memoryBox.clear();
    GameSound.musicEnabled = true;
    GameSound.effectsEnabled = true;
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  group('PongSettings', () {
    test('valeurs par défaut = comportement d\'origine', () {
      final settings = PongSettings(box);
      expect(settings.musicEnabled, isTrue);
      expect(settings.soundEffectsEnabled, isTrue);
      expect(settings.vibrationEnabled, isTrue);
      expect(settings.paddleSensitivity, PongSettings.defaultPaddleSensitivity);
      expect(settings.paddleSpeedMultiplier, 1.0);
      expect(settings.pseudo, isNull);
    });

    test('le cran du milieu vaut exactement 1', () {
      const multipliers = PongSettings.paddleSpeedMultipliers;
      expect(multipliers.length, 5);
      expect(multipliers[PongSettings.defaultPaddleSensitivity], 1.0);
      expect(PongSettings.paddleSensitivityLabels.length, multipliers.length);
      for (var i = 1; i < multipliers.length; i++) {
        expect(multipliers[i], greaterThan(multipliers[i - 1]));
      }
    });

    test('les réglages sont enregistrés dans Hive', () {
      final settings = PongSettings(box)
        ..musicEnabled = false
        ..soundEffectsEnabled = false
        ..vibrationEnabled = false
        ..paddleSensitivity = 4;
      expect(box.get(PongSettings.musicKey), isFalse);
      expect(box.get(PongSettings.effectsKey), isFalse);
      expect(box.get(PongSettings.vibrationKey), isFalse);
      expect(box.get(PongSettings.sensitivityKey), 4);

      final reread = PongSettings(box);
      expect(reread.musicEnabled, isFalse);
      expect(reread.soundEffectsEnabled, isFalse);
      expect(reread.vibrationEnabled, isFalse);
      expect(reread.paddleSpeedMultiplier, 1.5);
      expect(settings.paddleSensitivity, 4);
    });

    test('un cran hors limites est ramené dans 0..4', () {
      final settings = PongSettings(box)..paddleSensitivity = 9;
      expect(settings.paddleSensitivity, 4);
      settings.paddleSensitivity = -3;
      expect(settings.paddleSensitivity, 0);
      expect(settings.paddleSpeedMultiplier, 0.6);
    });

    test('une valeur illisible retombe sur la valeur par défaut', () async {
      await box.put(PongSettings.musicKey, 'oui');
      await box.put(PongSettings.sensitivityKey, 12);
      await box.put(PongSettings.pseudoKey, '   ');
      final settings = PongSettings(box);
      expect(settings.musicEnabled, isTrue);
      expect(settings.paddleSensitivity, 2);
      expect(settings.pseudo, isNull);
    });

    test('pseudo : mêmes règles que l\'accueil', () {
      expect(PongSettings.cleanPseudo('   '), isNull);
      expect(PongSettings.cleanPseudo('  Léa '), 'Léa');
      expect(PongSettings.cleanPseudo('a' * 30), 'a' * 20);

      final settings = PongSettings(box);
      expect(settings.savePseudo(''), isNull);
      expect(box.get(PongSettings.pseudoKey), isNull);
      expect(settings.savePseudo(' Max '), 'Max');
      expect(settings.pseudo, 'Max');
    });

    test('le pseudo existant est conservé', () async {
      await box.put(PongSettings.pseudoKey, 'Léa');
      final settings = PongSettings(box)..musicEnabled = false;
      expect(settings.pseudo, 'Léa');
    });

    test('la version affichée est celle de pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match =
          RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec);
      expect(match?.group(1), SettingsPage.appVersion);
    });
  });

  group('GameSound', () {
    test('catégorie : boucle = musique, sinon effet', () {
      final music = GameSound('sounds/background.mp3', loop: true);
      final effect = GameSound('sounds/hitball.mp3');
      final jingle =
          GameSound('sounds/loader.mp3', category: SoundCategory.music);
      expect(music.category, SoundCategory.music);
      expect(effect.category, SoundCategory.effect);
      expect(jingle.category, SoundCategory.music);
      music.dispose();
      effect.dispose();
      jingle.dispose();
    });

    test('les interrupteurs sont indépendants', () async {
      final music = GameSound('sounds/background.mp3', loop: true);
      GameSound.musicEnabled = false;
      expect(GameSound.musicEnabled, isFalse);
      expect(GameSound.effectsEnabled, isTrue);
      // Musique coupée : play() ne joue rien et ne lève pas d'erreur
      await music.play();
      GameSound.musicEnabled = true;
      await music.stop();
      await music.dispose();
    });
  });

  group('écran Réglages', () {
    for (final size in _screens) {
      testWidgets('valeurs par défaut, ${size.width.toInt()} dp',
          (tester) async {
        await _pump(tester, size, memoryBox);

        expect(find.text('RÉGLAGES'), findsOneWidget);
        expect(find.text('Musique'), findsOneWidget);
        expect(find.text('Effets sonores'), findsOneWidget);
        expect(find.text('Vibration'), findsOneWidget);
        expect(find.text('Normale'), findsOneWidget);
        expect(find.text('Aucun'), findsOneWidget);
        expect(find.text('Choisir'), findsOneWidget);
        final switches = tester.widgetList<Switch>(find.byType(Switch));
        expect(switches.length, 3);
        expect(switches.every((s) => s.value), isTrue);
        // Pas de rose plein sur cet écran
        expect(find.byType(PongPrimaryButton), findsNothing);

        await tester.scrollUntilVisible(find.text('PONG · version 1.0.0'), 50);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('les interrupteurs enregistrent et coupent le son',
        (tester) async {
      await _pump(tester, _screens.first, memoryBox);

      await tester.tap(find.text('Musique'));
      await tester.pump();
      expect(PongSettings(memoryBox).musicEnabled, isFalse);
      expect(GameSound.musicEnabled, isFalse);

      await tester.tap(find.text('Effets sonores'));
      await tester.pump();
      expect(PongSettings(memoryBox).soundEffectsEnabled, isFalse);
      expect(GameSound.effectsEnabled, isFalse);

      await tester.tap(find.byType(Switch).at(2));
      await tester.pump();
      expect(PongSettings(memoryBox).vibrationEnabled, isFalse);

      // Retour à l'état d'origine
      await tester.tap(find.text('Musique'));
      await tester.pump();
      expect(GameSound.musicEnabled, isTrue);
    });

    testWidgets('choisir un cran de sensibilité', (tester) async {
      await _pump(tester, _screens.first, memoryBox);

      await tester.tap(find.bySemanticsLabel('Sensibilité Très vive'));
      await tester.pump();
      expect(find.text('Très vive'), findsOneWidget);
      expect(PongSettings(memoryBox).paddleSpeedMultiplier, 1.5);

      await tester.tap(find.bySemanticsLabel('Sensibilité Douce'));
      await tester.pump();
      expect(PongSettings(memoryBox).paddleSpeedMultiplier, 0.8);
    });

    testWidgets('modifier le pseudo', (tester) async {
      await memoryBox.put(PongSettings.pseudoKey, 'Léa');
      await _pump(tester, _screens.first, memoryBox);
      expect(find.text('Léa'), findsOneWidget);

      await tester.ensureVisible(find.text('Modifier'));
      await tester.pump();
      await tester.tap(find.text('Modifier'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Ton pseudo'), findsOneWidget);

      // Vide : refusé, le dialogue reste ouvert
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('ENREGISTRER'));
      await tester.pump();
      expect(find.text('Choisis un pseudo'), findsOneWidget);
      expect(PongSettings(memoryBox).pseudo, 'Léa');

      await tester.enterText(find.byType(TextField), '  Max  ');
      await tester.tap(find.text('ENREGISTRER'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Ton pseudo'), findsNothing);
      expect(find.text('Max'), findsOneWidget);
      expect(PongSettings(memoryBox).pseudo, 'Max');
      expect(tester.takeException(), isNull);
    });
  });
}
