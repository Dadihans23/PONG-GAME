// Marque : l'app s'ouvre directement sur le chargement (l'intro du studio a
// été retirée), budget de démarrage et nom du jeu. Les sons n'ont pas de
// plugin natif en test, `GameSound` ignore donc leur chargement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/main.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'support/screen_harness.dart';

void main() {
  setUpAll(loadArchivo);

  test('le démarrage dure le chargement seul (4,5 s)', () {
    expect(SplashScreen.startupBudget, SplashScreen.duration);
    expect(SplashScreen.startupBudget, const Duration(milliseconds: 4500));
  });

  testWidgets('le logo texte affiche le nom du jeu', (tester) async {
    await pumpScreen(tester, const Center(child: PongLogo()), testScreens.first);
    expect(find.text(Brand.gameName.toUpperCase()), findsOneWidget);
    expect(find.bySemanticsLabel(Brand.gameName), findsOneWidget);
  });

  testWidgets("l'app s'ouvre sur le chargement, sans logo du studio",
      (tester) async {
    await tester.pumpWidget(const MyApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, Brand.gameName);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(Brand.gameName.toUpperCase()), findsOneWidget);
    expect(find.text('Chargement…'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == Brand.logoLight),
        findsNothing);
  });
}
