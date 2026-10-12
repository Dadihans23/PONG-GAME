// Langues de l'app : fichiers de traduction cohérents, choix de la langue
// (téléphone, Réglages), et police capable d'écrire les trois langues.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/entername.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/main.dart';

const List<String> _languages = ['fr', 'en', 'es'];

Map<String, dynamic> _readArb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Clés des messages (sans les métadonnées `@…`).
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

/// Placeholders utilisés par un message : `{nom}` ou `{nom, plural|select…`,
/// sans compter le texte des branches (`one{renvoi}`).
Set<String> _usedPlaceholders(String message) => RegExp(r'(?<![\w=])\{(\w+)[,}]')
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();

/// Caractères (points de code) d'une police TrueType, lus dans sa table
/// `cmap` (format 4, Unicode BMP).
Set<int> _fontCodePoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final numTables = data.getUint16(4);
  int? cmap;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  if (cmap == null) return {};
  final numSubtables = data.getUint16(cmap + 2);
  for (var i = 0; i < numSubtables; i++) {
    final entry = cmap + 4 + 8 * i;
    final platform = data.getUint16(entry);
    final encoding = data.getUint16(entry + 2);
    final offset = cmap + data.getUint32(entry + 4);
    if (platform != 3 || encoding != 1 || data.getUint16(offset) != 4) {
      continue;
    }
    final segCount = data.getUint16(offset + 6) ~/ 2;
    final ends = offset + 14;
    final starts = ends + 2 * segCount + 2;
    final deltas = starts + 2 * segCount;
    final rangeOffsets = deltas + 2 * segCount;
    final points = <int>{};
    for (var s = 0; s < segCount; s++) {
      final end = data.getUint16(ends + 2 * s);
      final start = data.getUint16(starts + 2 * s);
      final delta = data.getUint16(deltas + 2 * s);
      final rangeOffsetAt = rangeOffsets + 2 * s;
      final rangeOffset = data.getUint16(rangeOffsetAt);
      for (var c = start; c <= end && c != 0xFFFF; c++) {
        int glyph;
        if (rangeOffset == 0) {
          glyph = (c + delta) & 0xFFFF;
        } else {
          final at = rangeOffsetAt + rangeOffset + 2 * (c - start);
          glyph = data.getUint16(at);
          if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
        }
        if (glyph != 0) points.add(c);
      }
    }
    return points;
  }
  return {};
}

