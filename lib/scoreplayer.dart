import 'package:flutter/material.dart';


class Scoreplayer extends StatefulWidget {

  final bool hastarted ;
  final int playerScore ;
  final String playerName ;

  const Scoreplayer({super.key , required this.hastarted , required this.playerScore , required this.playerName});

  @override
  State<Scoreplayer> createState() => _ScoreplayerState();
}

class _ScoreplayerState extends State<Scoreplayer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: const Alignment(0, 0.4),
      child:Text(widget.hastarted ? "${widget.playerName}:${widget.playerScore}" : "" , style: TextStyle(color: Colors.grey.shade600 , fontSize: 18 , fontWeight: FontWeight.bold , letterSpacing: 13 ),)
    );
    
  }
}