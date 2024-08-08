import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';

class ScoreGlow extends StatelessWidget {
  final int score;
  final bool glowEffect; // Indicateur si le glow est activé ou non

  const ScoreGlow({
    super.key,
    required this.score,
    required this.glowEffect,
  });

  @override
  Widget build(BuildContext context) {
    return glowEffect
        ? AvatarGlow(
            duration: Duration(seconds: 1), // Durée de l'effet glow
            glowColor: Colors.white, // Couleur du glow
            child: Material(
              elevation: 8.0, // Élève l'avatar pour ajouter une ombre
              shape: CircleBorder(),
              child: Container(
                padding: EdgeInsets.all(1),
                decoration: BoxDecoration(shape: BoxShape.circle , color: Colors.black),
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
        : Container(
            padding: EdgeInsets.all(10),
            color: Colors.black,
            child: Text(
              '$score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
  }
}