void main() {
  group('fichiers de traduction', () {
    final arbs = {for (final language in _languages) language: _readArb(language)};
    final template = arbs['fr']!;
    final keys = _messageKeys(template);

    test('les trois langues ont exactement les mêmes clés', () {
      expect(keys, isNotEmpty);
      for (final language in _languages) {
        expect(arbs[language]!['@@locale'], language);
        expect(_messageKeys(arbs[language]!), keys,
            reason: 'clés de app_$language.arb');
      }
    });

    test('chaque chaîne a une description pour les relecteurs', () {
      for (final key in keys) {
        final meta = template['@$key'];
        expect(meta, isA<Map<String, dynamic>>(), reason: key);
        expect((meta as Map)['description'], isA<String>(), reason: key);
        expect((meta['description'] as String).length, greaterThan(10),
            reason: key);
      }
    });

    test('mêmes placeholders dans les trois langues, tous déclarés', () {
      for (final key in keys) {
        final meta = template['@$key'] as Map<String, dynamic>;
        final declared =
            ((meta['placeholders'] as Map<String, dynamic>?) ?? {}).keys.toSet();
        for (final language in _languages) {
          final message = arbs[language]![key] as String;
          expect(message.trim(), isNotEmpty, reason: '$language/$key');
          expect(_usedPlaceholders(message), declared,
              reason: '$language/$key : « $message »');
        }
      }
    });

    test('pluriels et choix présents dans les trois langues', () {
      for (final key in keys) {
        final fr = template[key] as String;
        for (final kind in ['plural', 'select']) {
          if (!fr.contains(', $kind,')) continue;
          for (final language in ['en', 'es']) {
            expect(arbs[language]![key], contains(', $kind,'),
                reason: '$language/$key doit garder le $kind');
            expect(arbs[language]![key], contains('other{'),
                reason: '$language/$key : branche other obligatoire');
          }
        }
      }
    });

    test('la police Archivo écrit tous les caractères des trois langues', () {
      final needed = <int>{
        for (final arb in arbs.values)
          for (final key in _messageKeys(arb))
            ...(arb[key] as String).runes,
        // Noms des langues et symboles de mise en forme
        for (final name in AppLanguage.values)
          if (name.nativeName != null) ...name.nativeName!.runes,
        ...'ñÑ¿¡áéíóúüÁÉÍÓÚÜº'.runes,
      }..removeWhere((rune) => rune <= 0x20);
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ]) {
        final font = _fontCodePoints(
            File('assets/fonts/Archivo-$weight.ttf').readAsBytesSync());
        final missing = needed.difference(font).map(String.fromCharCode);
        expect(missing, isEmpty, reason: 'Archivo-$weight sans $missing');
      }
    });
  });

  group('langue du téléphone', () {
    test('fr, en, es quel que soit le pays, sinon l\'anglais', () {
      String resolve(List<Locale> locales) =>
          resolveAppLocale(locales).languageCode;
      expect(resolve(const [Locale('fr', 'CI')]), 'fr');
      expect(resolve(const [Locale('fr', 'CA')]), 'fr');
      expect(resolve(const [Locale('es', 'MX')]), 'es');
      expect(resolve(const [Locale('es', 'ES')]), 'es');
      expect(resolve(const [Locale('en', 'GB')]), 'en');
      expect(resolve(const [Locale('de', 'DE')]), 'en');
      expect(resolve(const [Locale('ar')]), 'en');
      expect(resolve(const []), 'en');
      expect(resolveAppLocale(null).languageCode, 'en');
      // Langues préférées : la première que l'app parle
      expect(resolve(const [Locale('de', 'DE'), Locale('es', 'AR')]), 'es');
    });

    test('le pays est gardé pour le format des dates', () {
      expect(resolveAppLocale(const [Locale('en', 'GB')]),
          const Locale('en', 'GB'));
      expect(resolveAppLocale(const [Locale('es', 'MX')]),
          const Locale('es', 'MX'));
    });

    test('choix des Réglages : valeur enregistrée et langue effective', () {
      expect(AppLanguage.fromCode('system'), AppLanguage.system);
      expect(AppLanguage.fromCode('fr'), AppLanguage.french);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('es'), AppLanguage.spanish);
      expect(AppLanguage.fromCode(null), AppLanguage.system);
      expect(AppLanguage.fromCode('de'), AppLanguage.system);
      expect(AppLanguage.fromCode(3), AppLanguage.system);
      expect(
          effectiveLanguageCode(AppLanguage.system, const [Locale('es', 'CO')]),
          'es');
      expect(
          effectiveLanguageCode(AppLanguage.system, const [Locale('it')]), 'en');
      expect(
          effectiveLanguageCode(AppLanguage.french, const [Locale('es')]), 'fr');
    });

    test('les difficultés gardent leurs valeurs internes', () {
      expect(NamePage.difficulties, ['Facile', 'Normal', 'Difficile']);
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      expect([for (final d in NamePage.difficulties) en.difficultyLabel(d)],
          ['Easy', 'Normal', 'Hard']);
      expect([for (final d in NamePage.difficulties) es.difficultyLabel(d)],
          ['Fácil', 'Normal', 'Difícil']);
    });
  });

  group('app', () {
    Widget probe() => MyApp(
          home: Builder(
              builder: (context) => Scaffold(body: Text(context.l10n.homePlay))),
        );

    setUp(() => AppLanguageSetting.current.value = AppLanguage.system);
    tearDown(() => AppLanguageSetting.current.value = AppLanguage.system);

    testWidgets('« Automatique » suit la langue du téléphone, en direct',
        (tester) async {
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
      await tester.pumpWidget(probe());
      expect(find.text('Jugar'), findsOneWidget);

      // Le joueur change la langue de son téléphone, l'app ouverte
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'CI')];
      await tester.pump();
      expect(find.text('Jouer'), findsOneWidget);

      tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
      await tester.pump();
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('un choix manuel s\'applique tout de suite et ne suit plus '
        'le téléphone', (tester) async {
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      await tester.pumpWidget(probe());
      expect(find.text('Jouer'), findsOneWidget);

      AppLanguageSetting.current.value = AppLanguage.spanish;
      await tester.pump();
      expect(find.text('Jugar'), findsOneWidget);

      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      await tester.pump();
      expect(find.text('Jugar'), findsOneWidget);

      AppLanguageSetting.current.value = AppLanguage.system;
      await tester.pump();
      expect(find.text('Play'), findsOneWidget);
    });
  });
}
