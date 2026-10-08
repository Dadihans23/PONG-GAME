// Boutons — une seule famille (maquette, section 04).
//
// | Composant             | Usage                                                        |
// |-----------------------|--------------------------------------------------------------|
// | `PongPrimaryButton`   | L'action principale de l'écran. UN SEUL par écran, en bas.   |
// | `PongSecondaryButton` | Actions de second rang (Classement, Statistiques…).          |
// | `PongTextButton`      | Sortie ou lien discret (« Retour à l'accueil », « Modifier »). |
// | `PongIconButton`      | Icône seule 48 × 48 (retour, pause, réglages).               |
// | `PongCompactButton`   | Action de ligne dans une liste (« Rejoindre »), rose sans halo. |
// | `PongTileButton`      | Tuile d'accès icône + mot (rangée de 3 sous « Jouer »).      |
// | `PongPendingButton`   | Action principale lancée, en attente de l'autre joueur.      |
//
// Règle d'or : le rose plein avec halo (`PongPrimaryButton`) est réservé à
// l'action principale, une seule par écran. Une sélection utilise le contour
// rose (`PongSelectableButton`), jamais le remplissage.
//
// Tous : `onPressed: null` = désactivé. Un bouton principal désactivé doit
// être accompagné d'une phrase qui dit pourquoi.
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';
import 'pong_pressable.dart';

/// Contenu icône + libellé, réduit si la police système est très grande.
class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.style,
    this.icon,
    this.iconSize = 20,
    this.gap = 10,
    this.compensateSpacing = false,
  });

  final String label;
  final TextStyle style;
  final IconData? icon;
  final double iconSize;
  final double gap;
  final bool compensateSpacing;

  @override
  Widget build(BuildContext context) {
    final spacing = compensateSpacing ? (style.letterSpacing ?? 0) : 0.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: style.color),
            SizedBox(width: gap),
          ],
          Padding(
            // Compense l'espacement ajouté après la dernière lettre.
            padding: EdgeInsets.only(left: icon == null ? spacing : 0),
            child: Text(label, style: style, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal : 56 px, rayon 16, rose plein + halo, libellé en
/// majuscules espacées. Un seul par écran.
class PongPrimaryButton extends StatelessWidget {
  const PongPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  /// Libellé, écrit normalement (« Jouer ») : affiché en majuscules.
  final String label;

  /// `null` = désactivé (gris, sans halo).
  final VoidCallback? onPressed;

  /// Icône facultative avant le libellé (ex. `Icons.replay_rounded`).
  final IconData? icon;

  /// Prend toute la largeur disponible (défaut) ou s'ajuste au libellé.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PongPressable(
      onTap: onPressed,
      height: PongSizes.primaryButton,
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.lg),
      decoration: BoxDecoration(
        color: enabled ? PongColors.pink : PongColors.surfaceDisabled,
        boxShadow: enabled ? PongShadows.primaryButton : null,
      ),
      child: _ButtonContent(
        label: label.toUpperCase(),
        icon: icon,
        iconSize: 22,
        gap: 8,
        compensateSpacing: true,
        style: PongText.buttonLabel.copyWith(
          color: enabled ? Colors.white : PongColors.textDisabled,
        ),
      ),
    );
  }
}

/// Bouton secondaire : surface haute + bordure 1 px, 56 px (ou 48 px en
/// `compact`, par exemple deux boutons côte à côte dans un dialogue).
class PongSecondaryButton extends StatelessWidget {
  const PongSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 48 px, rayon 14, texte 14 au lieu de 56 px, rayon 16, texte 15.
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PongPressable(
      onTap: onPressed,
      height: compact ? PongSizes.touchTarget : PongSizes.primaryButton,
      width: expanded ? double.infinity : null,
      borderRadius: compact ? PongRadii.fieldAll : PongRadii.buttonAll,
      padding: EdgeInsets.symmetric(
          horizontal: compact ? PongSpacing.sm : PongSpacing.lg),
      decoration: BoxDecoration(
        color: enabled ? PongColors.surfaceHigh : PongColors.surfaceDisabled,
        border: Border.all(
            color: enabled ? PongColors.border : PongColors.borderSubtle),
      ),
      child: _ButtonContent(
        label: label,
        icon: icon,
        iconSize: compact ? 18 : 20,
        gap: compact ? 6 : 10,
        style: PongText.buttonLabelPlain.copyWith(
          fontSize: compact ? 14 : 15,
          color: enabled ? PongColors.textPrimary : PongColors.textDisabled,
        ),
      ),
    );
  }
}

