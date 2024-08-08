// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:pong_game/ball.dart';
// import 'package:pong_game/coverscreen.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:pong_game/bricks.dart';



// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
// enum direction { UP , DOWN}
// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;
//   double paddlePosition = 0;
//   bool hastarted = false;

//   // ball variables
//   double ballX = 0.0;
//   double ballY = 0.0;

//   var ballDirection = direction.DOWN ;

//   void startGame(){
//     hastarted = true;
//     print("debutez ");
//     Timer.periodic(Duration(milliseconds: 2), (timer) { 
//       setState(() {
//         ballY += 0.01;
//         // updateDirection() ;
        
//         // print(paddlePosition);
//       });

//     });
//   }
//   void updateDirection (){
//     setState(() {
//       if( ballY <= -0.9){
//         ballDirection == direction.DOWN ;
//       } else if(ballY >= 0.9){
//         ballDirection == direction.UP ;
//       }
//     });
//   }

//   void moveBall(){
//     setState(() {
//       if(ballDirection == direction.DOWN){
//         ballY -= 0.01;
//       }else if (ballDirection == direction.UP){
//         ballY += 0.01;
//       }
//     });
//   }


//   @override
//   void initState() {
//     super.initState();

//     accelerometerEvents.listen((AccelerometerEvent event) {
//       setState(() {
//         paddlePosition -= event.x * 0.05 ; // Ajustez le facteur de multiplication pour ajuster la sensibilité10
//         paddlePosition = paddlePosition.clamp(-1, 1.0); // Limite les mouvements de la brique
//       });
//     });
//   }

//   @override
  
//   Widget build(BuildContext context) {
   
//     return GestureDetector(
//       onTap: startGame,
//       child: Scaffold(
//         backgroundColor: Colors.black12,
       
//         body: Center(
//           child:Stack(
//             children: [
              
//               coverScreen(
//                 hastarted: hastarted,
//               ),
      
//               myBricks(
//                 x: 0,
//                 y: -0.9,
//                 iscomputer: true,
//               ),
      
//                myBricks(
//                 x: paddlePosition,
//                 y: 0.9,
//                 iscomputer: false,

//               ) ,
      
//               myBall(x: 0, y: ballY)
        
              
//               // Container(
//               //   alignment: Alignment(paddlePosition /80 ,  0.9 ),
//               //   child: Container(
//               //     height: 15,
//               //     width: 80,
//               //     decoration: BoxDecoration(
//               //       color: Colors.blue,
//               //       borderRadius: BorderRadius.only(
//               //         topLeft: Radius.circular(10),
//               //         topRight: Radius.circular(10),
//               //         bottomLeft: Radius.circular(10),
//               //         bottomRight: Radius.circular(10),
//               //       ),
//               //     ),
      
//               //   ),
//               // ),
      
            
           
      
//               // Positioned(
//               //   bottom: 50,
//               //   left: MediaQuery.of(context).size.width / 2 + paddlePosition,
//               //   child: Container(
//               //     width: 100,
//               //     height: 20,
//               //     color: Colors.blue,
//               //   ),
//               // ), 
              
//             ],
//           ) 
//         )
        
//       ),
//     );
//   }
// }