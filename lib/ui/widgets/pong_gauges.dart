// Jauges de jeu (maquette, section 06). Petites et discrètes : elles se
// lisent d'un coup d'œil sans attirer le regard loin de la balle.
//
// - `PongDotGauge` : points ronds (ex. 4 points = renvois avant la prochaine
//   accélération, orange série), avec un libellé facultatif (« VITESSE 3 »).
// - `PongBarGauge` : barres (ex. 5 barres = points du duel, bleu joueur).
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';

class PongDotGauge extends StatelessWidget {
  const PongDotGauge({
    super.key,
    required this.filled,
    this.count = 4,
    this.color = PongColors.streak,
    this.label,
  });

  /// Nombre de points pleins (0 à `count`).
  final int filled;
  final int count;
  final Color color;

  /// Libellé à droite, écrit normalement : affiché en majuscules.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Semantics(
      label: label == null ? '$filled sur $count' : '$label, $filled sur $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: i < filled ? color : PongColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
          if (label != null) ...[
            const SizedBox(width: 12),
            Text(
              label.toUpperCase(),
              style: PongText.hudLabel.copyWith(letterSpacing: 11 * 0.2),
            ),
          ],
        ],
      ),
    );
  }
}

class PongBarGauge extends StatelessWidget {
  const PongBarGauge({
    super.key,
    required this.filled,
    this.count = 5,
    this.color = PongColors.player,
  });

  final int filled;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$filled sur $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 14,
              height: 6,
              decoration: BoxDecoration(
                color: i < filled ? color : PongColors.gaugeEmpty,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
