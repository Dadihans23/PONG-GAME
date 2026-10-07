import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pong_game/ball.dart';
import 'package:pong_game/coverscreen.dart';
import 'package:pong_game/game/pong_engine.dart';
import 'package:pong_game/game/tilt_control.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/scoreplayer.dart';
import 'package:pong_game/topscore.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pong_game/bricks.dart';
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
  // Nombre maximum de pas de moteur par image : au-delà, le temps en trop est
  // abandonné pour que la balle ne saute pas après un blocage
  static const int maxStepsPerFrame = 50;

  // Nombre de pas de moteur par seconde : règle la vitesse de tout le jeu
  // (balle, adversaire, accélération), identique sur tous les téléphones.
  // L'ancienne boucle (minuteur de 1 ms) en faisait environ 700 en release
  // sur un Samsung SM-A135F ; valeur en cours de réglage avec le propriétaire
  static const int stepsPerSecond = 450;

  // --- Réglages de la raquette, à ajuster au ressenti ---
  // L'inclinaison est normalisée : 0 = téléphone droit, 1 = téléphone couché
  // sur le côté (90°). Ces valeurs reproduisent la vitesse d'avant (0,02 par
  // événement du capteur, 6 événements par seconde sur SM-A135F).

  // Vitesse maximale de la raquette, en unités de terrain par seconde
  // (le terrain fait 2 unités de large)
  static const double paddleMaxSpeed = 1.18;

  // Inclinaison qui donne la vitesse maximale. La baisser (0,5 = 30°) rend la
  // raquette plus vive sans changer sa vitesse maximale
  static const double tiltForMaxSpeed = 1.0;

  // Zone morte : sous cette inclinaison (0,05 = environ 3°) la raquette ne
  // bouge pas ; au-delà, la vitesse part de 0 et croît linéairement
  static const double tiltDeadZone = 0.05;

  // Lissage de l'inclinaison, en secondes : plus grand = plus doux mais plus
  // de retard, 0 = aucun lissage
  static const double tiltSmoothingTime = 0.05;

  // Période de lecture de l'accéléromètre : 20 ms = 50 mesures par seconde
  static const Duration sensorPeriod = Duration(milliseconds: 20);

  // Toute la logique de jeu (balle, raquettes, score, IA) vit dans le moteur
  late final PongEngine _engine = PongEngine(difficulty: widget.difficulty);

  bool hastarted = false;
  bool isPaused = false;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // Inclinaison du téléphone → vitesse de la raquette
  final TiltControl _tilt = TiltControl(
    maxSpeed: paddleMaxSpeed,
    deadZone: tiltDeadZone,
    fullTilt: tiltForMaxSpeed,
    smoothingTime: tiltSmoothingTime,
  );

  // Boucle de jeu : stepsPerSecond pas de moteur par seconde écoulée
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero; // Temps du ticker à l'image précédente
  int _pendingSteps = 0; // Temps écoulé pas encore converti en pas, en millionièmes de pas

  // Sons : un lecteur par son, chargé une fois à l'ouverture de l'écran
  final GameSound _hitballSound = GameSound('sounds/hitball.mp3');
  final GameSound _pauseSound = GameSound('sounds/pause.mp3');
  final GameSound _backgroundSound = GameSound('sounds/background.mp3', loop: true);
  final GameSound _winSound = GameSound('sounds/win.mp3');
  final GameSound _gameoverSound = GameSound('sounds/gameover.mp3');
  bool _hasPlayedWinSound = false;
  int _initialTopScore = 0;

  double playerWidth =  80 ;
  bool glowEffect = false; // Ajoutez une variable pour le glow

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

  void _addToLeaderboard(String name, int score) {
    final box = Hive.box('leaderboard');
    List<dynamic> entries = List<dynamic>.from(box.get('entries', defaultValue: []) ?? []);
    entries.add({
      'name': name,
      'score': score,
      'date': DateTime.now().toIso8601String(),
    });
    entries.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    if (entries.length > 10) {
      entries = entries.sublist(0, 10);
    }
    box.put('entries', entries);
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

  // Appelé une fois par image tant que la partie tourne
  void _onFrame(Duration elapsed) {
    final int frameMicroseconds = (elapsed - _lastElapsed).inMicroseconds;
    _pendingSteps += frameMicroseconds * stepsPerSecond;
    _lastElapsed = elapsed;

    // Les pas entiers sont joués, le reste est gardé pour l'image suivante
    int steps = _pendingSteps ~/ 1000000;
    _pendingSteps = _pendingSteps % 1000000;
    if (steps > maxStepsPerFrame) {
      steps = maxStepsPerFrame;
    }

    _engine.paddleHalfWidth = playerWidth / MediaQuery.of(context).size.width + 0.10;

    // Raquette : l'inclinaison lissée donne une vitesse en unités par seconde,
    // que le moteur applique à chaque pas. Le ticker ne tourne que pendant une
    // partie en cours : la raquette ne bouge donc ni avant le premier tap, ni
    // en pause, ni après la défaite
    _engine.playerSpeed = _tilt.update(frameMicroseconds / 1000000) / stepsPerSecond;

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

    // Un seul rafraîchissement par image
    setState(() {});
  }

  void _handleEvent(PongEvent event) {
    switch (event) {
      case PongEvent.playerHit:
        // Vibration haptique
        HapticFeedback.lightImpact();

        // Son de contact paddle
        _hitballSound.play();

        glowEffect = true; // Activez le glow effect lorsque le score change
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            glowEffect = false; // Désactivez le glow effect après une seconde
          });
        });

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
        // Une partie terminée à 0 point n'entre pas au classement
        if (_engine.playerScore > 0) {
          _addToLeaderboard(widget.playerName, _engine.playerScore);
        }
        _gameoverSound.play();
        _showdialog();
        break;
    }
  }

  void _checkTopScore() {
    // Vérifier et mettre à jour le meilleur score
    if (_engine.playerScore > topscore) {
      topscore = _engine.playerScore;
      saveTopScore(topscore);
    }
    // Jouer le son win quand le joueur dépasse son ancien meilleur score
    if (!_hasPlayedWinSound && _engine.playerScore > _initialTopScore && _initialTopScore > 0) {
      _hasPlayedWinSound = true;
      _winSound.play();
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


void _showdialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.grey.shade100,
         shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.0),
        ),
        actionsAlignment: MainAxisAlignment.center,
        title: Center(
          child: Text("Vous avez eu ${_engine.playerScore}" , style: const TextStyle(color: Colors.black , fontSize: 14, fontWeight:FontWeight.w700),),
        ),
        actions: <Widget>[
          GestureDetector(
            onTap: (){
              Navigator.of(context).pop();
            } ,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.blueAccent.shade700,
                child: const Text("Rejouer" , style: TextStyle(color: Colors.white , fontSize: 14, fontWeight:FontWeight.w700),),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: (){
              Navigator.of(context).pop();
              Navigator.push(
                this.context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardPage(),
                ),
              );
            } ,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.pink,
                child: const Text("Classement" , style: TextStyle(color: Colors.white , fontSize: 14, fontWeight:FontWeight.w700),),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: (){
              Navigator.of(context).pop();
              Navigator.push(
                this.context,
                MaterialPageRoute(
                  builder: (context) => const StatisticsPage(),
                ),
              );
            } ,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.deepPurple,
                child: const Text("Statistiques" , style: TextStyle(color: Colors.white , fontSize: 14, fontWeight:FontWeight.w700),),
              ),
            ),
          ),
        ],
      );
    },
  ).then((_) {
    // Réinitialisation unique, quel que soit le moyen de fermer le dialogue
    // (bouton, retour Android, tap à l'extérieur)
    if (mounted) {
      resetgame();
    }
  });
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
    _hasPlayedWinSound = false;
    _initialTopScore = topscore;
    });
   }


  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    loadTopScore();

  // Le capteur ne déplace rien : il mémorise la dernière inclinaison, que la
  // boucle de jeu lit à chaque image
  _accelSubscription = accelerometerEventStream(samplingPeriod: sensorPeriod).listen(
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

    return GestureDetector(
      onTap: isPaused ? null : startGame,
      child: Scaffold(
        backgroundColor: Colors.black12,
        body: Center(
          child:Stack(
            children: [
              coverScreen(
                hastarted: hastarted,
              ),
            // ScoreGlow(score: , glowEffect: glowEffect) ,
              Scoreplayer(
                hastarted: hastarted,
                playerScore: _engine.playerScore,
                playerName: widget.playerName,

              ) ,
               topScore(
                hastarted: hastarted,
                topscore: topscore,
              ) ,

              myBricks(
                x: _engine.enemyX,
                y: -0.9,
                iscomputer: true,
                playerWidth :playerWidth ,
              ),
               myBricks(
                x: _engine.playerX,
                y: 0.9,
                iscomputer: false,
                playerWidth :playerWidth ,

              ) ,


              myBall(x: _engine.ballX, y: _engine.ballY , hastarted: hastarted,),

              // Bouton pause
              if (hastarted)
                Positioned(
                  top: 40,
                  right: 20,
                  child: GestureDetector(
                    onTap: togglePause,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),

              // Overlay pause
              if (isPaused)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "PAUSE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: togglePause,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.pink,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withOpacity(0.6),
                                  spreadRadius: 4,
                                  blurRadius: 50,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              "R E P R E N D R E",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),


            ],
          )
        )

      ),
    );
  }
}
