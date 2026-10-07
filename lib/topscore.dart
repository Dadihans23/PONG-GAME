import 'package:flutter/material.dart';


class topScore extends StatefulWidget {

  final bool hastarted ;
  final int topscore ;

  const topScore({super.key , required this.hastarted  , required this.topscore});

  @override
  State<topScore> createState() => _topScoreState();
}

class _topScoreState extends State<topScore> {
  @override
  Widget build(BuildContext context) {
    return  Container(
        alignment: const Alignment(0, -0.4),
        child:Text(widget.hastarted ? "top score:${widget.topscore}" : "" , style: TextStyle(color: Colors.grey.shade600 , fontSize: 18 , fontWeight: FontWeight.bold ,letterSpacing: 13 ),)
      );
    
    
  }
}