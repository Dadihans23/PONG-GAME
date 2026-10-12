import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/entername.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/studio/studio_repository.dart';
import 'package:pong_game/ui/pong_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Le jeu est vertical : verrouillage en portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Hive.initFlutter();
  await Hive.openBox<int>('scores');
  await Hive.openBox('settings');
  await Hive.openBox('leaderboard');
  await Hive.openBox('stats');
  await Hive.openBox(StudioRepository.boxName);

  // Réglages du son appliqués avant le premier son (chargement)
  final settings = PongSettings();
  GameSound.musicEnabled = settings.musicEnabled;
  GameSound.effectsEnabled = settings.soundEffectsEnabled;

  // Langue choisie dans les Réglages (par défaut, celle du téléphone)
  AppLanguageSetting.current.value = settings.language;

  // Migration one-time : ancien topscore vers leaderboard
  final scoresBox = Hive.box<int>('scores');
  final leaderboardBox = Hive.box('leaderboard');
  final oldTopScore = scoresBox.get('topscore', defaultValue: 0) ?? 0;
  if (oldTopScore > 0 && !leaderboardBox.containsKey('migrated')) {
    List<dynamic> entries = List<dynamic>.from(leaderboardBox.get('entries', defaultValue: []) ?? []);
    entries.add({
      'name': 'Joueur',
      'score': oldTopScore,
      'date': DateTime.now().toIso8601String(),
    });
    leaderboardBox.put('entries', entries);
    leaderboardBox.put('migrated', true);
  }

  // Studio : le cache tout de suite, puis le site en arrière-plan (au plus
  // une fois par 24 h, ou au lancement qui suit un changement de langue),
  // sans retarder le chargement. La présentation est demandée dans la
  // langue de l'app.
  final studio = StudioRepository(
    Hive.box(StudioRepository.boxName),
    language: effectiveLanguageCode(
        settings.language,
        WidgetsBinding.instance.platformDispatcher.locales),
  )..loadCache();
  unawaited(studio.refreshIfDue());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home = const SplashScreen()});

  /// Premier écran (les tests en passent un autre).
  final Widget home;

  @override
  Widget build(BuildContext context) {
    // Un changement de langue dans les Réglages reconstruit l'app : tous les
    // écrans ouverts passent à la nouvelle langue, sans redémarrer.
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLanguageSetting.current,
      builder: (context, language, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: Brand.gameName,
        theme: PongTheme.dark(),
        themeMode: ThemeMode.dark,
        // `null` (Automatique) : la langue du téléphone, suivie en direct
        locale: language.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // fr, en ou es selon le téléphone, quel que soit le pays ; sinon
        // l'anglais
        localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
        // Chargement, puis accueil
        home: home,
      ),
    );
  }
}

/// Écran de chargement (maquette S1), premier écran de l'app : 4,5 s avec
/// `loader.mp3`, puis l'accueil. La balle qui pulse annonce le jeu ; la
/// barre rose porte le seul halo de l'écran.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Durée du chargement. Le jingle `loader.mp3` dure lui aussi environ
  /// 4,5 s : il démarre et finit avec la barre.
  static const Duration duration = Duration(milliseconds: 4500);

  /// Durée totale à ne pas dépasser, du lancement à l'accueil : le
  /// chargement seul (l'intro du studio a été retirée).
  static const Duration startupBudget = duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: SplashScreen.duration);

  /// Pulsation de la balle, en boucle pendant le chargement.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  // Jingle de chargement : coupé avec la musique
  final GameSound _loaderSound =
      GameSound('sounds/loader.mp3', category: SoundCategory.music);

  @override
  void initState() {
    super.initState();
    _loaderSound.play();
    _controller.addStatusListener(_onStatus);
    _controller.forward();
    _pulse.repeat(reverse: true);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _loaderSound.stop();
    final settingsBox = Hive.box('settings');
    final savedPseudo = settingsBox.get('pseudo') as String?;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NamePage(savedPseudo: savedPseudo),
      ),
    );
  }

  @override
  void dispose() {
    _loaderSound.dispose();
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: PongColors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: PongSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingBall(animation: reduceMotion ? null : _pulse),
              const SizedBox(height: 40),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: PongLogo(fontSize: 48),
              ),
              const SizedBox(height: 56),
              SizedBox(
                width: 200,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      _LoadingBar(progress: _controller.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Balle blanche avec son halo ; elle « respire » si [animation] est donnée.
class _PulsingBall extends StatelessWidget {
  const _PulsingBall({required this.animation});

  final Animation<double>? animation;

  static const Widget _ball = SizedBox.square(
    dimension: PongSizes.ball,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: PongColors.ball,
        shape: BoxShape.circle,
        boxShadow: PongShadows.ball,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final animation = this.animation;
    if (animation == null) return _ball;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: _ball,
    );
  }
}

/// Barre fine rose + « Chargement… » et le pourcentage.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress});

  /// Avancement, de 0 à 1.
  final double progress;

  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toInt();
    final l10n = context.l10n;
    return Semantics(
      label: l10n.splashLoadingLabel,
      value: '$percent${PongFormat.nbsp}%',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: _height,
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              color: PongColors.surfaceDisabled,
              borderRadius: BorderRadius.all(Radius.circular(_height / 2)),
            ),
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PongColors.pink,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(_height / 2)),
                  boxShadow:
                      PongShadows.glow(PongColors.pink, opacity: 0.9, blur: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: PongSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(l10n.splashLoading, style: PongText.caption),
              ),
              Text(
                '$percent${PongFormat.nbsp}%',
                style: PongText.figure.copyWith(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
