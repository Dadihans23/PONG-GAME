import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Bande de HUD de 72 px au-dessus du terrain (maquette G1, G2) : rien n'y
/// recouvre la raquette adverse.
///
/// - Avant le début : le mode (« SOLO · NORMAL »).
/// - En partie : la jauge de vitesse, qui se remplit d'un point par renvoi et
///   annonce la prochaine accélération (« VITESSE 3 »).
/// - À droite : le bouton pause, inactif tant que la partie n'a pas commencé.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.hasStarted,
    required this.difficulty,
    required this.speedLevel,
    required this.hitsSinceSpeedUp,
    required this.hitsPerSpeedUp,
    required this.onPause,
  });

  /// Hauteur de la bande, retirée du terrain.
  static const double height = 72;

  final bool hasStarted;
  final String difficulty;
  final int speedLevel;
  final int hitsSinceSpeedUp;
  final int hitsPerSpeedUp;

  /// `null` : bouton inactif (avant le début, après la défaite).
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(
            left: PongSpacing.screen, right: PongSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: hasStarted
                    ? PongDotGauge(
                        filled: hitsSinceSpeedUp,
                        count: hitsPerSpeedUp,
                        label: 'Vitesse $speedLevel',
                      )
                    : Text(
                        'SOLO · ${difficulty.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PongText.overline,
                      ),
              ),
            ),
            PongIconButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              filled: true,
              onPressed: onPause,
            ),
          ],
        ),
      ),
    );
  }
}
