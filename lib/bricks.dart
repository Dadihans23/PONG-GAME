import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class myBricks extends StatefulWidget {
  
  final double x;
  final double y;
  final bool iscomputer;
  final double playerWidth;

  const myBricks({
    super.key,
    required this.x,
    required this.y,
    required this.iscomputer,
    required this.playerWidth ,
  });

  @override
  State<myBricks> createState() => _myBricksState();
}

class _myBricksState extends State<myBricks> {
  @override
  Widget build(BuildContext context) {
    return Container(
              alignment: Alignment(widget.x, widget.y),
              child: Container(
                height:15,
                width: widget.playerWidth,
                decoration: BoxDecoration(
                  color: widget.iscomputer ? Colors.green : Colors.blue ,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            );
  }
}