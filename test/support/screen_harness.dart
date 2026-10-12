// Outils communs aux tests d'écrans : vraie police Archivo (pour que les
// textes aient leur vraie largeur) et tailles d'écran vérifiées.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Langue des écrans de test : le français, langue d'origine, dans laquelle
/// les tests cherchent leurs textes. Les tests des autres langues passent
/// `locale:` à [pumpScreen].
const Locale testLocale = Locale('fr');

/// Langues de l'app, vérifiées écran par écran.
const List<Locale> testLocales = [Locale('fr'), Locale('en'), Locale('es')];

/// Écrans vérifiés : le SM-A135F (320 × 713 dp, dont 48 de barre de
/// navigation) et la maquette (360 × 800 dp).
const List<Size> testScreens = [Size(320, 665), Size(360, 800)];

/// Charge la police Archivo de l'app (à appeler dans `setUpAll`).
Future<void> loadArchivo() async {
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

/// Affiche [page] seule, avec le thème de l'app, sur un écran de [size] dp,
/// dans la langue [locale] (le français par défaut).
Future<void> pumpScreen(WidgetTester tester, Widget page, Size size,
    {Locale locale = testLocale}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      debugShowCheckedModeBanner: false,
      theme: PongTheme.dark(),
      home: page));
  await tester.pump();
}

/// Échoue si un texte affiché est coupé (« … ») ou dépasse ses lignes :
/// une traduction plus longue doit tenir, rétrécir ou passer à la ligne.
/// [allowed] : textes qu'on accepte de couper (un pseudo très long).
void expectNoTruncatedText(WidgetTester tester,
    {Set<String> allowed = const {}}) {
  final truncated = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.attached) continue;
    if (!paragraph.didExceedMaxLines) continue;
    final text = paragraph.text.toPlainText();
    if (!allowed.contains(text)) truncated.add(text);
  }
  expect(truncated, isEmpty, reason: 'Textes coupés : $truncated');
}
