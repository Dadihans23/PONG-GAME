// Cartes et éléments de contenu (maquette, section 05).
//
// - `PongCard` : conteneur de base, surface opaque #15151C, bordure 1 px.
//   Bordure colorée (`borderColor`) réservée au podium.
// - `PongListRow` : ligne de liste (classement, parties trouvées).
// - `PongStatCard` : carte statistique icône + libellé + chiffre clé.
// - `PongFigureTile` : petite tuile chiffre + libellé (récap fin de partie).
// - `PongIconBadge` : icône dans une pastille teintée (cartes, dialogues).
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';
import 'pong_pressable.dart';

/// Carte de base. Avec `onTap`, elle devient tactile (ondulation, 48 px min).
class PongCard extends StatelessWidget {
  const PongCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PongSpacing.md),
    this.borderColor,
    this.onTap,
    this.borderRadius = PongRadii.cardAll,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Bordure colorée 1,5 px (podium uniquement) ; sinon bordure discrète.
  final Color? borderColor;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  BoxDecoration get _decoration => BoxDecoration(
        color: PongColors.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? PongColors.borderSubtle,
          width: borderColor == null ? 1 : 1.5,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: _decoration,
        child: child,
      );
    }
    return PongPressable(
      onTap: onTap,
      width: double.infinity,
      pressedScale: 0.985,
      borderRadius: borderRadius,
      padding: padding,
      alignment: Alignment.centerLeft,
      decoration: _decoration,
      child: child,
    );
  }
}

/// Ligne de liste : [leading] · titre / sous-titre · valeur ou [trailing].
///
/// ```dart
/// PongListRow(
///   leading: const Icon(Icons.emoji_events_rounded, color: PongColors.gold),
///   title: 'Léa',
///   subtitle: '12/09/2026',
///   value: '2 650',
///   borderColor: PongColors.podium(1),
/// )
/// ```
class PongListRow extends StatelessWidget {
  const PongListRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.borderColor,
    this.onTap,
  });

  final String title;

  /// Élément de gauche (icône, rang), centré dans 32 px.
  final Widget? leading;
  final String? subtitle;

  /// Valeur à droite, en chiffres tabulaires (score).
  final String? value;

  /// Élément de droite à la place de `value` (ex. `PongCompactButton`).
  final Widget? trailing;

  /// Bordure colorée (podium) : `PongColors.podium(rang)`.
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final subtitle = this.subtitle;
    final value = this.value;
    final trailing = this.trailing;
    return PongCard(
      padding: const EdgeInsets.symmetric(
          horizontal: PongSpacing.md, vertical: PongSpacing.sm),
      borderColor: borderColor,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 32, child: Center(child: leading)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PongText.cardTitle.copyWith(fontSize: 16),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PongText.caption.copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: PongSpacing.sm),
              Text(value, style: PongText.listValue),
            ],
            if (trailing != null) ...[
              const SizedBox(width: PongSpacing.sm),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte statistique : icône colorée, libellé, chiffre clé de la même couleur.
class PongStatCard extends StatelessWidget {
  const PongStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = PongColors.textPrimary,
  });

  final IconData icon;
  final String label;

  /// Valeur affichée telle quelle (« 23 renvois », « 1h 12min »).
  final String value;

  /// Couleur de donnée : `PongColors.streak`, `data`, `record`…
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PongCard(
      child: Semantics(
        container: true,
        label: '$label : $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 10),
            Text(label, style: PongText.caption.copyWith(fontWeight: FontWeight.w400)),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: PongText.keyFigure.copyWith(fontSize: 28, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petite tuile chiffre + libellé, fond surface haute, rayon 12.
/// Se place dans une `Row`, chaque tuile dans un `Expanded`.
class PongFigureTile extends StatelessWidget {
  const PongFigureTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        color: PongColors.surfaceHigh,
        borderRadius: PongRadii.segmentAll,
      ),
      child: Semantics(
        label: '$label : $value',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: PongText.figure),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PongText.caption.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Icône dans une pastille teintée. Par défaut 44 px, rayon 12, fond = la
/// couleur à 12 %. `circular: true` pour la pastille ronde des dialogues.
class PongIconBadge extends StatelessWidget {
  const PongIconBadge({
    super.key,
    required this.icon,
    this.color = PongColors.pinkLight,
    this.background,
    this.size = 44,
    this.iconSize = 24,
    this.circular = false,
  });

  final IconData icon;
  final Color color;

  /// Fond ; par défaut `color` à 12 %.
  final Color? background;
  final double size;
  final double iconSize;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? PongColors.alpha(color, 0.12),
        borderRadius: BorderRadius.circular(circular ? size / 2 : 12),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
