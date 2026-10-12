// Chaque écran dans les trois langues, à 320 et 360 dp de large : rien ne
// déborde (un débordement fait échouer le test) et aucun texte n'est coupé
// par « … ». L'espagnol est souvent 20 à 30 % plus long que le français.
//
// Captures : `TILTO_SHOTS=<dossier> flutter test test/l10n_screens_test.dart`
// écrit une image PNG par écran, langue et largeur dans ce dossier.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/aide.dart';
import 'package:pong_game/entername.dart';
import 'package:pong_game/game_ui/game_over_card.dart';
import 'package:pong_game/game_ui/pause_overlay.dart';
import 'package:pong_game/hompage.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/leaderboard.dart';
import 'package:pong_game/multiplayer/screens/duel_result_screen.dart';
import 'package:pong_game/multiplayer/screens/duel_screen.dart';
import 'package:pong_game/multiplayer/screens/join_screen.dart';
import 'package:pong_game/multiplayer/screens/lobby_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_menu_screen.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_view_data.dart';
import 'package:pong_game/multiplayer/widgets/duel_incident.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/settings/settings_page.dart';
import 'package:pong_game/statistics.dart';
import 'package:pong_game/studio/studio_info.dart';
import 'package:pong_game/studio/studio_page.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'support/screen_harness.dart';

/// Dossier des captures, ou `null` (pas de capture).
final String? _shotsDir = Platform.environment['TILTO_SHOTS'];

/// Icônes Material du SDK, pour des captures lisibles (sans elles, chaque
/// icône est un carré).
Future<void> _loadMaterialIcons() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final file = File('$flutterRoot/bin/cache/artifacts/material_fonts/'
      'materialicons-regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotsDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final element = find.byType(MaterialApp).evaluate().first;
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Vérifie l'écran affiché (ni débordement ni texte coupé), puis le capture.
Future<void> _check(WidgetTester tester, String name,
    {Set<String> allowed = const {}}) async {
  expect(tester.takeException(), isNull, reason: name);
  expectNoTruncatedText(tester, allowed: allowed);
  await _shot(tester, name);
}

/// Ouvre un dialogue Pong au-dessus d'un écran vide, comme en jeu.
class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showPongDialog<void>(context: context, builder: widget.builder);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: PongColors.background);
}

const DuelHudData _hud = DuelHudData(
  myName: 'Léa',
  opponentName: 'Tom',
  myScore: 3,
  opponentScore: 2,
  connection: DuelConnection.weak,
);

DuelResultData _result(
        {required int me, required int other, RematchState? rematch}) =>
    DuelResultData(
      myName: 'Léa',
      opponentName: 'Inès',
      myScore: me,
      opponentScore: other,
      duration: const Duration(minutes: 2, seconds: 14),
      longestRally: 14,
      rematch: rematch ?? RematchState.none,
    );

/// Accéléromètre muet : les captures laissent passer le vrai temps
/// (`runAsync`), et le capteur n'a pas de plugin natif en test.
void _muteSensors() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (_) async => null);
  messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
      MockStreamHandler.inline(onListen: (_, __) {}));
}

