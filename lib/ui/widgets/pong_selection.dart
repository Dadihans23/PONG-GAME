// Sélection : contour rose + teinte 16 % + petit halo, jamais le rose plein
// (réservé au bouton principal).
//
// - `PongSelectableButton` : un choix parmi quelques-uns, 48 px.
// - `PongSegmentedControl` : rangée de `PongSelectableButton` dans un rail
//   (choix de la difficulté Facile / Normal / Difficile).
// - `PongChoiceCard` : grande carte de choix avec pastille d'icône, titre,
//   sous-titre et coche (Solo / Multijoueur). Peut contenir un `child`
//   affiché sous la ligne (ex. les segments de difficulté de la carte Solo).
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';
import 'pong_cards.dart';
import 'pong_pressable.dart';

/// Bouton sélectionnable 48 px, rayon 12.
class PongSelectableButton extends StatelessWidget {
  const PongSelectableButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;

  /// `null` = désactivé.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final Color textColor = !enabled
        ? PongColors.textDisabled
        : selected
            ? Colors.white
            : PongColors.textSecondary;
    return PongPressable(
      onTap: onPressed,
      selected: selected,
      height: PongSizes.touchTarget,
      width: double.infinity,
      borderRadius: PongRadii.segmentAll,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.xs),
      decoration: BoxDecoration(
        color: selected
            ? PongColors.pinkTintSolid
            : enabled
                ? PongColors.surfaceHigh
                : PongColors.surfaceDisabled,
        border: Border.all(
          color: selected ? PongColors.pink : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: selected && enabled ? PongShadows.selected : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: PongText.segmentLabel.copyWith(
            color: textColor,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Rail de segments : fond #0B0B10, padding 6, rayon 16, bordure #1E1E28.
///
/// ```dart
/// PongSegmentedControl<String>(
///   values: const ['Facile', 'Normal', 'Difficile'],
///   selected: _difficulty,
///   onChanged: (v) => setState(() => _difficulty = v),
/// )
/// ```
class PongSegmentedControl<T> extends StatelessWidget {
  const PongSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.labelOf,
  });

  final List<T> values;
  final T selected;

  /// `null` = tout le rail est désactivé.
  final ValueChanged<T>? onChanged;

  /// Libellé d'une valeur (défaut : `toString()`).
  final String Function(T value)? labelOf;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: PongColors.background,
        borderRadius: PongRadii.buttonAll,
        border: Border.fromBorderSide(BorderSide(color: PongColors.surfaceHigh)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: PongSpacing.xs),
            Expanded(
              child: PongSelectableButton(
                label: labelOf?.call(values[i]) ?? values[i].toString(),
                selected: values[i] == selected,
                onPressed:
                    onChanged == null ? null : () => onChanged(values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte de choix : rayon 18, padding 16. Sélectionnée : fond rose 8 %,
/// contour rose 1,5 px, halo, coche rose. Sinon : surface + rond vide.
class PongChoiceCard extends StatelessWidget {
  const PongChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;

  /// `null` = désactivé (choix indisponible).
  final VoidCallback? onTap;

  /// Contenu facultatif sous la ligne principale (affiché tel quel).
  final Widget? child;

  /// Élément de droite à la place de la coche (ex. pastille « Bientôt »
  /// sur un mode indisponible).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final subtitle = this.subtitle;
    final child = this.child;
    final trailing = this.trailing;
    return PongPressable(
      onTap: onTap,
      selected: selected,
      width: double.infinity,
      pressedScale: 0.985,
      borderRadius: PongRadii.choiceCardAll,
      padding: const EdgeInsets.all(PongSpacing.md),
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: selected ? PongColors.pinkTintSoftSolid : PongColors.surface,
        border: Border.all(
          color: selected ? PongColors.pink : PongColors.borderSubtle,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected ? PongShadows.selectedCard : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PongIconBadge(
                icon: icon,
                color: selected
                    ? PongColors.pinkLight
                    : enabled
                        ? PongColors.textSecondary
                        : PongColors.textDisabled,
                background:
                    selected ? PongColors.pinkBadge : PongColors.surfaceHigh,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: PongText.cardTitle.copyWith(
                        color: enabled
                            ? PongColors.textPrimary
                            : PongColors.textDisabled,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: PongText.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: PongSpacing.xs),
              trailing ??
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 24,
                    color: selected
                        ? PongColors.pinkLight
                        : PongColors.textDisabled,
                  ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}
