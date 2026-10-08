// Outils communs aux tests d'écrans : vraie police Archivo (pour que les
// textes aient leur vraie largeur) et tailles d'écran vérifiées.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/ui/pong_ui.dart';

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

/// Affiche [page] seule, avec le thème de l'app, sur un écran de [size] dp.
Future<void> pumpScreen(WidgetTester tester, Widget page, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: PongTheme.dark(), home: page));
  await tester.pump();
}
