import 'package:flutter/material.dart';
import 'package:pong_game/hompage.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/aide.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NamePage extends StatefulWidget {
  final String? savedPseudo;

  const NamePage({super.key, this.savedPseudo});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  bool _shakingInput = false;
  late AnimationController _controller;
  // Sons : un lecteur par son, chargé une fois à l'ouverture de l'écran
  final GameSound _winterSound = GameSound('sounds/athmopshere.mp3', loop: true);
  final GameSound _letsgoSound = GameSound('sounds/letsgo.mp3');
  final GameSound _shootSound = GameSound('sounds/shoot.mp3');
  String selectedDifficulty = 'Normal';

  // Pseudo courant (celui de Hive au lancement, puis le dernier enregistré)
  String? _pseudo;
  bool _editingPseudo = false; // true quand le joueur a tapé « Modifier »
  bool _isStarting = false; // true entre le tap sur « S U I V A N T » et le retour du jeu

  bool get _hasSavedPseudo => _pseudo != null && _pseudo!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _winterSound.play();

    _pseudo = widget.savedPseudo;
    if (_hasSavedPseudo) {
      _nameController.text = _pseudo!;
    }
  }

  void startPlaying() async {
    // Un second tap pendant le lancement n'ouvre pas une deuxième partie
    if (_isStarting) return;
    // Un pseudo vide ou fait d'espaces est refusé
    final playerName = _nameController.text.trim();
    if (playerName.isNotEmpty) {
      _isStarting = true;
      // Save pseudo to Hive
      final settingsBox = Hive.box('settings');
      settingsBox.put('pseudo', playerName);
      _nameController.text = playerName;
      setState(() {
        _pseudo = playerName;
        _editingPseudo = false;
      });

      _winterSound.stop();

      // Lecteur membre : NamePage reste dans la pile sous le jeu, le son
      // continue donc pendant la transition
      await _letsgoSound.play();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: 'Pong Game',
            playerName: playerName,
            difficulty: selectedDifficulty,
          ),
        ),
      );

      // Retour du jeu : rafraîchir le meilleur score et relancer la musique
      _isStarting = false;
      if (!mounted) return;
      setState(() {});
      _winterSound.play();
    } else {
      setState(() {
        _shakingInput = true;
      });
      _controller.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() {
          _shakingInput = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _winterSound.dispose();
    _letsgoSound.dispose();
    _shootSound.dispose();
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildDifficultyButton(String label) {
    final bool isSelected = selectedDifficulty == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDifficulty = label;
        });
        _shootSound.play();
      },
      child: FractionallySizedBox(
        widthFactor: 0.9,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Colors.pink : Colors.grey.shade900,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.6),
                      spreadRadius: 4,
                      blurRadius: 50,
                      offset: const Offset(0, 3),
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
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "P O N G",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 35,
                        fontWeight: FontWeight.w800),
                  ),

                  // Pseudo section
                  if (_hasSavedPseudo && !_editingPseudo)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            "Bonjour $_pseudo",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Action discrète : réaffiche le champ, prérempli
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _editingPseudo = true;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "Modifier",
                              style: TextStyle(
                                color: Colors.pink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ShakeTransition(
                      axis: Axis.horizontal,
                      duration: const Duration(milliseconds: 500),
                      offset: 10,
                      controller: _controller,
                      child: TextField(
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
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
                          hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w100),
                          fillColor: Colors.black,
                        ),
                        controller: _nameController,
                      ),
                    ),

                  // Difficulty selection
                  Column(
                    children: [
                      const Text(
                        "Choisis le niveau de difficulté ",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          _buildDifficultyButton('Facile'),
                          const SizedBox(height: 15),
                          _buildDifficultyButton('Normal'),
                          const SizedBox(height: 15),
                          _buildDifficultyButton('Difficile'),
                        ],
                      ),
                    ],
                  ),

                  GestureDetector(
                    onTap: startPlaying,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.pink,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.6),
                              spreadRadius: 4,
                              blurRadius: 50,
                              offset: const Offset(0, 3),
                            ),
                          ]),
                      child: const Text(
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
                    style: const TextStyle(
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.teal,
                      ),
                      child: const Text(
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

  const ShakeTransition({
    super.key,
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
