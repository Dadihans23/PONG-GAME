// Signature du studio : « Un jeu de » + petit logo blanc, et une ligne
// facultative en dessous (version). En bas des Réglages et de l'Aide,
// jamais pendant une partie. Noms et logo viennent de lib/brand.dart.
import 'package:flutter/material.dart';

import '../../brand.dart';
import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';

class PongStudioSignature extends StatelessWidget {
  const PongStudioSignature({super.key, this.caption});

  /// Ligne sous la signature (ex. nom du jeu et version).
  final String? caption;

  /// Hauteur du logo : à peine plus grand que le texte qui le précède.
  static const double logoHeight = 16;

  /// Le blanc du logo est plus lumineux que le gris du texte : on l'atténue
  /// pour que la signature reste en retrait.
  static const double _logoOpacity = 0.7;

  static const TextStyle _style = TextStyle(
    fontFamily: PongText.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: PongColors.textTertiary,
  );

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Semantics(
      label: caption == null ? Brand.signature : '${Brand.signature}. $caption',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Brand.signaturePrefix, style: _style),
              const SizedBox(width: PongSpacing.xs),
              Image.asset(
                Brand.logoLight,
                height: logoHeight,
                width: logoHeight * Brand.logoLightAspectRatio,
                opacity: const AlwaysStoppedAnimation(_logoOpacity),
                filterQuality: FilterQuality.medium,
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: PongSpacing.xxs),
            Text(caption, style: _style, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
