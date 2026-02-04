import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pong_game/ball.dart';
import 'package:pong_game/coverscreen.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pong_game/bricks.dart';
import 'package:pong_game/hompage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pong_game/leaderboard.dart';
import 'package:pong_game/aide.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NamePage extends StatefulWidget {
  final String? savedPseudo;

  const NamePage({super.key, this.savedPseudo});

  @override
  _NamePageState createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  bool _shakingInput = false;
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _winterPlayer = AudioPlayer();
  String selectedDifficulty = 'Normal';

  bool get _hasSavedPseudo => widget.savedPseudo != null && widget.savedPseudo!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _playWelcomeSound();
    _playWinterMusic();

    if (_hasSavedPseudo) {
      _nameController.text = widget.savedPseudo!;
    }
  }

  Future<void> _playWelcomeSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/welcome.mp3'));
    } catch (e) {
      print('Welcome sound error: $e');
    }
  }

  Future<void> _playWinterMusic() async {
    try {
      await _winterPlayer.setReleaseMode(ReleaseMode.loop);
      await _winterPlayer.play(AssetSource('sounds/athmopshere.mp3'));
    } catch (e) {
      print('Winter music error: $e');
    }
  }

  void startPlaying() async {
    final playerName = _nameController.text;
    if (playerName.isNotEmpty) {
      // Save pseudo to Hive
      final settingsBox = Hive.box('settings');
      settingsBox.put('pseudo', playerName);

      _winterPlayer.stop();

      try {
        final letsgoPlayer = AudioPlayer();
        await letsgoPlayer.play(AssetSource('sounds/letsgo.mp3'));
      } catch (e) {
        print('Letsgo sound error: $e');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: 'Pong Game',
            playerName: playerName,
            difficulty: selectedDifficulty,
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
    _audioPlayer.dispose();
    _winterPlayer.stop();
    _winterPlayer.dispose();
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _playShootSound() async {
    try {
      final shootPlayer = AudioPlayer();
      await shootPlayer.play(AssetSource('sounds/shoot.mp3'));
    } catch (e) {
      print('Shoot sound error: $e');
    }
  }

  Widget _buildDifficultyButton(String label) {
    final bool isSelected = selectedDifficulty == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDifficulty = label;
        });
        _playShootSound();
      },
      child: FractionallySizedBox(
        widthFactor: 0.9,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Colors.pink : Colors.grey.shade900,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.6),
                      spreadRadius: 4,
                      blurRadius: 50,
                      offset: Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 17,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: SafeArea(
        child: Center(
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.75,
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

                  // Pseudo section
                  if (_hasSavedPseudo)
                    Text(
                      "Bonjour ${widget.savedPseudo}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
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
                            hintText: 'Entrez votre pseudo ',
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

                  // Difficulty selection
                  Column(
                    children: [
                      Text(
                        "Choisis le niveau de difficulté ",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Column(
                        children: [
                          _buildDifficultyButton('Facile'),
                          SizedBox(height: 15),
                          _buildDifficultyButton('Normal'),
                          SizedBox(height: 15),
                          _buildDifficultyButton('Difficile'),
                        ],
                      ),
                    ],
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
                              offset: Offset(0, 3),
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
                  Text(
                    "Meilleur score : ${Hive.box<int>('scores').get('topscore', defaultValue: 0)}",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AidePage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.teal,
                      ),
                      child: Text(
                        "A I D E",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
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
