// Pastilles 28 px (maquette, section 06) : même gabarit, la couleur porte
// le sens.
//
// - `PongPill.signal` : annonce en jeu ou en fin de partie, majuscules
//   espacées, contour 50 % + fond 12 % (« NOUVEAU RECORD », « POINT POUR LÉA »).
// - `PongPill.status` : état calme, sans contour (« Prêt », « En attente »).
//   Sans couleur, la pastille est neutre (gris sur surface haute).
//
// ```dart
// const PongPill.signal(label: 'Nouveau record', color: PongColors.record, icon: Icons.star_rounded)
// const PongPill.signal(label: 'Point pour Léa', color: PongColors.player, textColor: PongColors.playerLight)
// const PongPill.status(label: 'Prêt', color: PongColors.success, icon: Icons.check_rounded)
// const PongPill.status(label: 'En attente', icon: Icons.hourglass_top_rounded)
// ```
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';

class PongPill extends StatelessWidget {
  const PongPill.signal({
    super.key,
    required this.label,
    required Color this.color,
    this.textColor,
    this.icon,
  }) : _signal = true;

  const PongPill.status({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
  }) : _signal = false;

  /// Libellé, écrit normalement ; une pastille-signal le passe en majuscules.
  final String label;

  /// Couleur de sens (`record`, `player`, `bonus`, `success`…) ;
  /// `null` (statut seulement) = neutre.
  final Color? color;

  /// Couleur du texte et de l'icône, si plus claire que `color` est
  /// nécessaire pour la lisibilité (`playerLight`, `bonusLight`).
  final Color? textColor;
  final IconData? icon;
  final bool _signal;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    final icon = this.icon;
    final Color fg = textColor ?? color ?? PongColors.textSecondary;
    final Color bg = color == null
        ? PongColors.surfaceHigh
        : PongColors.alpha(color, _signal ? 0.12 : 0.14);
    final style = (_signal ? PongText.pillLabel : PongText.statusLabel)
        .copyWith(color: fg);
    return Container(
      height: PongSizes.pill,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PongSizes.pill / 2),
        border: _signal && color != null
            ? Border.all(color: PongColors.alpha(color, 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
          ],
          Text(_signal ? label.toUpperCase() : label,
              maxLines: 1, style: style),
        ],
      ),
    );
  }
}