/// Bouton texte : sans fond, zone tactile 48 px. Pour les sorties
/// (« Retour à l'accueil ») ou un lien rose (`color: PongColors.pinkLight`).
class PongTextButton extends StatelessWidget {
  const PongTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = PongColors.textBody,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Couleur du texte : gris clair par défaut, `PongColors.pinkLight` pour
  /// un lien.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PongPressable(
      onTap: onPressed,
      borderRadius: PongRadii.fieldAll,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.sm),
      child: _ButtonContent(
        label: label,
        icon: icon,
        iconSize: 18,
        gap: 6,
        style: PongText.buttonLabelPlain
            .copyWith(color: enabled ? color : PongColors.textDisabled),
      ),
    );
  }
}

/// Bouton icône 48 × 48, rayon 14. `filled` lui donne un fond sombre
/// semi-opaque (bouton pause au-dessus du terrain).
class PongIconButton extends StatelessWidget {
  const PongIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Nom de l'action, lu par le lecteur d'écran et affiché à l'appui long
  /// (« Retour », « Pause »).
  final String tooltip;
  final bool filled;

  /// Couleur de l'icône (défaut : blanc cassé, ou gris clair si `filled`).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final iconColor = !enabled
        ? PongColors.textDisabled
        : color ?? (filled ? PongColors.textBody : PongColors.textPrimary);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: PongPressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        width: PongSizes.touchTarget,
        height: PongSizes.touchTarget,
        borderRadius: PongRadii.fieldAll,
        pressedScale: 0.92,
        decoration: BoxDecoration(
          color: filled ? const Color(0xBF1E1E28) : null,
        ),
        child: Icon(icon, size: 24, color: iconColor),
      ),
    );
  }
}

/// Bouton compact rose (48 px, sans halo) : uniquement l'action d'une ligne
/// de liste. Ne compte pas comme « le » bouton principal de l'écran.
class PongCompactButton extends StatelessWidget {
  const PongCompactButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PongPressable(
      onTap: onPressed,
      height: PongSizes.touchTarget,
      borderRadius: PongRadii.fieldAll,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: enabled ? PongColors.pink : PongColors.surfaceDisabled,
      ),
      child: _ButtonContent(
        label: label,
        style: PongText.buttonLabelPlain.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: enabled ? Colors.white : PongColors.textDisabled,
        ),
      ),
    );
  }
}

/// Tuile d'accès 64 px : icône au-dessus d'un mot. Se place dans une `Row`,
/// chaque tuile dans un `Expanded` (Classement · Statistiques · Aide).
class PongTileButton extends StatelessWidget {
  const PongTileButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? PongColors.textBody : PongColors.textDisabled;
    return PongPressable(
      onTap: onPressed,
      height: 64,
      width: double.infinity,
      borderRadius: PongRadii.fieldAll,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.xxs),
      decoration: const BoxDecoration(
        color: PongColors.surface,
        border:
            Border.fromBorderSide(BorderSide(color: PongColors.borderSubtle)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: PongSpacing.xxs),
            Text(label,
                maxLines: 1, style: PongText.tileLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Bouton principal « en attente » (maquette V2) : la place du bouton rose
/// une fois l'action lancée, quand la suite dépend de l'autre joueur
/// (« En attente de Tom… »). Contour rose 1,5 px, fond rose 10 %, roue qui
/// tourne, sans halo : il n'y a plus rien à faire qu'attendre.
///
/// Avec `onPressed`, le toucher annule l'attente ; sans, il est inerte.
class PongPendingButton extends StatelessWidget {
  const PongPendingButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;

  /// Annule l'action en attente ; `null` = le bouton ne fait rien.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PongPressable(
      // Un bouton sans action reste lisible (pas grisé) : c'est un état
      onTap: onPressed,
      height: PongSizes.primaryButton,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.lg),
      decoration: BoxDecoration(
        color: PongColors.alpha(PongColors.pink, 0.1),
        border: Border.all(
            color: PongColors.alpha(PongColors.pink, 0.6), width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PongColors.pinkLight,
                backgroundColor: PongColors.alpha(PongColors.pinkLight, 0.3),
              ),
            ),
            const SizedBox(width: 10),
            Text(label,
                maxLines: 1,
                style: PongText.buttonLabelPlain
                    .copyWith(color: PongColors.pinkLight)),
          ],
        ),
      ),
    );
  }
}
