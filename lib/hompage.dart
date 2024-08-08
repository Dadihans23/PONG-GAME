import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pong_game/ball.dart';
import 'package:pong_game/coverscreen.dart';
import 'package:pong_game/scoreplayer.dart';
import 'package:pong_game/topscore.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pong_game/bricks.dart';
import 'package:pong_game/scoreglow.dart';
import 'package:hive_flutter/hive_flutter.dart';





class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title , required this.playerName});

  final String title;
  final String playerName ; 

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
enum direction { UP , DOWN , LEFT , RIGHT}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  double paddlePosition = 0;
  bool hastarted = false;
  double ballSpeed = 0.0025;

  double playerWidth =  80 ;
  double playerX= 0;
  double enemyX= 0;
  double centeringFactor = 20; // Facteur de recentrage
  int playerScore = 0;
  bool ballChangedDirection= false;
  bool glowEffect = false; // Ajoutez une variable pour le glow

  int hitsCounter = 0; // Compteur pour le nombre de fois que le joueur renvoie la balle

  int topscore= 1000 ;

  // ball variables
  double ballX = 0.0;
  double ballY = 0.0;

  var ballYDirection = direction.DOWN ;
  var ballXDirection = direction.LEFT ;


  Future<void> loadTopScore() async {
    final box = Hive.box<int>('scores');
    setState(() {
      topscore = box.get('topscore', defaultValue: topscore)!;
    });
  }

  Future<void> saveTopScore(int newTopScore) async {
    final box = Hive.box<int>('scores');
    box.put('topscore', newTopScore);
  }
  
  void startGame(){
    if(hastarted) {
    }
    else{
      hastarted = true;
      Timer.periodic(Duration(milliseconds : 1), (timer) { 
          moveEnemy();
          updateDirection() ;
          moveBall(); 
          if (isplayerdead()){
            timer.cancel();
            _showdialog();
            
          };   
      });
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
            )
         
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





  void moveEnemy(){
    setState(() {
      enemyX = ballX ;
    });
  }


   void resetgame(){
    setState(() {
    paddlePosition = 0;
    hastarted = false;
    ballX = 0.0;
    ballY = 0.0;
    playerScore = 0 ;
    hitsCounter = 0 ;
    ballXDirection = direction.LEFT ;
    ballSpeed = 0.002;
    playerX= 0 ;


    });
   }
void updateDirection() {
    setState(() {
      double x1 = playerX - playerWidth / MediaQuery.of(context).size.width - 0.10;
      double x2 = playerX + playerWidth / MediaQuery.of(context).size.width + 0.10;

      // update vertical direction
      if (ballY >= 0.9 && ballX >= x1 && ballX <= x2) {
        if (!ballChangedDirection) {
          ballYDirection = direction.UP;
          playerScore += 50; // Incrémenter le score du joueur de 50
          ballChangedDirection = true;

          glowEffect = true; // Activez le glow effect lorsque le score change
          Future.delayed(Duration(seconds: 1), () {
            setState(() {
              glowEffect = false; // Désactivez le glow effect après une seconde
            });
          });

          hitsCounter++ ;
          if (hitsCounter > 3){
            ballSpeed += 0.0005; // Augmenter la vitesse de la balle
            hitsCounter = 0; // Reset le compteur de renvois
          }


          // Vérifier et mettre à jour le meilleur score
          if (playerScore > topscore) {
            topscore = playerScore;
            saveTopScore(topscore);
          }
        }
      } else if (ballY <= -0.9) {
        ballYDirection = direction.DOWN;
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
        ballY += ballSpeed;
      }else if (ballYDirection == direction.UP){
        ballY -= ballSpeed;
        
      }

      // update horizontal move
      if(ballXDirection == direction.RIGHT){
        ballX += ballSpeed;
      }else if (ballXDirection == direction.LEFT){
        ballX -= ballSpeed;
      }

      // print(ballX) ;
     }); 
  }


  @override
  void initState() {
    super.initState();

  accelerometerEvents.listen((AccelerometerEvent event) {
    setState(() {
      paddlePosition -= event.x * 1 ; // Ajustez le facteur de multiplication pour ajuster la sensibilité10
      paddlePosition = paddlePosition.clamp(-1, 1.0); // Limite les mouvements de la brique

      if (paddlePosition > 0) {
       
              playerX += 0.095;
              playerX = playerX.clamp(-1.0, 1.0); // Limite les mouvements de playerX         
                
        }
        else {
              playerX -= 0.095;
              playerX = playerX.clamp(-1.0, 1.0); // Limite les mouvements de playerX
        }


         // Recentrage progressif
        if (paddlePosition.abs() < centeringFactor) {
          paddlePosition = 0;
        } else if (paddlePosition > 0) {
          paddlePosition -= centeringFactor;
        } else {
          paddlePosition += centeringFactor;
        }

        playerX = playerX.clamp(-1.0, 1.0); // Limite les mouvements de playerX

      });
    });
  }

  @override
  
  Widget build(BuildContext context) {
   
    return GestureDetector(
      onTap: startGame,
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
            
      
              myBall(x: ballX, y: ballY , hastarted: false,)
        
              
              // Container(
              //   alignment: Alignment(paddlePosition /80 ,  0.9 ),
              //   child: Container(
              //     height: 15,
              //     width: 80,
              //     decoration: BoxDecoration(
              //       color: Colors.blue,
              //       borderRadius: BorderRadius.only(
              //         topLeft: Radius.circular(10),
              //         topRight: Radius.circular(10),
              //         bottomLeft: Radius.circular(10),
              //         bottomRight: Radius.circular(10),
              //       ),
              //     ),
      
              //   ),
              // ),
      
            
           
      
              // Positioned(
              //   bottom: 50,
              //   left: MediaQuery.of(context).size.width / 2 + paddlePosition,
              //   child: Container(
              //     width: 100,
              //     height: 20,
              //     color: Colors.blue,
              //   ),
              // ), 
              
            ],
          ) 
        )
        
      ),
    );
  }
}