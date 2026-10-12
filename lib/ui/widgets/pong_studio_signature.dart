// Signature du studio : « Un jeu de » + petit logo blanc + chevron, et une
// ligne facultative en dessous (version). En pied de page des Réglages et de
// l'Aide, jamais pendant une partie. Toute la ligne (48 px de haut) ouvre la
// page « Le studio » quand `onTap` est donné.
//
// Nom et logo viennent de `Studio.current` (lib/studio/), mis à jour par le
// site ; à défaut, ceux de lib/brand.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../brand.dart';
import '../../studio/studio_info.dart';
import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';
import 'pong_pressable.dart';

class PongStudioSignature extends StatelessWidget {
  const PongStudioSignature({super.key, this.caption, this.onTap, this.studio});

  /// Ligne sous la signature (ex. nom du jeu et version), hors zone tactile.
  final String? caption;

  /// Ouvre la page « Le studio » ; `null` = signature inerte, sans chevron.
  final VoidCallback? onTap;

  /// Présentation à afficher (tests) ; par défaut `Studio.current`.
  final ValueListenable<StudioInfo>? studio;

  /// Hauteur du logo : à peine plus grand que le texte qui le précède.
  static const double logoHeight = 16;

  /// Largeur maximale du logo, pour un logo très allongé.
  static const double logoMaxWidth = 160;

  /// Le blanc du logo est plus lumineux que le gris du texte : on l'atténue
  /// pour que la signature reste en retrait.
  static const double logoOpacity = 0.7;

  static const TextStyle _style = TextStyle(
    fontFamily: PongText.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: PongColors.textTertiary,
  );

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return ValueListenableBuilder<StudioInfo>(
      valueListenable: studio ?? Studio.current,
      builder: (context, info, _) {
        final line = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(Brand.signaturePrefix, style: _style),
            const SizedBox(width: PongSpacing.xs),
            Flexible(
              child: PongStudioLogo(
                info: info,
                height: logoHeight,
                maxWidth: logoMaxWidth,
                opacity: logoOpacity,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: PongSpacing.xxs),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: PongColors.textTertiary),
            ],
          ],
        );
        final signature = onTap == null
            ? Semantics(
                label: '${Brand.signaturePrefix} ${info.name}',
                excludeSemantics: true,
                child: line,
              )
            : PongPressable(
                onTap: onTap,
                semanticLabel: 'Le studio, ${info.name}',
                borderRadius: PongRadii.fieldAll,
                padding: const EdgeInsets.symmetric(horizontal: PongSpacing.sm),
                child: ExcludeSemantics(child: line),
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            signature,
            if (caption != null) ...[
              const SizedBox(height: PongSpacing.xxs),
              Text(caption, style: _style, textAlign: TextAlign.center),
            ],
          ],
        );
      },
    );
  }
}

/// Logo du studio à une hauteur donnée : le logo du site, sinon le logo
/// intégré (studio d'origine), sinon le nom écrit en blanc.
class PongStudioLogo extends StatelessWidget {
  const PongStudioLogo({
    super.key,
    required this.info,
    required this.height,
    this.maxWidth = double.infinity,
    this.opacity = 1,
  });

  final StudioInfo info;
  final double height;
  final double maxWidth;

  /// Atténuation (1 = blanc plein).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final width = (height * info.logoAspectRatio).clamp(height, maxWidth);
    final logo = info.logo;
    final Widget image;
    if (logo != null) {
      image = Image.memory(
        logo,
        height: height,
        width: width,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        opacity: AlwaysStoppedAnimation(opacity),
        errorBuilder: (context, _, __) => _name(),
      );
    } else if (info.usesBuiltInLogo) {
      image = Image.asset(
        Brand.logoLight,
        height: height,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        opacity: AlwaysStoppedAnimation(opacity),
      );
    } else {
      image = _name();
    }
    return Semantics(
      label: info.name,
      image: !info.showsNameAsText,
      excludeSemantics: true,
      child: image,
    );
  }

  /// Le nom en texte, à la hauteur du logo ; un nom long rétrécit pour
  /// tenir en entier sur une ligne.
  Widget _name() => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            info.name,
            maxLines: 1,
            style: TextStyle(
              fontFamily: PongText.fontFamily,
              fontSize: height * 0.9,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: PongColors.alpha(PongColors.textPrimary, opacity),
            ),
          ),
        ),
      );
}
