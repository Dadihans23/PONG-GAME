// Interrupteurs (écran Réglages).
//
// - `PongSwitch` : l'interrupteur seul. Activé = règle de sélection du kit
//   (contour rose + teinte, jamais le rose plein) et une coche dans le
//   bouton, pour ne pas dépendre de la couleur seule.
// - `PongSwitchRow` : ligne entière tactile (≥ 56 px) : pastille d'icône ·
//   titre / sous-titre · interrupteur. Se pose dans une `PongCard` sans
//   marge intérieure, plusieurs lignes séparées par `PongCardDivider`.
//
// ```dart
// PongSwitchRow(
//   icon: Icons.vibration_rounded,
//   title: 'Vibration',
//   subtitle: 'Au renvoi et à la fin de partie',
//   value: _vibration,
//   onChanged: (v) => setState(() => _vibration = v),
// )
// ```
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';
import 'pong_cards.dart';
import 'pong_pressable.dart';

class PongSwitch extends StatelessWidget {
  const PongSwitch({super.key, required this.value, required this.onChanged});

  final bool value;

  /// `null` = désactivé.
  final ValueChanged<bool>? onChanged;

  static Color _track(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return PongColors.surfaceDisabled;
    return states.contains(WidgetState.selected)
        ? PongColors.pinkTintSolid
        : PongColors.surfaceHigh;
  }

  static Color _outline(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return PongColors.borderSubtle;
    return states.contains(WidgetState.selected)
        ? PongColors.pink
        : PongColors.border;
  }

  static Color _thumb(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return PongColors.textDisabled;
    return states.contains(WidgetState.selected)
        ? PongColors.pinkLight
        : PongColors.textTertiary;
  }

  static Icon? _thumbIcon(Set<WidgetState> states) =>
      states.contains(WidgetState.selected)
          ? const Icon(Icons.check_rounded, color: PongColors.pinkTintSolid)
          : null;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      trackColor: WidgetStateProperty.resolveWith(_track),
      trackOutlineColor: WidgetStateProperty.resolveWith(_outline),
      trackOutlineWidth: const WidgetStatePropertyAll(1.5),
      thumbColor: WidgetStateProperty.resolveWith(_thumb),
      thumbIcon: WidgetStateProperty.resolveWith(_thumbIcon),
      overlayColor: WidgetStatePropertyAll(PongColors.alpha(PongColors.pink, 0.12)),
    );
  }
}

/// Ligne de réglage avec interrupteur ; toute la ligne bascule la valeur.
class PongSwitchRow extends StatelessWidget {
  const PongSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;

  /// Une courte phrase qui dit ce que le réglage touche.
  final String? subtitle;
  final bool value;

  /// `null` = désactivé.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final subtitle = this.subtitle;
    final enabled = onChanged != null;
    return MergeSemantics(
      child: PongPressable(
        onTap: onChanged == null ? null : () => onChanged(!value),
        width: double.infinity,
        minHeight: 56,
        pressedScale: 1,
        borderRadius: PongRadii.cardAll,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.fromLTRB(
            PongSpacing.md, PongSpacing.sm, PongSpacing.sm, PongSpacing.sm),
        child: Row(
          children: [
            PongIconBadge(
              icon: icon,
              size: 40,
              iconSize: 22,
              color: !enabled
                  ? PongColors.textDisabled
                  : value
                      ? PongColors.pinkLight
                      : PongColors.textSecondary,
              background: value && enabled
                  ? PongColors.pinkBadge
                  : PongColors.surfaceHigh,
            ),
            const SizedBox(width: PongSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: PongText.cardTitle.copyWith(
                      fontSize: 16,
                      color: enabled
                          ? PongColors.textPrimary
                          : PongColors.textDisabled,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: PongText.caption.copyWith(
                            fontSize: 12, fontWeight: FontWeight.w400)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: PongSpacing.xs),
            PongSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Filet entre deux lignes d'une même carte, aligné sur le texte.
class PongCardDivider extends StatelessWidget {
  const PongCardDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: PongSpacing.md + 40 + PongSpacing.sm,
      color: PongColors.borderSubtle,
    );
  }
}
