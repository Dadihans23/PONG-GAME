// Réglages : la classe PongSettings (valeurs par défaut, enregistrement,
// valeurs illisibles), les catégories de GameSound et l'écran Réglages à
// 320 et 360 dp. Hive écrit dans un dossier temporaire ; les sons n'ont pas
// de plugin natif en test, `GameSound` ignore donc leur chargement.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/settings/settings_page.dart';
import 'package:pong_game/ui/pong_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

// Accéléromètre muet par défaut : la zone d'essai n'a pas de capteur en test
Future<void> _pump(WidgetTester tester, Size size, Box<dynamic> box,
    {Stream<AccelerometerEvent>? accelerometer}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      theme: PongTheme.dark(),
      home: SettingsPage(
          settings: PongSettings(box),
          accelerometer: accelerometer ?? const Stream.empty())));
  await tester.pump();
}

// Téléphone penché de [degrees] vers la droite
AccelerometerEvent _tiltedRight(double degrees) {
  final double angle = degrees * pi / 180;
  return AccelerometerEvent(-9.81 * sin(angle), 9.81 * cos(angle), 0);
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
      expect(settings.paddleSensitivity, PaddleSensitivity.defaultValue);
      expect(settings.pseudo, isNull);
    });

    test('les réglages sont enregistrés dans Hive', () {
      final settings = PongSettings(box)
        ..musicEnabled = false
        ..soundEffectsEnabled = false
        ..vibrationEnabled = false
        ..paddleSensitivity = 65;
      expect(box.get(PongSettings.musicKey), isFalse);
      expect(box.get(PongSettings.effectsKey), isFalse);
      expect(box.get(PongSettings.vibrationKey), isFalse);
      expect(box.get(PongSettings.sensitivityKey), 65);
      expect(PongSettings.sensitivityKey, 'paddleSensitivity100');

      final reread = PongSettings(box);
      expect(reread.musicEnabled, isFalse);
      expect(reread.soundEffectsEnabled, isFalse);
      expect(reread.vibrationEnabled, isFalse);
      expect(reread.paddleSensitivity, 65);
      expect(settings.paddleSensitivity, 65);
    });

    test('une sensibilité hors limites est ramenée dans 0..100', () {
      final settings = PongSettings(box)..paddleSensitivity = 140;
      expect(settings.paddleSensitivity, 100);
      settings.paddleSensitivity = -3;
      expect(settings.paddleSensitivity, 0);
      expect(box.get(PongSettings.sensitivityKey), 0);
    });

    test('ancien cran (0 à 4) converti, nouvelle clé prioritaire', () async {
      const expected = [20, 35, 50, 65, 80];
      for (var notch = 0; notch < 5; notch++) {
        await box.clear();
        await box.put(PongSettings.legacySensitivityKey, notch);
        expect(PongSettings(box).paddleSensitivity, expected[notch],
            reason: 'cran $notch');
      }
      // Une fois réglée sur le nouveau curseur, l'ancienne clé est ignorée
      PongSettings(box).paddleSensitivity = 80;
      expect(PongSettings(box).paddleSensitivity, 80);
      expect(box.get(PongSettings.legacySensitivityKey), 4);
    });

    test('une valeur illisible retombe sur la valeur par défaut', () async {
      await box.put(PongSettings.musicKey, 'oui');
      await box.put(PongSettings.sensitivityKey, 'vive');
      await box.put(PongSettings.legacySensitivityKey, 12);
      await box.put(PongSettings.pseudoKey, '   ');
      final settings = PongSettings(box);
      expect(settings.musicEnabled, isTrue);
      expect(settings.paddleSensitivity, PaddleSensitivity.defaultValue);
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
        // Sensibilité : curseur à la valeur par défaut, bornes, zone d'essai
        expect(find.text('Sensibilité'), findsOneWidget);
        expect(find.byKey(const ValueKey('sensibilite-valeur')), findsOneWidget);
        expect(find.text('${PaddleSensitivity.defaultValue}'), findsOneWidget);
        expect(find.text('Douce'), findsOneWidget);
        expect(find.text('Vive'), findsOneWidget);
        final slider = tester.widget<Slider>(find.byType(Slider));
        expect(slider.value, PaddleSensitivity.defaultValue.toDouble());
        expect(slider.min, 0);
        expect(slider.max, 100);
        expect(tester.getSize(find.byType(Slider)).height,
            greaterThanOrEqualTo(PongSizes.touchTarget));
        expect(find.byKey(const ValueKey('zone-essai')), findsOneWidget);
        expect(find.byKey(const ValueKey('raquette-essai')), findsOneWidget);
        expect(find.text("Zone d'essai · penche ton téléphone"), findsOneWidget);
        final switches = tester.widgetList<Switch>(find.byType(Switch));
        expect(switches.length, 3);
        expect(switches.every((s) => s.value), isTrue);
        // Pas de rose plein sur cet écran
        expect(find.byType(PongPrimaryButton), findsNothing);

        // Profil, sous la carte Sensibilité
        await tester.scrollUntilVisible(find.text('Choisir'), 50);
        expect(find.text('Aucun'), findsOneWidget);
        expect(find.text('Choisir'), findsOneWidget);

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

    for (final size in _screens) {
      testWidgets('régler la sensibilité au curseur, ${size.width.toInt()} dp',
          (tester) async {
        await _pump(tester, size, memoryBox);
        final slider = find.byType(Slider);
        await tester.ensureVisible(slider);
        await tester.pump();

        // Tout à droite : 100, enregistré au relâchement
        await tester.drag(slider, Offset(size.width, 0));
        await tester.pump();
        expect(find.text('100'), findsOneWidget);
        expect(PongSettings(memoryBox).paddleSensitivity, 100);

        // Tout à gauche : 0
        await tester.drag(slider, Offset(-size.width, 0));
        await tester.pump();
        expect(find.text('0'), findsOneWidget);
        expect(PongSettings(memoryBox).paddleSensitivity, 0);

        // Un toucher au milieu de la piste : environ 50
        await tester.tapAt(tester.getCenter(slider));
        await tester.pump();
        final saved = PongSettings(memoryBox).paddleSensitivity;
        expect(saved, inInclusiveRange(45, 55));
        expect(find.text('$saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets("valeur enregistrée affichée à l'ouverture", (tester) async {
      PongSettings(memoryBox).paddleSensitivity = 65;
      await _pump(tester, _screens.first, memoryBox);
      expect(find.text('65'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 65);
    });

    testWidgets("zone d'essai : la raquette suit l'inclinaison, plus vite à 100",
        (tester) async {
      // Distance parcourue en 0,3 s penché de 15° à droite, avec [value]
      Future<double> travel(int value) async {
        PongSettings(memoryBox).paddleSensitivity = value;
        final sensor = StreamController<AccelerometerEvent>();
        await _pump(tester, _screens.last, memoryBox,
            accelerometer: sensor.stream);
        final paddle = find.byKey(const ValueKey('raquette-essai'));
        final double start = tester.getTopLeft(paddle).dx;
        sensor.add(_tiltedRight(15));
        await tester.pump();
        for (var i = 0; i < 18; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final double moved = tester.getTopLeft(paddle).dx - start;
        // Sortie de l'écran : capteur libéré
        await tester.pumpWidget(const SizedBox());
        expect(sensor.hasListener, isFalse);
        unawaited(sensor.close());
        return moved;
      }

      final slow = await travel(0);
      final fast = await travel(100);
      expect(slow, greaterThan(0));
      expect(fast, greaterThan(slow * 2));
    });

    testWidgets("zone d'essai : immobile sans mesure du capteur",
        (tester) async {
      await _pump(tester, _screens.first, memoryBox);
      final paddle = find.byKey(const ValueKey('raquette-essai'));
      final double start = tester.getTopLeft(paddle).dx;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(paddle).dx, start);
      // Aucune image programmée en continu tant que le capteur se tait
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('modifier le pseudo', (tester) async {
      await memoryBox.put(PongSettings.pseudoKey, 'Léa');
      await _pump(tester, _screens.first, memoryBox);
      await tester.scrollUntilVisible(find.text('Modifier'), 50);
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
