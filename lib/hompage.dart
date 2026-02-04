import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pong_game/ball.dart';
import 'package:pong_game/coverscreen.dart';
import 'package:pong_game/scoreplayer.dart';
import 'package:pong_game/topscore.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pong_game/bricks.dart';
import 'package:pong_game/scoreglow.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/leaderboard.dart';
import 'package:pong_game/statistics.dart';
import 'package:audioplayers/audioplayers.dart';





class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.playerName, required this.difficulty});

  final String title;
  final String playerName;
  final String difficulty;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
enum direction { UP , DOWN , LEFT , RIGHT}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool hastarted = false;
  double ballSpeedX = 0.002;
  double ballSpeedY = 0.002;
  final Random _random = Random();
  double _enemyOffset = 0.0;
  bool isPaused = false;
  Timer? _gameTimer;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // Audio players
  final AudioPlayer _hitballPlayer = AudioPlayer();
  final AudioPlayer _pausePlayer = AudioPlayer();
  final AudioPlayer _backgroundPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _losePlayer = AudioPlayer();
  final AudioPlayer _gameoverPlayer = AudioPlayer();
  bool _hasPlayedWinSound = false;
  int _initialTopScore = 0;

  double playerWidth =  80 ;
  double playerX= 0;
  double enemyX= 0;
  double deadZone = 0.8; // Ignore les micro-mouvements sous ce seuil
  double sensitivity = 0.02; // Facteur de sensibilité du mouvement
  int playerScore = 0;
  bool ballChangedDirection= false;
  bool glowEffect = false; // Ajoutez une variable pour le glow

  int hitsCounter = 0; // Compteur pour le nombre de fois que le joueur renvoie la balle

  int topscore= 0 ;

  // Statistics
  int _currentStreak = 0;
  final Stopwatch _playTimeStopwatch = Stopwatch();

  // ball variables
  double ballX = 0.0;
  double ballY = 0.0;

  var ballYDirection = direction.DOWN ;
  var ballXDirection = direction.LEFT ;


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
    if (_currentStreak > bestStreak) {
      box.put('bestStreak', _currentStreak);
    }
  }
  
  void startGame(){
    if(hastarted) {
    }
    else{
      hastarted = true;
      _playTimeStopwatch.start();
      _gameTimer = Timer.periodic(Duration(milliseconds : 1), (timer) {
          if (!isPaused) {
            moveEnemy();
            updateDirection() ;
            moveBall();
            if (isplayerdead()){
              timer.cancel();
              _gameTimer = null;
              _playTimeStopwatch.stop();
              _saveStats();
              _addToLeaderboard(widget.playerName, playerScore);
              _gameoverPlayer.play(AssetSource('sounds/gameover.mp3'));
              _showdialog();
            };
          }
      });
    }
  }

  void togglePause() {
    if (!hastarted) return;
    setState(() {
      isPaused = !isPaused;
    });
    if (isPaused) {
      _playTimeStopwatch.stop();
      // Son de pause + musique de fond en boucle
      _pausePlayer.play(AssetSource('sounds/pause.mp3'));
      _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
      _backgroundPlayer.play(AssetSource('sounds/background.mp3'));
    } else {
      _playTimeStopwatch.start();
      // Arrêter la musique de fond quand on reprend
      _backgroundPlayer.stop();
    }
  }
 

