// Signature du studio (Réglages, Aide) et page « Le studio » : ouverture au
// toucher, contenu avec et sans présentation, liens, mise à jour en direct
// quand la réponse du site arrive, à 320 et 360 dp.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/aide.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/studio/studio_info.dart';
import 'package:pong_game/studio/studio_page.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'support/screen_harness.dart';

const StudioInfo _withAbout = StudioInfo(
  name: 'Nexora',
  about: 'Nexora est un petit studio qui fait des jeux courts.\n\n'
      'Tilto est né d\'une envie : jouer au Pong sans toucher l\'écran.',
  website: 'https://tilto.fun',
  contactUrl: 'https://tilto.fun/contact',
);

/// Page seule, avec un lanceur de liens factice.
Future<List<Uri>> _pumpPage(WidgetTester tester, Size size,
    {ValueListenable<StudioInfo>? studio, bool launchSucceeds = true}) async {
  final opened = <Uri>[];
  await pumpScreen(
    tester,
    StudioPage(
      studio: studio ?? ValueNotifier(StudioInfo.fallback),
      launcher: (url) async {
        opened.add(url);
        return launchSucceeds;
      },
    ),
    size,
  );
  return opened;
}

void main() {
  setUpAll(loadArchivo);
  tearDown(() => Studio.current.value = StudioInfo.fallback);

  group('signature', () {
    testWidgets('toute la ligne est touchable (48 dp) et ouvre la page',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, const AidePage(), testScreens.first);
      final signature = find.byType(PongStudioSignature);
      await tester.scrollUntilVisible(signature, 100);

      final pressable =
          find.descendant(of: signature, matching: find.byType(PongPressable));
      expect(tester.getSize(pressable).height,
          greaterThanOrEqualTo(PongSizes.touchTarget));
      expect(find.bySemanticsLabel('Le studio, ${Brand.studioName}'),
          findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      semantics.dispose();

      await tester.tap(pressable);
      await tester.pumpAndSettle();
      expect(find.byType(StudioPage), findsOneWidget);
      expect(find.text('LE STUDIO'), findsOneWidget);

      // Retour Android : l'Aide
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(StudioPage), findsNothing);
      expect(find.byType(AidePage), findsOneWidget);
    });

    testWidgets('logo intégré, puis logo du site dès qu\'il arrive',
        (tester) async {
      final studio = ValueNotifier(StudioInfo.fallback);
      await pumpScreen(
          tester,
          Center(child: PongStudioSignature(studio: studio, onTap: () {})),
          testScreens.first);
      bool isAsset(Widget w) => w is Image && w.image is AssetImage;
      bool isMemory(Widget w) => w is Image && w.image is MemoryImage;
      expect(find.byWidgetPredicate(isAsset), findsOneWidget);

      // Le studio change de nom sans logo : le nom s'écrit
      studio.value = StudioInfo.fallback.copyWith(name: 'Orbis');
      await tester.pump();
      expect(find.byWidgetPredicate(isAsset), findsNothing);
      expect(find.text('Orbis'), findsOneWidget);

      // Puis son logo arrive
      studio.value = StudioInfo(
        name: 'Orbis',
        about: '',
        website: 'https://tilto.fun',
        contactUrl: 'https://tilto.fun/contact',
        logo: Uint8List.fromList(_transparentPng),
        logoWidth: 1,
        logoHeight: 1,
      );
      await tester.pump();
      expect(find.byWidgetPredicate(isMemory), findsOneWidget);
      expect(find.text('Orbis'), findsNothing);
    });

    testWidgets('sans onTap : inerte, sans chevron', (tester) async {
      await pumpScreen(tester, const Center(child: PongStudioSignature()),
          testScreens.first);
      expect(find.byType(PongPressable), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.text('Un jeu de'), findsOneWidget);
    });
  });

  group('page « Le studio »', () {
    for (final size in testScreens) {
      testWidgets('sans présentation, ${size.width.toInt()} dp',
          (tester) async {
        await _pumpPage(tester, size);
        expect(find.text('Tilto est un jeu de Nexora.'), findsOneWidget);
        // Logo intégré au centre du terrain, aucun paragraphe
        expect(
            find.byWidgetPredicate((w) => w is Image && w.image is AssetImage),
            findsOneWidget);
        expect(
            find.byType(Text).evaluate().where((e) {
              final style = (e.widget as Text).style;
              return style == PongText.body;
            }),
            isEmpty);
        expect(find.text('Visiter le site'), findsOneWidget);
        expect(find.text('Écrire au studio'), findsOneWidget);
        expect(
            find.text('Tilto · version ${Brand.appVersion}'), findsOneWidget);
        // Pas de rose plein : les liens sortent de l'app
        expect(find.byType(PongPrimaryButton), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('avec présentation, ${size.width.toInt()} dp',
          (tester) async {
        await _pumpPage(tester, size, studio: ValueNotifier(_withAbout));
        expect(
            find.text('Nexora est un petit studio qui fait des jeux courts.'),
            findsOneWidget);
        await tester.scrollUntilVisible(
            find.textContaining('sans toucher l\'écran'), 100);
        expect(find.textContaining('sans toucher l\'écran'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('les liens ouvrent le site et la page de contact',
        (tester) async {
      final opened = await _pumpPage(tester, testScreens.first);
      await tester.tap(find.text('Visiter le site'));
      await tester.pump();
      await tester.tap(find.text('Écrire au studio'));
      await tester.pump();
      expect(opened, [
        Uri.parse(Brand.studioWebsite),
        Uri.parse(Brand.studioContactUrl),
      ]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('navigateur introuvable : message discret', (tester) async {
      await _pumpPage(tester, testScreens.first, launchSucceeds: false);
      await tester.tap(find.text('Visiter le site'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text("Le lien ne s'ouvre pas. Va sur tilto.fun depuis ton "
              'navigateur.'),
          findsOneWidget);
    });

    testWidgets('mise à jour en direct quand la réponse du site arrive',
        (tester) async {
      final studio = ValueNotifier(StudioInfo.fallback);
      await _pumpPage(tester, testScreens.first, studio: studio);
      expect(find.text('Tilto est un jeu de Nexora.'), findsOneWidget);

      studio.value = _withAbout.copyWith(name: 'Orbis');
      await tester.pump();
      expect(find.text('Tilto est un jeu de Orbis.'), findsOneWidget);
      expect(find.text('Nexora est un petit studio qui fait des jeux courts.'),
          findsOneWidget);
      // Sans logo pour ce nom : le nom s'écrit au centre du terrain
      expect(find.text('Orbis'), findsOneWidget);
    });

    testWidgets('par défaut, la page suit Studio.current', (tester) async {
      await pumpScreen(tester, const StudioPage(), testScreens.first);
      expect(find.text('Tilto est un jeu de Nexora.'), findsOneWidget);
      Studio.current.value = _withAbout.copyWith(name: 'Orbis');
      await tester.pump();
      expect(find.text('Tilto est un jeu de Orbis.'), findsOneWidget);
    });
  });
}

/// PNG transparent de 1 × 1 pixel.
const List<int> _transparentPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
