import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pong_game/ball.dart';
import 'package:pong_game/coverscreen.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pong_game/bricks.dart';
import 'package:pong_game/hompage.dart';

class NamePage extends StatefulWidget {
  const NamePage({super.key});

  @override
  _NamePageState createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  bool _shakingInput = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  void startPlaying() {
    final playerName = _nameController.text;
    if (playerName.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: 'Pong Game',
            playerName: playerName,

          ),
        ),
      );
    } else {
      setState(() {
        _shakingInput = true;
      });
      _controller.forward(from: 0).then((_) {
        setState(() {
          _shakingInput = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: SafeArea(
        child: Center(
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.4,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    child: Text(
                      "P O N G",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 35,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  ShakeTransition(
                    axis: Axis.horizontal,
                    duration: const Duration(milliseconds: 500),
                    offset: 10,
                    controller: _controller,
                    child: Container(
                      child: TextField(
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          hintText: 'Entrez votre prénom ',
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: _shakingInput ? Colors.red : Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: _shakingInput ? Colors.red : Colors.grey),
                          ),
                          hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w100),
                          fillColor: Colors.black,
                        ),
                        controller: _nameController,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: startPlaying,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.pink,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.6),
                              spreadRadius: 4,
                              blurRadius: 50,
                              offset: Offset(0, 3), // changes position of shadow
                            ),
                          ]),
                      child: Text(
                        "S U I V A N T",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShakeTransition extends StatelessWidget {
  final AnimationController controller;
  final double offset;
  final Duration duration;
  final Axis axis;
  final Widget child;

  ShakeTransition({
    required this.controller,
    required this.child,
    this.offset = 140.0,
    this.duration = const Duration(milliseconds: 900),
    this.axis = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? child) {
        double dx = 0, dy = 0;
        if (axis == Axis.horizontal) {
          dx = offset * (1.0 - controller.value);
        } else {
          dy = offset * (100.0 - controller.value);
        }
        return Transform.translate(
          offset: Offset(dx, dy),
          child: child,
        );
      },
    );
  }
}


// import 'dart:async';

// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:pong_game/ball.dart';
// import 'package:pong_game/coverscreen.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:pong_game/bricks.dart';
// import 'package:pong_game/hompage.dart';





// class name extends StatelessWidget {
//   const name({super.key});

//   @override
//   Widget build(BuildContext context) {

 
//     final TextEditingController _nameController = TextEditingController();
//     final bool shakingInput = false;


//     void startplaying(){
//       final playerName = _nameController.text;
//       if (playerName.isNotEmpty) {
//         shakingInput == true;
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => MyHomePage(
//               title: 'Pong Game',
//             ),
//           ),
//         );
//       }
//     }
//     return Scaffold(
//       backgroundColor: Colors.black12,
//       body: SafeArea(
//         child: Center(
//           child: Container(
//             height: MediaQuery.sizeOf(context).height*0.4 ,
//             child: Padding(
//             padding: EdgeInsets.symmetric(horizontal:50),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Container(
//                   child: Text("P O N G" , style: TextStyle( color: Colors.grey , fontSize: 35 , fontWeight: FontWeight.w800),),
//                 ),
//                 Container(
//                   child: TextField(
//                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
//                     decoration: InputDecoration(
//                       contentPadding: EdgeInsets.symmetric(vertical: 10 , horizontal: 10) ,
//                       hintText: 'Entrez votre prenom ',
//                       enabledBorder: const OutlineInputBorder(
//                         borderSide: BorderSide(color: Colors.grey),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Colors.grey),
//                       ),
//                       hintStyle: TextStyle( color : Colors.grey , fontSize: 15 , fontWeight: FontWeight.w100), 
//                       fillColor: Colors.black                  
//                     ),
//                     controller: _nameController,
//                   ),
//                 ) , 
//                 GestureDetector(
//                   onTap: startplaying,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 20 , vertical: 10),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(8),
//                       color: Colors.pink,
//                       boxShadow: [
//                           BoxShadow(
//                             color: Colors.pink.withOpacity(0.6),
//                             spreadRadius: 4,
//                             blurRadius: 50,
//                             offset: Offset(0, 3), // changes position of shadow
//                           ),
//                         ]
//                     ),
//                     child: Text("S U I V A N T" ,  style: TextStyle( color: Colors.white , fontSize: 17 , fontWeight: FontWeight.bold),),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           ),
//         ),
//       ),
//     );
//   }
// }




