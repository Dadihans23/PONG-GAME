// Écrans du multijoueur (maquette « Pong Multijoueur ») : chaque écran et
// ses états, à 320 et 360 dp, avec la vraie police. Ce sont des écrans de
// présentation : on vérifie ce qui est affiché et les callbacks appelés.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/multiplayer/screens/duel_result_screen.dart';
import 'package:pong_game/multiplayer/screens/duel_screen.dart';
import 'package:pong_game/multiplayer/screens/join_screen.dart';
import 'package:pong_game/multiplayer/screens/lobby_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_menu_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_view_data.dart';
import 'package:pong_game/multiplayer/widgets/duel_court.dart';
import 'package:pong_game/multiplayer/widgets/duel_incident.dart';
import 'package:pong_game/multiplayer/widgets/duel_texts.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'support/screen_harness.dart';

/// Pseudo le plus long accepté (20 caractères) : rien ne doit déborder.
const String longName = 'Maximilien-Alexandre';

/// Simule le bouton retour d'Android.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

/// Bouton principal portant [label] (affiché en majuscules).
PongPrimaryButton primaryButton(WidgetTester tester, String label) =>
    tester.widget<PongPrimaryButton>(
        find.widgetWithText(PongPrimaryButton, label.toUpperCase()));

/// Raquettes et balle dessinées sur le terrain.
Finder decoratedWith(bool Function(BoxDecoration d) test) =>
    find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        test(w.decoration! as BoxDecoration));

final Finder ball = decoratedWith(
    (d) => d.shape == BoxShape.circle && d.color == PongColors.ball);
final Finder myPaddle = decoratedWith((d) => d.color == PongColors.player);
final Finder opponentPaddle =
    decoratedWith((d) => d.color == PongColors.opponent);

