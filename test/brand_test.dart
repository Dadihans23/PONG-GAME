// Marque : intro du studio (enchaînement vers le chargement, toucher pour
// passer, réduction des animations), budget de démarrage et nom du jeu.
// Les sons n'ont pas de plugin natif en test, `GameSound` ignore donc leur
// chargement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/main.dart';
import 'package:pong_game/studio_intro.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'support/screen_harness.dart';

Future<void> _pumpIntro(WidgetTester tester, {bool reduceMotion = false}) {
  tester.view.physicalSize = testScreens.first;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(MaterialApp(
    theme: PongTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: const StudioIntro(next: SplashScreen.builder),
  ));
}

// Fondu vers le chargement, puis retrait de l'intro (le chargement anime
// sa balle en boucle : pas de pumpAndSettle)
Future<void> _pumpTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(StudioIntro.transition);
  await tester.pump(StudioIntro.transition);
}

Finder get _studioLogo => find.byWidgetPredicate((widget) =>
    widget is Image &&
    widget.image is AssetImage &&
    (widget.image as AssetImage).assetName == Brand.logoLight);

void main() {
  setUpAll(loadArchivo);

  test('intro + chargement = 6 s, comme avant l\'intro', () {
    expect(StudioIntro.duration,
        StudioIntro.fadeIn + StudioIntro.hold + StudioIntro.fadeOut);
    expect(StudioIntro.duration + SplashScreen.duration,
        SplashScreen.startupBudget);
    expect(SplashScreen.startupBudget, const Duration(seconds: 6));
  });

  testWidgets('l\'intro montre le logo du studio puis mène au chargement',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpIntro(tester);
    expect(_studioLogo, findsOneWidget);
    expect(find.bySemanticsLabel(Brand.studioName), findsOneWidget);
    semantics.dispose();
    expect(find.byType(SplashScreen), findsNothing);

    // Logo visible au milieu de l'intro
    await tester.pump(StudioIntro.fadeIn + StudioIntro.hold ~/ 2);
    final fade = tester.widget<FadeTransition>(find.ancestor(
        of: _studioLogo, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1.0);
    expect(find.byType(SplashScreen), findsNothing);

    // Fin de l'intro : le chargement la remplace
    await tester.pump(StudioIntro.duration);
    await _pumpTransition(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(StudioIntro), findsNothing);
    expect(find.text(Brand.gameName.toUpperCase()), findsOneWidget);
    expect(find.text('Chargement…'), findsOneWidget);
  });

  testWidgets('un toucher passe l\'intro', (tester) async {
    await _pumpIntro(tester);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byType(StudioIntro));
    await _pumpTransition(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(StudioIntro), findsNothing);

    // La fin prévue de l'intro ne relance pas de navigation
    await tester.pump(StudioIntro.duration);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('réduction des animations : logo sans fondu, même enchaînement',
      (tester) async {
    await _pumpIntro(tester, reduceMotion: true);
    expect(_studioLogo, findsOneWidget);
    expect(
        find.ancestor(of: _studioLogo, matching: find.byType(FadeTransition)),
        findsNothing);

    await tester.pump(StudioIntro.duration);
    await _pumpTransition(tester);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(StudioIntro), findsNothing);
  });

  testWidgets('le logo texte affiche le nom du jeu', (tester) async {
    await pumpScreen(tester, const Center(child: PongLogo()), testScreens.first);
    expect(find.text(Brand.gameName.toUpperCase()), findsOneWidget);
    expect(find.bySemanticsLabel(Brand.gameName), findsOneWidget);
  });

  testWidgets('MaterialApp porte le nom du jeu', (tester) async {
    await tester.pumpWidget(const MyApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, Brand.gameName);
    expect(find.byType(StudioIntro), findsOneWidget);
  });
}
