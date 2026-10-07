import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';

class myBall extends StatefulWidget {
  final double x;
  final double y;
  final bool hastarted;

  const myBall({
    super.key,
    required this.x,
    required this.y,
    required this.hastarted,
  });

  @override
  State<myBall> createState() => _ballState();
}

class _ballState extends State<myBall> {
  @override
  Widget build(BuildContext context) {
    return widget.hastarted 
        ? Container(
            alignment: Alignment(widget.x, widget.y),
            child: Container(
              height: 20,
              width: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          )
        : Container(
            alignment: Alignment(widget.x, widget.y),
            child: AvatarGlow(
              child: Material(
                elevation: 24.0,
                shape: const CircleBorder(),
                child: Container(
                  height: 20,
                  width: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
  }
}