void main() {
  setUpAll(loadArchivo);

  test('tournures autour d\'un pseudo', () {
    expect(DuelTexts.gameOf('Tom'), 'Partie de Tom');
    expect(DuelTexts.gameOf('Inès'), "Partie d'Inès");
    expect(DuelTexts.gameOf('Éloïse'), "Partie d'Éloïse");
    expect(DuelTexts.gameOf('Yanis'), 'Partie de Yanis');
    expect(DuelTexts.gameOf('Hugo'), 'Partie de Hugo');
    expect(DuelTexts.waitingFor('Inès'), "En attente d'Inès…");
    expect(DuelTexts.initial(' léa'), 'L');
    expect(DuelTexts.initial(''), '?');
  });

  group('menu (M1)', () {
    for (final size in testScreens) {
      testWidgets('créer ou rejoindre, ${size.width.toInt()} dp',
          (tester) async {
        var created = 0;
        var joined = 0;
        await pumpScreen(
            tester,
            MultiplayerMenuScreen(
              playerName: 'Léa',
              onCreate: () => created++,
              onJoin: () => joined++,
            ),
            size);

        expect(find.text('MULTIJOUEUR'), findsOneWidget);
        expect(find.text('Tu joues en tant que Léa'), findsOneWidget);
        // Deux cartes de même poids, pas de bouton rose
        expect(find.byType(PongPrimaryButton), findsNothing);
        // Le rappel réseau tient en bas de l'écran sans défiler
        expect(tester.getBottomLeft(find.textContaining('Pas besoin')).dy,
            lessThan(size.height));

        await tester.tap(find.text('Créer une partie'));
        await tester.tap(find.text('Rejoindre une partie'));
        expect(created, 1);
        expect(joined, 1);
      });
    }

    testWidgets('création en cours : roue, cartes inactives', (tester) async {
      var taps = 0;
      await pumpScreen(
          tester,
          MultiplayerMenuScreen(
            playerName: longName,
            creating: true,
            onCreate: () => taps++,
            onJoin: () => taps++,
          ),
          testScreens.first);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Créer une partie'));
      await tester.tap(find.text('Rejoindre une partie'));
      expect(taps, 0);
    });
  });

  group('rejoindre (J1, J2, J3)', () {
    const games = [
      DiscoveredGameViewData(id: 'tom', hostName: 'Tom'),
      DiscoveredGameViewData(id: 'ines', hostName: 'Inès', playerCount: 2),
      DiscoveredGameViewData(id: 'long', hostName: longName),
    ];

    for (final size in testScreens) {
      testWidgets('recherche sans résultat, ${size.width.toInt()} dp',
          (tester) async {
        await pumpScreen(
            tester,
            JoinScreen(
                data: const JoinViewData(), onJoin: (_) {}, onRefresh: () {}),
            size);
        expect(find.text('REJOINDRE'), findsOneWidget);
        expect(find.text('Recherche de parties…'), findsOneWidget);
        expect(find.textContaining("Reste près de l'autre joueur"),
            findsOneWidget);
        // Rien à toucher pendant la recherche, à part le retour
        expect(find.byType(PongPrimaryButton), findsNothing);
        expect(find.byType(PongSecondaryButton), findsNothing);
        // Les ondes tournent sans bloquer l'écran
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('parties trouvées, ${size.width.toInt()} dp', (tester) async {
        final joined = <String>[];
        var refreshed = 0;
        await pumpScreen(
            tester,
            JoinScreen(
              data: const JoinViewData(games: games),
              onJoin: joined.add,
              onRefresh: () => refreshed++,
            ),
            size);

        expect(find.text('3 parties à proximité · recherche en cours'),
            findsOneWidget);
        expect(find.text('Partie de Tom'), findsOneWidget);
        expect(find.text("Partie d'Inès"), findsOneWidget);
        // Ni le nom de la partie ni le nombre de joueurs ne sont tronqués
        for (final text in ['Partie de Tom', '1 / 2 joueurs']) {
          expect(
              tester
                  .renderObject<RenderParagraph>(find.text(text).first)
                  .didExceedMaxLines,
              isFalse,
              reason: text);
        }
        expect(find.text('2 / 2 joueurs'), findsOneWidget);
        // Partie pleine : grisée, « Complète », sans bouton
        expect(find.text('Complète'), findsOneWidget);
        expect(find.byType(PongCompactButton), findsNWidgets(2));

        await tester.tap(find.byType(PongCompactButton).first);
        await tester.tap(find.text('Complète'));
        expect(joined, ['tom']);

        // « Actualiser » en secondaire, pas en rose
        expect(find.byType(PongPrimaryButton), findsNothing);
        await tester.tap(find.text('Actualiser'));
        expect(refreshed, 1);
      });

      testWidgets('aucune partie, ${size.width.toInt()} dp', (tester) async {
        var refreshed = 0;
        await pumpScreen(
            tester,
            JoinScreen(
              data: const JoinViewData(searching: false),
              onJoin: (_) {},
              onRefresh: () => refreshed++,
            ),
            size);
        expect(find.text('Aucune partie trouvée'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.textContaining('Créer une partie'), findsOneWidget);
        // Actualiser devient l'action principale
        await tester.tap(find.text('ACTUALISER'));
        expect(refreshed, 1);
      });
    }

    testWidgets('connexion en cours : les autres parties attendent',
        (tester) async {
      final joined = <String>[];
      await pumpScreen(
          tester,
          JoinScreen(
            data: const JoinViewData(
                games: games, searching: false, joiningId: 'tom'),
            onJoin: joined.add,
            onRefresh: () {},
          ),
          testScreens.first);
      expect(find.text('3 parties à proximité'), findsOneWidget);
      expect(find.text('Connexion…'), findsOneWidget);
      final rejoin =
          tester.widget<PongCompactButton>(find.byType(PongCompactButton));
      expect(rejoin.onPressed, isNull);
      final refresh =
          tester.widget<PongSecondaryButton>(find.byType(PongSecondaryButton));
      expect(refresh.onPressed, isNull);
    });
  });

  group('salon (L1 à L4)', () {
    for (final size in testScreens) {
      testWidgets('hôte seul, ${size.width.toInt()} dp', (tester) async {
        var left = 0;
        await pumpScreen(
            tester,
            LobbyScreen(
              data: const LobbyViewData(
                  isHost: true, me: LobbyPlayerViewData(name: 'Léa')),
              onReadyChanged: (_) => fail('Prêt est inactif'),
              onLeave: () => left++,
            ),
            size);

        expect(find.text('SALON'), findsOneWidget);
        expect(find.text('Partie de Léa'), findsOneWidget);
        expect(find.text('Duel · premier à 5 points'), findsOneWidget);
        expect(find.text('Toi · hôte'), findsOneWidget);
        expect(find.text("En attente d'un joueur…"), findsOneWidget);
        expect(find.text('Ta partie est visible par les joueurs à proximité.'),
            findsOneWidget);
        // Pas de bouton retour : on sort par « Annuler la partie »
        expect(find.byTooltip('Retour'), findsNothing);

        // « Prêt » est là, inactif, avec sa raison au-dessus
        expect(primaryButton(tester, 'Prêt').onPressed, isNull);
        expect(find.text("Disponible dès qu'un joueur te rejoint"),
            findsOneWidget);
        // La phrase des ondes reste visible au-dessus de la raison, sans
        // défiler
        expect(
            tester
                .getBottomLeft(find
                    .text('Ta partie est visible par les joueurs à proximité.'))
                .dy,
            lessThan(tester
                    .getTopLeft(
                        find.text("Disponible dès qu'un joueur te rejoint"))
                    .dy -
                PongSpacing.sm));
        await tester.tap(find.text('PRÊT'));

        await tester.tap(find.text('Annuler la partie'));
        expect(left, 1);
        // Le retour Android passe aussi par la sortie du salon
        await pressBack(tester);
        expect(left, 2);
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('joueur connecté, ${size.width.toInt()} dp', (tester) async {
        final ready = <bool>[];
        await pumpScreen(
            tester,
            LobbyScreen(
              data: const LobbyViewData(
                isHost: true,
                me: LobbyPlayerViewData(name: 'Léa'),
                other: LobbyPlayerViewData(name: 'Tom', justJoined: true),
              ),
              onReadyChanged: ready.add,
              onLeave: () {},
            ),
            size);

        expect(find.text('Vient de rejoindre'), findsOneWidget);
        expect(find.text('En attente'), findsNWidgets(2));
        expect(
            find.text('La partie démarre quand vous êtes prêts tous les deux'),
            findsOneWidget);
        expect(find.text("En attente d'un joueur…"), findsNothing);
        await tester.tap(find.text('PRÊT'));
        expect(ready, [true]);
      });

      testWidgets('vu par l\'invité, prêt, ${size.width.toInt()} dp',
          (tester) async {
        final ready = <bool>[];
        var left = 0;
        await pumpScreen(
            tester,
            LobbyScreen(
              data: const LobbyViewData(
                isHost: false,
                me: LobbyPlayerViewData(name: 'Léa', ready: true),
                other: LobbyPlayerViewData(name: 'Tom'),
              ),
              onReadyChanged: ready.add,
              onLeave: () => left++,
            ),
            size);

        // La partie porte le nom de l'hôte ; l'hôte en haut, moi en bas
        expect(find.text('Partie de Tom'), findsOneWidget);
        expect(find.text('Hôte'), findsOneWidget);
        expect(find.text('Toi'), findsOneWidget);
        expect(tester.getTopLeft(find.text('Tom')).dy,
            lessThan(tester.getTopLeft(find.text('Léa')).dy));
        expect(find.text('Prêt'), findsOneWidget);

        // Une fois prêt : plus de rose, on peut seulement annuler
        expect(find.byType(PongPrimaryButton), findsNothing);
        expect(find.text('En attente de Tom…'), findsOneWidget);
        await tester.tap(find.text('Je ne suis plus prêt'));
        expect(ready, [false]);
        await tester.tap(find.text('Quitter'));
        expect(left, 1);
      });

      testWidgets('compte à rebours, ${size.width.toInt()} dp', (tester) async {
        await pumpScreen(
            tester,
            LobbyScreen(
              data: const LobbyViewData(
                isHost: true,
                me: LobbyPlayerViewData(name: longName, ready: true),
                other: LobbyPlayerViewData(name: 'Tom', ready: true),
                countdown: 3,
              ),
              onReadyChanged: (_) {},
              onLeave: () {},
            ),
            size);

        expect(find.text('3'), findsOneWidget);
        expect(find.text('PRENDS TON TÉLÉPHONE'), findsOneWidget);
        expect(find.text('À deux mains, prêt à incliner'), findsOneWidget);
        expect(find.text('${longName.toUpperCase()}  CONTRE  TOM'),
            findsOneWidget);
        // Plus de boutons pendant le compte à rebours
        expect(find.byType(PongPrimaryButton), findsNothing);
        expect(find.text('Annuler la partie'), findsNothing);
      });
    }

    testWidgets("l'autre est prêt : on invite à le rejoindre", (tester) async {
      await pumpScreen(
          tester,
          LobbyScreen(
            data: const LobbyViewData(
              isHost: false,
              me: LobbyPlayerViewData(name: 'Léa'),
              other: LobbyPlayerViewData(name: 'Inès', ready: true),
            ),
            onReadyChanged: (_) {},
            onLeave: () {},
          ),
          testScreens.first);
      expect(find.text("Partie d'Inès"), findsOneWidget);
      expect(find.text("Inès t'attend. À toi !"), findsOneWidget);
      expect(primaryButton(tester, 'Prêt').onPressed, isNotNull);
    });

    testWidgets('le chiffre change à chaque seconde', (tester) async {
      Widget lobby(int value) => LobbyScreen(
            data: LobbyViewData(
              isHost: true,
              me: const LobbyPlayerViewData(name: 'Léa', ready: true),
              other: const LobbyPlayerViewData(name: 'Tom', ready: true),
              countdown: value,
            ),
            onReadyChanged: (_) {},
            onLeave: () {},
          );
      await pumpScreen(tester, lobby(3), testScreens.first);
      await tester
          .pumpWidget(MaterialApp(theme: PongTheme.dark(), home: lobby(2)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });
  });

  group('duel (D1, D2)', () {
    const hud = DuelHudData(
      myName: 'Léa',
      opponentName: 'Tom',
      myScore: 2,
      opponentScore: 3,
    );
    const field = DuelFieldData(
        ballX: 0.4, ballY: -0.3, myPaddleX: -0.6, opponentPaddleX: 0.5);

    for (final size in testScreens) {
      testWidgets('en jeu, ${size.width.toInt()} dp', (tester) async {
        await pumpScreen(
            tester, const DuelScreen(hud: hud, field: field), size);

        expect(find.text('DUEL · PREMIER À 5'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
        // Pas de pause en duel
        expect(find.byTooltip('Pause'), findsNothing);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('LÉA'), findsOneWidget);
        expect(find.text('TOM'), findsOneWidget);
        // Cinq barres par joueur, autant de pleines que de points
        final gauges =
            tester.widgetList<PongBarGauge>(find.byType(PongBarGauge)).toList();
        expect(gauges.map((g) => g.count), [5, 5]);
        expect(gauges.map((g) => g.filled).toSet(), {2, 3});

        // L'adversaire au-dessus de la ligne médiane, moi en dessous
        final double middle = tester.getCenter(find.byType(DuelCourt)).dy;
        expect(tester.getCenter(find.text('TOM')).dy, lessThan(middle));
        expect(tester.getCenter(find.text('LÉA')).dy, greaterThan(middle));

        // Raquettes à 0,27 × la largeur du terrain, balle visible
        final double courtWidth = tester.getSize(find.byType(DuelCourt)).width;
        expect(
            tester.getSize(myPaddle).width, closeTo(courtWidth * 0.27, 0.01));
        expect(tester.getSize(opponentPaddle).width,
            closeTo(courtWidth * 0.27, 0.01));
        expect(ball, findsOneWidget);
        // Ma raquette en bas, à gauche (x = -0,6) ; l'adversaire en haut
        expect(tester.getCenter(myPaddle).dy, greaterThan(middle));
        expect(tester.getCenter(opponentPaddle).dy, lessThan(middle));
        expect(tester.getCenter(myPaddle).dx,
            lessThan(tester.getCenter(find.byType(DuelCourt)).dx));
      });

      testWidgets('point marqué, ${size.width.toInt()} dp', (tester) async {
        await pumpScreen(
            tester,
            const DuelScreen(
              hud: DuelHudData(
                  myName: longName,
                  opponentName: 'Tom',
                  myScore: 3,
                  opponentScore: 3),
              field: field,
              point: DuelPointData(scorer: DuelSide.me, resumeIn: 2),
            ),
            size);
        await tester.pump(const Duration(milliseconds: 300));

        expect(
            find.text('POINT POUR ${longName.toUpperCase()}'), findsOneWidget);
        expect(find.text('Reprise dans 2…'), findsOneWidget);
        expect(find.text('–'), findsOneWidget);
        // Pas de balle pendant l'annonce
        expect(ball, findsNothing);
      });
    }

    testWidgets('connexion dégradée : indicateur rouge', (tester) async {
      await pumpScreen(
          tester,
          const DuelScreen(
            hud: DuelHudData(
              myName: 'Léa',
              opponentName: 'Tom',
              myScore: 0,
              opponentScore: 0,
              connection: DuelConnection.weak,
            ),
            field: DuelFieldData.initial,
          ),
          testScreens.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Connexion faible'), findsOneWidget);
      final icon =
          tester.widget<Icon>(find.byIcon(Icons.network_wifi_1_bar_rounded));
      expect(icon.color, PongColors.error);
    });

    testWidgets('le retour Android est remonté, pas exécuté', (tester) async {
      var requests = 0;
      await pumpScreen(
          tester,
          DuelScreen(
            hud: hud,
            field: field,
            onLeaveRequested: () => requests++,
          ),
          testScreens.first);
      await pressBack(tester);
      expect(requests, 1);
      expect(find.byType(DuelScreen), findsOneWidget);
    });
  });

  group('fin du duel (V1, V2)', () {
    DuelResultData result({
      int me = 5,
      int other = 3,
      RematchState rematch = RematchState.none,
      String myName = 'Léa',
    }) =>
        DuelResultData(
          myName: myName,
          opponentName: 'Tom',
          myScore: me,
          opponentScore: other,
          duration: const Duration(minutes: 2, seconds: 41),
          longestRally: 14,
          rematch: rematch,
        );

    for (final size in testScreens) {
      testWidgets('victoire, ${size.width.toInt()} dp', (tester) async {
        var rematch = 0;
        var quit = 0;
        await pumpScreen(
            tester,
            DuelResultScreen(
              result: result(myName: longName),
              onRematch: () => rematch++,
              onQuit: () => quit++,
            ),
            size);

        expect(find.text('VICTOIRE'), findsOneWidget);
        expect(find.text('$longName gagne !'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(
            find.text('2m 41s · plus long échange : '
                '14${PongFormat.nbsp}renvois'),
            findsOneWidget);
        await tester.tap(find.text('REJOUER'));
        await tester.tap(find.text('Quitter'));
        expect(rematch, 1);
        expect(quit, 1);
        await pressBack(tester);
        expect(quit, 2);
      });

      testWidgets(
          'défaite, en attente de la revanche, '
          '${size.width.toInt()} dp', (tester) async {
        var cancelled = 0;
        await pumpScreen(
            tester,
            DuelResultScreen(
              result: result(me: 3, other: 5, rematch: RematchState.iAsked),
              onRematch: () => fail('déjà demandé'),
              onCancelRematch: () => cancelled++,
              onQuit: () {},
            ),
            size);
        expect(find.text('DÉFAITE'), findsOneWidget);
        expect(find.text('Tom gagne !'), findsOneWidget);
        expect(find.text('Si près ! La revanche ?'), findsOneWidget);
        expect(find.text("Tu veux rejouer · Tom n'a pas encore répondu"),
            findsOneWidget);
        expect(find.byType(PongPrimaryButton), findsNothing);
        await tester.tap(find.text('En attente de Tom…'));
        expect(cancelled, 1);
      });
    }

    testWidgets("l'autre demande la revanche le premier", (tester) async {
      var rematch = 0;
      await pumpScreen(
          tester,
          DuelResultScreen(
            result:
                result(me: 0, other: 5, rematch: RematchState.opponentAsked),
            onRematch: () => rematch++,
            onQuit: () {},
          ),
          testScreens.first);
      expect(find.text('Tom veut rejouer'), findsOneWidget);
      expect(find.text('La revanche ?'), findsOneWidget);
      await tester.tap(find.text('REJOUER'));
      expect(rematch, 1);
    });

    testWidgets("l'autre est parti : Rejouer inactif", (tester) async {
      await pumpScreen(
          tester,
          DuelResultScreen(
            result: result(rematch: RematchState.opponentLeft),
            onRematch: () => fail('personne en face'),
            onQuit: () {},
          ),
          testScreens.first);
      expect(find.text('Tom a quitté la partie'), findsOneWidget);
      expect(primaryButton(tester, 'Rejouer').onPressed, isNull);
    });
  });

  group('incidents (X1, X2, X3)', () {
    final incidents = <String, DuelIncident>{
      'hôte, joueur déconnecté': const DuelIncident.opponentDisconnected('Tom'),
      "invité, l'hôte a quitté": const DuelIncident.hostLeft('Tom'),
      'connexion impossible': const DuelIncident.connectionFailed(),
      'connexion perdue': const DuelIncident.connectionLost(longName),
      'partie complète': const DuelIncident.gameFull('Inès'),
      'pas de Wi-Fi': const DuelIncident.noNetwork(),
      'quitter le duel': const DuelIncident.leaveDuel('Tom'),
    };

    for (final size in testScreens) {
      for (final entry in incidents.entries) {
        testWidgets('${entry.key}, ${size.width.toInt()} dp', (tester) async {
          final incident = entry.value;
          DuelIncidentAction? chosen;
          await pumpScreen(
              tester,
              Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () async =>
                          chosen = await showDuelIncident(context, incident),
                      child: const Text('ouvrir'),
                    ),
                  ),
                ),
              ),
              size);
          await tester.tap(find.text('ouvrir'));
          await tester.pumpAndSettle();

          expect(find.text(incident.title), findsOneWidget);
          expect(find.text(incident.message), findsOneWidget);
          // Le retour Android ne ferme pas l'incident
          await pressBack(tester);
          expect(find.text(incident.title), findsOneWidget);

          final secondary = incident.secondaryLabel;
          if (secondary != null) {
            await tester.tap(find.text(secondary));
            await tester.pumpAndSettle();
            expect(chosen, DuelIncidentAction.secondary);
          } else {
            await tester.tap(find.text(incident.primaryLabel.toUpperCase()));
            await tester.pumpAndSettle();
            expect(chosen, DuelIncidentAction.primary);
          }
          expect(find.text(incident.title), findsNothing);
        });
      }
    }

    test('les textes ne parlent ni de code ni d\'adresse', () {
      for (final incident in incidents.values) {
        expect(
            incident.message,
            isNot(contains(
                RegExp(r'\b(IP|erreur)\b|\d+\.\d+', caseSensitive: false))));
      }
    });
  });
}
