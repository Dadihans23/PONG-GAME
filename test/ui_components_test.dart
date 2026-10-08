// Construit chaque composant du système de design (lib/ui/) pour vérifier
// qu'aucun ne plante, dans ses états principaux, sur un écran étroit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/ui/pong_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child,
    {Size size = const Size(360, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: PongTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: PongSpacing.screenPadding,
        child: child,
      ),
    ),
  ));
}

void main() {
  testWidgets('le thème sombre utilise Archivo et le rose', (tester) async {
    final theme = PongTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, PongColors.pink);
    expect(theme.textTheme.bodyLarge?.fontFamily, PongText.fontFamily);
  });

  testWidgets('boutons : actifs, désactivés, et taps', (tester) async {
    var taps = 0;
    void tap() => taps++;
    await _pump(
      tester,
      Column(children: [
        PongPrimaryButton(label: 'Jouer', onPressed: tap),
        PongPrimaryButton(
            label: 'Rejouer', icon: Icons.replay_rounded, onPressed: tap),
        const PongPrimaryButton(label: 'Prêt', onPressed: null),
        PongSecondaryButton(
            label: 'Classement',
            icon: Icons.leaderboard_rounded,
            onPressed: tap),
        Row(children: [
          Expanded(
            child: PongSecondaryButton(
                label: 'Statistiques',
                icon: Icons.bar_chart_rounded,
                compact: true,
                onPressed: tap),
          ),
        ]),
        const PongSecondaryButton(label: 'Désactivé', onPressed: null),
        PongTextButton(label: "Retour à l'accueil", onPressed: tap),
        PongTextButton(
            label: 'Modifier',
            icon: Icons.edit_rounded,
            color: PongColors.pinkLight,
            onPressed: tap),
        Row(children: [
          PongIconButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              filled: true,
              onPressed: tap),
          const PongIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Retour',
              onPressed: null),
          PongCompactButton(label: 'Rejoindre', onPressed: tap),
        ]),
        Row(children: [
          Expanded(
            child: PongTileButton(
                icon: Icons.help_rounded, label: 'Aide', onPressed: tap),
          ),
        ]),
      ]),
    );
    expect(find.text('JOUER'), findsOneWidget);
    expect(find.text('PRÊT'), findsOneWidget);

    await tester.tap(find.text('JOUER'));
    await tester.tap(find.text('PRÊT')); // désactivé : ne compte pas
    await tester.tap(find.text('Classement'));
    await tester.tap(find.text('Rejoindre'));
    await tester.tap(find.text('Aide'));
    await tester.pumpAndSettle();
    expect(taps, 4);

    // Zones tactiles d'au moins 48 px.
    expect(tester.getSize(find.byType(PongIconButton).first).height,
        greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(PongTextButton).first).height,
        greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(PongPrimaryButton).first).height, 56);
  });

  testWidgets('sélection : segments et cartes de choix', (tester) async {
    String? chosen;
    var cardTaps = 0;
    await _pump(
      tester,
      Column(children: [
        PongSegmentedControl<String>(
          values: const ['Facile', 'Normal', 'Difficile'],
          selected: 'Normal',
          onChanged: (v) => chosen = v,
        ),
        const PongSegmentedControl<String>(
          values: ['A', 'B'],
          selected: 'A',
          onChanged: null,
        ),
        PongSelectableButton(label: 'Seul', selected: true, onPressed: () {}),
        PongChoiceCard(
          icon: Icons.person_rounded,
          title: 'Solo',
          subtitle: "Contre l'ordinateur",
          selected: true,
          onTap: () => cardTaps++,
          child: const Text('contenu'),
        ),
        const PongChoiceCard(
          icon: Icons.group_rounded,
          title: 'Multijoueur',
          subtitle: 'À deux, même Wi-Fi',
          selected: false,
          onTap: null,
        ),
      ]),
    );
    await tester.tap(find.text('Difficile'));
    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();
    expect(chosen, 'Difficile');
    expect(cardTaps, 1);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('cartes, pastilles, jauges, titres', (tester) async {
    await _pump(
      tester,
      Column(children: [
        const PongLogo(),
        const PongScreenTitle('Classement'),
        const PongOverline('Mode de jeu'),
        const PongCard(child: Text('carte')),
        PongCard(onTap: () {}, child: const Text('carte tactile')),
        PongListRow(
          leading:
              const Icon(Icons.emoji_events_rounded, color: PongColors.gold),
          title: 'Léa',
          subtitle: '12/09/2026',
          value: '2 650',
          borderColor: PongColors.podium(1),
        ),
        PongListRow(
          title: 'Partie de Léa',
          trailing: PongCompactButton(label: 'Rejoindre', onPressed: () {}),
        ),
        const PongStatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Meilleure série',
          value: '23 renvois',
          color: PongColors.streak,
        ),
        const Row(children: [
          Expanded(child: PongFigureTile(value: '18', label: 'renvois')),
          Expanded(child: PongFigureTile(value: '1m 12s', label: 'durée')),
        ]),
        const PongIconBadge(icon: Icons.person_rounded),
        const PongPill.signal(
            label: 'Nouveau record',
            color: PongColors.record,
            icon: Icons.star_rounded),
        const PongPill.status(
            label: 'Prêt',
            color: PongColors.success,
            icon: Icons.check_rounded),
        const PongPill.status(
            label: 'En attente', icon: Icons.hourglass_top_rounded),
        const PongDotGauge(filled: 2, label: 'Vitesse 3'),
        const PongBarGauge(filled: 3),
        const Text('1 250', style: PongText.gameScore),
      ]),
    );
    expect(find.text('CLASSEMENT'), findsOneWidget);
    expect(find.text('MODE DE JEU'), findsOneWidget);
    expect(find.text('NOUVEAU RECORD'), findsOneWidget);
    expect(PongColors.podium(4), isNull);
  });

  testWidgets('champ de texte : défaut, focus, erreur', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? error;
    late StateSetter setOuter;
    await _pump(
      tester,
      StatefulBuilder(builder: (context, setState) {
        setOuter = setState;
        return Column(children: [
          PongTextField(
            controller: controller,
            label: 'Ton pseudo',
            hintText: 'Entre ton pseudo',
            errorText: error,
            maxLength: 5,
          ),
          const PongTextField(hintText: 'Désactivé', enabled: false),
        ]);
      }),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Léa123456');
    await tester.pump();
    expect(controller.text, 'Léa12');

    setOuter(() => error = 'Choisis un pseudo pour jouer');
    await tester.pump();
    expect(find.text('Choisis un pseudo pour jouer'), findsOneWidget);
    await tester.pumpAndSettle(); // fin du tremblement
  });

  testWidgets('en-tête, gabarit et dialogue', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: PongTheme.dark(),
      home: Builder(
        builder: (context) => PongPageScaffold(
          title: 'Statistiques',
          trailing: PongIconButton(
              icon: Icons.settings_rounded,
              tooltip: 'Réglages',
              onPressed: () {}),
          body: ListView(
            padding: PongSpacing.screenPadding,
            children: const [Text('contenu')],
          ),
          bottomAction: PongPrimaryButton(
            label: 'Ouvrir',
            onPressed: () => showPongDialog<void>(
              context: context,
              builder: (context) => PongDialogCard(
                icon: Icons.link_off_rounded,
                iconColor: PongColors.error,
                title: 'Connexion perdue',
                message: "L'autre joueur a quitté la partie.",
                content: const Text('détail'),
                actions: [
                  PongPrimaryButton(
                      label: 'OK', onPressed: () => Navigator.pop(context)),
                  PongTextButton(label: 'Quitter', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('STATISTIQUES'), findsOneWidget);
    expect(tester.getSize(find.byType(PongHeaderBar)).height, 64);

    await tester.tap(find.text('OUVRIR'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion perdue'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion perdue'), findsNothing);
  });
}