void main() {
  late Directory hiveDir;
  late Box<dynamic> memorySettings;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _muteSensors();
    await loadArchivo();
    await _loadMaterialIcons();
    hiveDir = await Directory.systemTemp.createTemp('tilto_l10n_screens');
    Hive.init(hiveDir.path);
    await Hive.openBox<int>('scores');
    await Hive.openBox('settings');
    await Hive.openBox('leaderboard');
    await Hive.openBox('stats');
    memorySettings =
        await Hive.openBox('settings_memory', bytes: Uint8List(0));
  });

  setUp(() async {
    await Hive.box<int>('scores').clear();
    await Hive.box('settings').clear();
    await Hive.box('leaderboard').clear();
    await Hive.box('stats').clear();
    await memorySettings.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  Future<void> fillStats() async {
    final stats = Hive.box('stats');
    await stats.put('totalGames', 148);
    await stats.put('totalPlayTimeMs', 4325000);
    await stats.put('bestStreak', 23);
    await stats.put('duelWins', 12);
    await stats.put('duelLosses', 7);
    await Hive.box<int>('scores').put('topscore', 2400);
  }

  testWidgets('en anglais, « Hard » lance le moteur en « Difficile »',
      (tester) async {
    await pumpScreen(tester, const NamePage(savedPseudo: 'Léa'),
        testScreens.first,
        locale: const Locale('en'));
    expect(find.text('Easy'), findsOneWidget);
    await tester.tap(find.text('Hard'));
    await tester.pump();
    // Hive écrit le pseudo pour de vrai : toucher hors de l'horloge simulée
    await tester.runAsync(() async {
      await tester.tap(find.text('PLAY'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final game = tester.widget<MyHomePage>(find.byType(MyHomePage));
    expect(game.difficulty, 'Difficile');
    expect(find.text('SOLO · HARD'), findsOneWidget);
  });

  for (final locale in testLocales) {
    for (final size in testScreens) {
      final String tag = '${locale.languageCode}_${size.width.toInt()}';
      Future<void> pump(WidgetTester tester, Widget page) =>
          pumpScreen(tester, page, size, locale: locale);

      group('$tag :', () {
        testWidgets('accueil', (tester) async {
          await pump(tester, const NamePage());
          await _check(tester, '${tag}_accueil_premier_lancement');
          // Pseudo vide : le message d'erreur tient aussi
          await tester.tap(find.byType(PongPrimaryButton));
          await tester.pump(const Duration(milliseconds: 400));
          await _check(tester, '${tag}_accueil_erreur_pseudo');
        });

        testWidgets('accueil avec pseudo, solo puis multijoueur',
            (tester) async {
          await tester.runAsync(fillStats);
          await pump(tester, const NamePage(savedPseudo: 'Léa'));
          // « Jouer » et les raccourcis tiennent sans défiler
          expect(tester.getBottomLeft(find.byType(PongTileButton).first).dy,
              lessThan(size.height));
          await _check(tester, '${tag}_accueil_solo');

          final l10n = lookupAppLocalizations(locale);
          await tester.tap(find.text(l10n.modeMultiplayer));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.getBottomLeft(find.byType(PongTileButton).first).dy,
              lessThan(size.height));
          await _check(tester, '${tag}_accueil_multijoueur');
        });

        testWidgets('partie : avant le premier tap', (tester) async {
          await tester.runAsync(
              () => Hive.box<int>('scores').put('topscore', 2400));
          await pump(
              tester,
              const MyHomePage(
                  title: 'Tilto', playerName: 'Léa', difficulty: 'Difficile'));
          await _check(tester, '${tag}_partie_debut');
        });

        testWidgets('pause', (tester) async {
          await pump(
              tester,
              Scaffold(
                body: PauseOverlay(
                    score: 12450,
                    record: 24000,
                    onResume: () {},
                    onQuit: () {}),
              ));
          await _check(tester, '${tag}_pause');
        });

        for (final record in [false, true]) {
          testWidgets('fin de partie${record ? ' record' : ''}',
              (tester) async {
            await pump(
              tester,
              _DialogHost(
                builder: (context) => SingleChildScrollView(
                  child: GameOverCard(
                    summary: GameSummary(
                      score: record ? 2650 : 1200,
                      previousRecord: 2400,
                      isNewRecord: record,
                      hits: 23,
                      duration: const Duration(minutes: 3, seconds: 20),
                      maxSpeed: 6,
                      rank: record ? 2 : 5,
                    ),
                    onAction: (_) {},
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 600));
            await _check(
                tester, '${tag}_fin_de_partie${record ? '_record' : ''}');
          });
        }

        testWidgets('classement', (tester) async {
          await pump(tester, const LeaderboardPage());
          await _check(tester, '${tag}_classement_vide');
          await tester.runAsync(() => Hive.box('leaderboard').put('entries', [
                for (var i = 0; i < 10; i++)
                  {
                    'name': ['Léa', 'Tom', 'Inès', 'Max'][i % 4],
                    'score': 950 * (i + 1),
                    'date': '2026-09-${(i + 1).toString().padLeft(2, '0')}',
                  },
              ]));
          await pump(tester, const LeaderboardPage());
          await _check(tester, '${tag}_classement');
        });

        testWidgets('statistiques', (tester) async {
          await pump(tester, const StatisticsPage());
          await _check(tester, '${tag}_statistiques_vides');
          await tester.runAsync(fillStats);
          await pump(tester, const StatisticsPage());
          await _check(tester, '${tag}_statistiques');
          await tester.drag(find.byType(ListView), const Offset(0, -600));
          await tester.pump();
          await _check(tester, '${tag}_statistiques_bas');
        });

        testWidgets('aide', (tester) async {
          await pump(tester, const AidePage());
          await _check(tester, '${tag}_aide');
          await tester.drag(find.byType(ListView), const Offset(0, -1200));
          await tester.pump();
          await _check(tester, '${tag}_aide_bas');
        });

        testWidgets('réglages, jusqu\'au choix de la langue', (tester) async {
          await memorySettings.put(PongSettings.pseudoKey, 'Léa');
          await pump(
              tester,
              SettingsPage(
                  settings: PongSettings(memorySettings),
                  accelerometer: const Stream.empty()));
          await _check(tester, '${tag}_reglages');
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
          await _check(tester, '${tag}_reglages_milieu');
          await tester.drag(find.byType(ListView), const Offset(0, -1500));
          await tester.pump();
          await _check(tester, '${tag}_reglages_langue');
        });

        testWidgets('le studio', (tester) async {
          await pump(
              tester,
              StudioPage(
                studio: ValueNotifier(const StudioInfo(
                  name: 'Nexora',
                  about: 'Un petit studio indépendant.\n\n'
                      'Des jeux courts, à jouer partout.',
                  website: 'https://tilto.fun',
                  contactUrl: 'https://tilto.fun/contact',
                )),
              ));
          await _check(tester, '${tag}_studio');
        });

        testWidgets('multijoueur : menu', (tester) async {
          await pump(
              tester,
              MultiplayerMenuScreen(
                  playerName: 'Léa', onCreate: () {}, onJoin: () {}));
          await _check(tester, '${tag}_mp_menu');
        });

        testWidgets('multijoueur : recherche', (tester) async {
          for (final (name, data) in [
            ('recherche', const JoinViewData()),
            ('aucune_partie', const JoinViewData(searching: false)),
            (
              'liste',
              const JoinViewData(games: [
                DiscoveredGameViewData(id: 'a', hostName: 'Tom'),
                DiscoveredGameViewData(
                    id: 'b', hostName: 'Inès', playerCount: 2),
              ]),
            ),
            (
              'connexion',
              const JoinViewData(
                  searching: false,
                  joiningId: 'a',
                  games: [DiscoveredGameViewData(id: 'a', hostName: 'Tom')]),
            ),
          ]) {
            await pump(tester,
                JoinScreen(data: data, onJoin: (_) {}, onRefresh: () {}));
            await tester.pump(const Duration(milliseconds: 400));
            await _check(tester, '${tag}_mp_rejoindre_$name');
          }
        });

        testWidgets('multijoueur : salon', (tester) async {
          const lea = LobbyPlayerViewData(name: 'Léa');
          for (final (name, data) in [
            ('seul', const LobbyViewData(isHost: true, me: lea)),
            (
              'arrivee',
              const LobbyViewData(
                  isHost: true,
                  me: lea,
                  other: LobbyPlayerViewData(name: 'Tom', justJoined: true)),
            ),
            (
              'autre_pret',
              const LobbyViewData(
                  isHost: false,
                  me: lea,
                  other: LobbyPlayerViewData(name: 'Tom', ready: true)),
            ),
            (
              'moi_pret',
              const LobbyViewData(
                  isHost: true,
                  me: LobbyPlayerViewData(name: 'Léa', ready: true),
                  other: LobbyPlayerViewData(name: 'Inès')),
            ),
            (
              'compte_a_rebours',
              const LobbyViewData(
                  isHost: true,
                  me: LobbyPlayerViewData(name: 'Léa', ready: true),
                  other: LobbyPlayerViewData(name: 'Tom', ready: true),
                  countdown: 3),
            ),
          ]) {
            await pump(tester,
                LobbyScreen(data: data, onReadyChanged: (_) {}, onLeave: () {}));
            await tester.pump(const Duration(milliseconds: 400));
            await _check(tester, '${tag}_mp_salon_$name');
          }
        });

        testWidgets('multijoueur : duel', (tester) async {
          await pump(tester,
              const DuelScreen(hud: _hud, field: DuelFieldData.initial));
          await _check(tester, '${tag}_mp_duel');
          await pump(
              tester,
              const DuelScreen(
                  hud: _hud,
                  field: DuelFieldData.initial,
                  point: DuelPointData(scorer: DuelSide.me, resumeIn: 2)));
          await tester.pump(const Duration(milliseconds: 400));
          await _check(tester, '${tag}_mp_duel_point');
        });

        testWidgets('multijoueur : fin du duel', (tester) async {
          for (final (name, result) in [
            ('victoire', _result(me: 5, other: 3)),
            (
              'defaite_revanche_demandee',
              _result(me: 4, other: 5, rematch: RematchState.iAsked),
            ),
            (
              'defaite_adversaire_parti',
              _result(me: 1, other: 5, rematch: RematchState.opponentLeft),
            ),
            (
              'revanche_proposee',
              _result(me: 5, other: 2, rematch: RematchState.opponentAsked),
            ),
          ]) {
            await pump(
                tester,
                DuelResultScreen(
                    result: result, onRematch: () {}, onQuit: () {}));
            await tester.pump(const Duration(milliseconds: 400));
            await _check(tester, '${tag}_mp_fin_$name');
          }
        });

        testWidgets('multijoueur : incidents', (tester) async {
          for (final incident in const [
            DuelIncident.opponentDisconnected('Tom'),
            DuelIncident.hostLeft('Tom'),
            DuelIncident.connectionLost('Tom'),
            DuelIncident.connectionFailed(),
            DuelIncident.gameFull('Inès'),
            DuelIncident.noNetwork(),
            DuelIncident.leaveDuel('Tom'),
            DuelIncident.versionMismatch(),
            DuelIncident.closedInBackground(),
          ]) {
            await pump(
                tester,
                Scaffold(
                  body: Center(
                    child: SingleChildScrollView(
                      padding: PongSpacing.screenPadding,
                      child: DuelIncidentCard(
                          incident: incident, onAction: (_) {}),
                    ),
                  ),
                ));
            await _check(tester, '${tag}_mp_incident_${incident.kind.name}');
          }
        });
      });
    }
  }
}
