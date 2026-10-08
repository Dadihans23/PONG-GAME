import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pong_game/game/game_tuning.dart';
import 'package:pong_game/game/leaderboard_rules.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';
import 'package:pong_game/game/pong_engine.dart';
import 'package:pong_game/game/tilt_control.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/game_ui/game_court.dart';
import 'package:pong_game/game_ui/game_hud.dart';
import 'package:pong_game/game_ui/game_over_card.dart';
import 'package:pong_game/game_ui/pause_overlay.dart';
import 'package:pong_game/ui/pong_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/leaderboard.dart';
import 'package:pong_game/statistics.dart';





class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.playerName, required this.difficulty});

  final String title;
  final String playerName;
  final String difficulty;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  // Rythme du jeu (pas de moteur par seconde, rattrapage plafonné) et
  // réglages de la raquette : `GameTuning`, communs au solo et au duel.
  // Valeurs réglées au ressenti avec le propriétaire sur un vrai téléphone

  // --- Effets visuels, mesurés en temps de jeu (figés pendant la pause) ---
  // Flash de la raquette et « +50 » qui monte, au renvoi
  static const Duration paddleFlashDuration = Duration(milliseconds: 180);
  static const Duration scorePopupDuration = Duration(milliseconds: 700);
  // Terrain et score à l'or quand le record tombe, puis retour au blanc
  static const Duration recordGoldHold = Duration(milliseconds: 1200);
  static const Duration recordGoldFade = Duration(milliseconds: 300);

  // Toute la logique de jeu (balle, raquettes, score, IA) vit dans le moteur
  late final PongEngine _engine = PongEngine(difficulty: widget.difficulty);

  // Réglages du joueur, lus une fois : ils ne changent pas pendant une partie
  final PongSettings _settings = PongSettings();

  bool hastarted = false;
  bool isPaused = false;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // Inclinaison du téléphone → vitesse de la raquette, selon la sensibilité
  // du joueur (0 à 100)
  late final TiltControl _tilt =
      PaddleSensitivity.tiltControl(_settings.paddleSensitivity);

  // Boucle de jeu : GameTuning.stepsPerSecond pas de moteur par seconde écoulée
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero; // Temps du ticker à l'image précédente
  int _pendingSteps = 0; // Temps écoulé pas encore converti en pas, en millionièmes de pas

  // Horloge des effets : temps de jeu écoulé depuis le début de la partie
  Duration _gameTime = Duration.zero;
  Duration? _lastHitTime; // Dernier renvoi du joueur
  double _lastHitX = 0; // Position de la raquette à ce renvoi
  Duration? _recordTime; // Moment où le record est tombé

  // Sons : un lecteur par son, chargé une fois à l'ouverture de l'écran
  final GameSound _hitballSound = GameSound('sounds/hitball.mp3');
  final GameSound _pauseSound = GameSound('sounds/pause.mp3');
  final GameSound _backgroundSound = GameSound('sounds/background.mp3', loop: true);
  final GameSound _winSound = GameSound('sounds/win.mp3');
  final GameSound _gameoverSound = GameSound('sounds/gameover.mp3');

  // Le record d'avant la partie a été battu (son, or, pastille, carte de fin)
  bool _recordBeaten = false;
  int _initialTopScore = 0;

  int topscore= 0 ;

  // Statistics
  final Stopwatch _playTimeStopwatch = Stopwatch();


  Future<void> loadTopScore() async {
    final box = Hive.box<int>('scores');
    setState(() {
      topscore = box.get('topscore', defaultValue: 0)!;
      _initialTopScore = topscore;
    });
  }

  Future<void> saveTopScore(int newTopScore) async {
    final box = Hive.box<int>('scores');
    box.put('topscore', newTopScore);
  }

  // Ajoute la partie au classement et retourne son rang (null hors du top 10)
  int? _addToLeaderboard(String name, int score) {
    final box = Hive.box('leaderboard');
    final result = insertLeaderboardEntry(
      List<dynamic>.from(box.get('entries', defaultValue: []) ?? []),
      {
        'name': name,
        'score': score,
        'date': DateTime.now().toIso8601String(),
      },
    );
    box.put('entries', result.entries);
    return result.rank;
  }

  void _saveStats() {
    final box = Hive.box('stats');
    final totalGames = (box.get('totalGames', defaultValue: 0) as int) + 1;
    final totalPlayTimeMs = (box.get('totalPlayTimeMs', defaultValue: 0) as int) + _playTimeStopwatch.elapsedMilliseconds;
    final bestStreak = box.get('bestStreak', defaultValue: 0) as int;
    box.put('totalGames', totalGames);
    box.put('totalPlayTimeMs', totalPlayTimeMs);
    if (_engine.currentStreak > bestStreak) {
      box.put('bestStreak', _engine.currentStreak);
    }
  }

  void startGame(){
    if(hastarted) {
    }
    else{
      hastarted = true;
      _playTimeStopwatch.start();
      _startTicker();
    }
  }

  // Le ticker repart de zéro à chaque démarrage : aucun temps accumulé
  // pendant la pause ou avant la partie n'est rattrapé
  void _startTicker() {
    _lastElapsed = Duration.zero;
    // Le lissage repart de l'inclinaison actuelle du téléphone
    _tilt.reset();
    _ticker.start();
  }

  // Largeur du terrain en pixels : l'écran moins les marges du terrain. Les
  // coordonnées du moteur (-1 à 1) couvrent le terrain, pas tout l'écran
  double _courtWidth() {
    return MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        2 * GameCourt.sideMargin;
  }

  // Appelé une fois par image tant que la partie tourne
  void _onFrame(Duration elapsed) {
    final int frameMicroseconds = (elapsed - _lastElapsed).inMicroseconds;
    _pendingSteps += frameMicroseconds * GameTuning.stepsPerSecond;
    _lastElapsed = elapsed;
    _gameTime += Duration(microseconds: frameMicroseconds);

    // Les pas entiers sont joués, le reste est gardé pour l'image suivante
    int steps = _pendingSteps ~/ 1000000;
    _pendingSteps = _pendingSteps % 1000000;
    if (steps > GameTuning.maxStepsPerFrame) {
      steps = GameTuning.maxStepsPerFrame;
    }

    _engine.paddleHalfWidth = PongSizes.paddleWidth / _courtWidth() + 0.10;

    // Raquette : l'inclinaison lissée donne une vitesse en unités par seconde,
    // que le moteur applique à chaque pas. Le ticker ne tourne que pendant une
    // partie en cours : la raquette ne bouge donc ni avant le premier tap, ni
    // en pause, ni après la défaite
    _engine.playerSpeed = _tilt.update(frameMicroseconds / 1000000) / GameTuning.stepsPerSecond;

    for (int i = 0; i < steps; i++) {
      final events = _engine.tick();
      for (final event in events) {
        _handleEvent(event);
      }
      // Partie perdue : les pas restants de l'image ne sont pas joués
      if (events.contains(PongEvent.playerDead)) {
        break;
      }
    }

    // Un seul rafraîchissement par image : les effets (flash, « +50 », or)
    // sont calculés à partir de _gameTime pendant ce même rafraîchissement
    setState(() {});
  }

  void _handleEvent(PongEvent event) {
    switch (event) {
      case PongEvent.playerHit:
        // Vibration haptique
        if (_settings.vibrationEnabled) HapticFeedback.lightImpact();

        // Son de contact paddle
        _hitballSound.play();

        // Flash de la raquette et « +50 »
        _lastHitTime = _gameTime;
        _lastHitX = _engine.playerX;

        _checkTopScore();
        break;
      case PongEvent.enemyHit:
        // Son de contact paddle ennemi
        _hitballSound.play();
        break;
      case PongEvent.enemyMissed:
        _checkTopScore();
        break;
      case PongEvent.playerDead:
        _ticker.stop();
        _playTimeStopwatch.stop();
        _saveStats();
        // Le record n'est enregistré qu'en fin de partie : une partie quittée
        // ne compte pas
        if (topscore > _initialTopScore) {
          saveTopScore(topscore);
        }
        // Une partie terminée à 0 point n'entre pas au classement
        int? rank;
        if (_engine.playerScore > 0) {
          rank = _addToLeaderboard(widget.playerName, _engine.playerScore);
        }
        _gameoverSound.play();
        _showGameOver(GameSummary(
          score: _engine.playerScore,
          previousRecord: _initialTopScore,
          isNewRecord: _recordBeaten,
          hits: _engine.currentStreak,
          duration: _playTimeStopwatch.elapsed,
          maxSpeed: _engine.speedLevel,
          rank: rank,
        ));
        break;
    }
  }

  void _checkTopScore() {
    // Meilleur score affiché, enregistré à la fin de la partie
    if (_engine.playerScore > topscore) {
      topscore = _engine.playerScore;
    }
    // Le joueur dépasse son ancien meilleur score : son, vibration longue et
    // passage à l'or, une seule fois par partie
    if (!_recordBeaten && _engine.playerScore > _initialTopScore && _initialTopScore > 0) {
      _recordBeaten = true;
      _recordTime = _gameTime;
      _winSound.play();
      if (_settings.vibrationEnabled) HapticFeedback.vibrate();
    }
  }

  void togglePause() {
    // Pas de pause avant le démarrage ni après la défaite
    if (!hastarted || _engine.isPlayerDead) return;
    setState(() {
      isPaused = !isPaused;
    });
    if (isPaused) {
      // Ticker arrêté : le temps de jeu ne s'accumule pas pendant la pause
      _ticker.stop();
      _playTimeStopwatch.stop();
      // Son de pause + musique de fond en boucle
      _pauseSound.play();
      _backgroundSound.play();
    } else {
      _startTicker();
      _playTimeStopwatch.start();
      // Arrêter la musique de fond quand on reprend
      _backgroundSound.stop();
    }
  }

  // « Quitter la partie » depuis la pause : retour à l'accueil. La partie est
  // abandonnée : ni statistiques, ni classement, ni record enregistrés
  void _quitGame() {
    _ticker.stop();
    _playTimeStopwatch.stop();
    _backgroundSound.stop();
    Navigator.of(context).pop();
  }

  Future<void> _showGameOver(GameSummary summary) async {
    final GameOverAction? action = await showPongDialog<GameOverAction>(
      context: context,
      builder: (dialogContext) => SingleChildScrollView(
        child: GameOverCard(
          summary: summary,
          onAction: (action) => Navigator.of(dialogContext).pop(action),
        ),
      ),
    );
    if (!mounted) return;

    // Réinitialisation unique, quel que soit le moyen de fermer le dialogue
    // (bouton ou retour Android)
    resetgame();

    switch (action) {
      case GameOverAction.leaderboard:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeaderboardPage()),
        );
        break;
      case GameOverAction.statistics:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StatisticsPage()),
        );
        break;
      case GameOverAction.home:
        Navigator.of(context).pop();
        break;
      case GameOverAction.replay:
      case null:
        break;
    }
  }


   void resetgame(){
    _ticker.stop();
    _pendingSteps = 0;
    _backgroundSound.stop();
    _playTimeStopwatch.stop();
    _playTimeStopwatch.reset();
    setState(() {
    hastarted = false;
    isPaused = false;
    _engine.reset();
    _recordBeaten = false;
    _initialTopScore = topscore;
    _gameTime = Duration.zero;
    _lastHitTime = null;
    _recordTime = null;
    });
   }

  // Effets du terrain à l'instant de jeu courant
  CourtEffects _courtEffects() {
    double gold = 0;
    final recordTime = _recordTime;
    if (recordTime != null) {
      final Duration since = _gameTime - recordTime;
      if (since < recordGoldHold) {
        gold = 1;
      } else if (since < recordGoldHold + recordGoldFade) {
        gold = 1 - (since - recordGoldHold).inMicroseconds / recordGoldFade.inMicroseconds;
      }
    }

    bool paddleFlash = false;
    double? popupProgress;
    final hitTime = _lastHitTime;
    if (hitTime != null) {
      final Duration since = _gameTime - hitTime;
      paddleFlash = since < paddleFlashDuration;
      if (since < scorePopupDuration) {
        popupProgress = since.inMicroseconds / scorePopupDuration.inMicroseconds;
      }
    }

    return CourtEffects(
      gold: gold,
      paddleFlash: paddleFlash,
      popupProgress: popupProgress,
      popupX: _lastHitX,
    );
  }


  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    loadTopScore();

  // Le capteur ne déplace rien : il mémorise la dernière inclinaison, que la
  // boucle de jeu lit à chaque image
  _accelSubscription = accelerometerEventStream(samplingPeriod: GameTuning.sensorPeriod).listen(
    (AccelerometerEvent event) {
      _tilt.setAcceleration(event.x, event.y, event.z);
    },
    onError: (Object e) {
      debugPrint('Accéléromètre indisponible : $e');
    },
  );
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _hitballSound.dispose();
    _pauseSound.dispose();
    _backgroundSound.dispose();
    _winSound.dispose();
    _gameoverSound.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override

  Widget build(BuildContext context) {
    final bool dead = _engine.isPlayerDead;

    return GestureDetector(
      onTap: isPaused ? null : startGame,
      child: Scaffold(
        backgroundColor: PongColors.background,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // HUD au-dessus du terrain : il ne recouvre jamais le jeu
                  GameHud(
                    hasStarted: hastarted,
                    difficulty: widget.difficulty,
                    speedLevel: _engine.speedLevel,
                    hitsSinceSpeedUp: _engine.hitsSinceSpeedUp,
                    hitsPerSpeedUp: PongEngine.hitsPerSpeedUp,
                    onPause: hastarted && !isPaused && !dead ? togglePause : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(GameCourt.sideMargin, 0,
                          GameCourt.sideMargin, GameCourt.bottomMargin),
                      child: GameCourt(
                        engine: _engine,
                        hasStarted: hastarted,
                        isLive: hastarted && !isPaused && !dead,
                        playerName: widget.playerName,
                        // Record d'avant la partie : il ne suit pas le score
                        record: _initialTopScore,
                        recordBeaten: _recordBeaten,
                        effects: _courtEffects(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Voile de pause
            if (isPaused)
              Positioned.fill(
                child: PauseOverlay(
                  score: _engine.playerScore,
                  record: topscore,
                  onResume: togglePause,
                  onQuit: _quitGame,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