void _showdialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return PopScope(
        onPopInvoked: (popMode) {
          resetgame();
          return  ; // Ferme la boîte de dialogue
        },
        child: AlertDialog(
          backgroundColor: Colors.grey.shade100,
           shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          actionsAlignment: MainAxisAlignment.center,
          title: Center(
            child: Text("Vous avez eu ${playerScore}" , style: TextStyle(color: Colors.black , fontSize: 14, fontWeight:FontWeight.w700),),
          ),
          actions: <Widget>[
            GestureDetector(
              onTap: (){
                Navigator.of(context).pop();
                resetgame();
              } ,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.all(10),
                  color: Colors.blueAccent.shade700,
                  child: Text("Rejouer" , style: TextStyle(color: Colors.white , fontSize: 14, fontWeight:FontWeight.w700),),
                ),
              ),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: (){
                Navigator.of(context).pop();
                resetgame();
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
                  padding: EdgeInsets.all(10),
                  color: Colors.pink,
                  child: Text("Classement" , style: TextStyle(color: Colors.white , fontSize: 14, fontWeight:FontWeight.w700),),
                ),
              ),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: (){
                Navigator.of(context).pop();
                resetgame();
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
                  padding: EdgeInsets.all(10),
                  color: Colors.deepPurple,
                  child: Text("Statistiques" , style: TextStyle(color: Colors.white , fontSize: 14, fontWeight:FontWeight.w700),),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
  bool isplayerdead() {
     if (ballY >=1){
      return true ;
     }
     
     return false;
  }





  void moveEnemy() {
    setState(() {
      double targetX = ballX + _enemyOffset;

      if (widget.difficulty == 'Facile') {
        // Slow speed, large random offset that changes occasionally
        double maxSpeed = 0.01;
        if (_random.nextInt(60) == 0) {
          _enemyOffset = (_random.nextDouble() - 0.5) * 0.6;
        }
        double diff = targetX - enemyX;
        if (diff.abs() > maxSpeed) {
          enemyX += diff > 0 ? maxSpeed : -maxSpeed;
        } else {
          enemyX = targetX;
        }
      } else if (widget.difficulty == 'Normal') {
        // Medium speed, small random offset
        double maxSpeed = 0.03;
        if (_random.nextInt(40) == 0) {
          _enemyOffset = (_random.nextDouble() - 0.5) * 0.3;
        }
        double diff = targetX - enemyX;
        if (diff.abs() > maxSpeed) {
          enemyX += diff > 0 ? maxSpeed : -maxSpeed;
        } else {
          enemyX = targetX;
        }
      } else {
        // Difficile: near-perfect tracking with tiny offset
        double maxSpeed = 0.05;
        if (_random.nextInt(100) == 0) {
          _enemyOffset = (_random.nextDouble() - 0.5) * 0.08;
        }
        double diff = targetX - enemyX;
        if (diff.abs() > maxSpeed) {
          enemyX += diff > 0 ? maxSpeed : -maxSpeed;
        } else {
          enemyX = targetX;
        }
      }

      enemyX = enemyX.clamp(-1.0, 1.0);
    });
  }


   void resetgame(){
    _gameTimer?.cancel();
    _gameTimer = null;
    _backgroundPlayer.stop();
    _playTimeStopwatch.stop();
    _playTimeStopwatch.reset();
    setState(() {
    hastarted = false;
    isPaused = false;
    ballX = 0.0;
    ballY = 0.0;
    playerScore = 0 ;
    hitsCounter = 0 ;
    ballXDirection = direction.LEFT ;
    ballSpeedX = 0.002;
    ballSpeedY = 0.002;
    playerX= 0 ;
    _enemyOffset = 0.0;
    _hasPlayedWinSound = false;
    _initialTopScore = topscore;
    _currentStreak = 0;
    });
   }
void updateDirection() {
    setState(() {
      double paddleHalfWidth = playerWidth / MediaQuery.of(context).size.width + 0.10;
      double x1 = playerX - paddleHalfWidth;
      double x2 = playerX + paddleHalfWidth;

      // update vertical direction — use wider zone to prevent ball skipping past paddle at high speed
      if (ballY >= 0.85 && ballYDirection == direction.DOWN && ballX >= x1 && ballX <= x2) {
        if (!ballChangedDirection) {
          ballYDirection = direction.UP;
          playerScore += 50; // Incrémenter le score du joueur de 50
          ballChangedDirection = true;

          // Vibration haptique
          HapticFeedback.lightImpact();

          // Rebond angulaire basé sur la position de l'impact
          double hitOffset = (ballX - playerX) / paddleHalfWidth; // -1 à 1
          ballSpeedX = hitOffset.abs() * ballSpeedY * 1.5;
          if (hitOffset > 0) {
            ballXDirection = direction.RIGHT;
          } else if (hitOffset < 0) {
            ballXDirection = direction.LEFT;
          }

          // Son de contact paddle
          _hitballPlayer.stop();
          _hitballPlayer.play(AssetSource('sounds/hitball.mp3'));

          glowEffect = true; // Activez le glow effect lorsque le score change
          Future.delayed(Duration(seconds: 1), () {
            setState(() {
              glowEffect = false; // Désactivez le glow effect après une seconde
            });
          });

          _currentStreak++;
          hitsCounter++ ;
          if (hitsCounter > 3){
            ballSpeedY += 0.0005; // Augmenter la vitesse de la balle
            hitsCounter = 0; // Reset le compteur de renvois
          }


          // Vérifier et mettre à jour le meilleur score
          if (playerScore > topscore) {
            topscore = playerScore;
            saveTopScore(topscore);
          }
          // Jouer le son win quand le joueur dépasse son ancien meilleur score
          if (!_hasPlayedWinSound && playerScore > _initialTopScore && _initialTopScore > 0) {
            _hasPlayedWinSound = true;
            _winPlayer.play(AssetSource('sounds/win.mp3'));
          }
        }
      } else if (ballY <= -0.85 && ballYDirection == direction.UP) {
        // Check if enemy paddle is aligned with ball
        double enemyHalfWidth = playerWidth / MediaQuery.of(context).size.width + 0.10;
        double enemyX1 = enemyX - enemyHalfWidth;
        double enemyX2 = enemyX + enemyHalfWidth;

        if (ballX >= enemyX1 && ballX <= enemyX2) {
          // Enemy catches it, ball bounces back down
          ballYDirection = direction.DOWN;

          // Rebond angulaire pour le paddle ennemi
          double hitOffset = (ballX - enemyX) / enemyHalfWidth;
          ballSpeedX = hitOffset.abs() * ballSpeedY * 1.5;
          if (hitOffset > 0) {
            ballXDirection = direction.RIGHT;
          } else if (hitOffset < 0) {
            ballXDirection = direction.LEFT;
          }

          // Son de contact paddle ennemi
          _hitballPlayer.stop();
          _hitballPlayer.play(AssetSource('sounds/hitball.mp3'));
        } else {
          // Enemy missed! Player scores, reset ball
          playerScore += 100;
          if (playerScore > topscore) {
            topscore = playerScore;
            saveTopScore(topscore);
          }
          // Jouer le son win quand le joueur dépasse son ancien meilleur score
          if (!_hasPlayedWinSound && playerScore > _initialTopScore && _initialTopScore > 0) {
            _hasPlayedWinSound = true;
            _winPlayer.play(AssetSource('sounds/win.mp3'));
          }
          ballX = 0.0;
          ballY = 0.0;
          ballSpeedX = 0.002;
          ballYDirection = direction.DOWN;
          _enemyOffset = 0.0;
        }
      } else {
        ballChangedDirection = false; // Reset when the ball is not hitting the player's paddle
      }

      // update horizontal direction
      if (ballX >= 1) {
        ballXDirection = direction.LEFT;
      } else if (ballX <= -1) {
        ballXDirection = direction.RIGHT;
      }
    });
  }

  void moveBall(){
     setState(() {
      // update vertical move
      if(ballYDirection == direction.DOWN){
        ballY += ballSpeedY;
      }else if (ballYDirection == direction.UP){
        ballY -= ballSpeedY;
      }

      // update horizontal move
      if(ballXDirection == direction.RIGHT){
        ballX += ballSpeedX;
      }else if (ballXDirection == direction.LEFT){
        ballX -= ballSpeedX;
      }

      // Clamp ball position to prevent skipping past paddles
      ballY = ballY.clamp(-1.0, 1.0);
      ballX = ballX.clamp(-1.0, 1.0);
     });
  }


  @override
  void initState() {
    super.initState();
    loadTopScore();

  _accelSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
    setState(() {
      double tilt = -event.x;

      // Zone morte : ignorer les micro-vibrations
      if (tilt.abs() < deadZone) {
        return;
      }

      // Mouvement proportionnel à l'inclinaison
      double movement = tilt * sensitivity;
      playerX += movement;
      playerX = playerX.clamp(-1.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _hitballPlayer.dispose();
    _pausePlayer.dispose();
    _backgroundPlayer.dispose();
    _winPlayer.dispose();
    _losePlayer.dispose();
    _gameoverPlayer.dispose();
    _gameTimer?.cancel();
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
                playerScore: playerScore,
                playerName: widget.playerName,

              ) ,
               topScore(
                hastarted: hastarted,
                topscore: topscore,
              ) ,
              
              myBricks(
                x: enemyX,
                y: -0.9,
                iscomputer: true,
                playerWidth :playerWidth ,
              ),
               myBricks( 
                x: playerX,
                y: 0.9,
                iscomputer: false,
                playerWidth :playerWidth ,

              ) ,
            
      
              myBall(x: ballX, y: ballY , hastarted: false,),

              // Bouton pause
              if (hastarted)
                Positioned(
                  top: 40,
                  right: 20,
                  child: GestureDetector(
                    onTap: togglePause,
                    child: Container(
                      padding: EdgeInsets.all(8),
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
                        Text(
                          "PAUSE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 30),
                        GestureDetector(
                          onTap: togglePause,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.pink,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withOpacity(0.6),
                                  spreadRadius: 4,
                                  blurRadius: 50,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
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