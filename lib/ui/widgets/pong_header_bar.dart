// Barre d'en-tête 64 px : retour à gauche, titre espacé centré, action
// facultative à droite. S'utilise comme `Scaffold.appBar` (gère la barre
// d'état) ou via `PongPageScaffold`.
//
// ```dart
// Scaffold(appBar: const PongHeaderBar(title: 'Classement'), body: ...)
// PongHeaderBar(
//   center: const PongLogo(fontSize: 32),
//   showBack: false,
//   trailing: PongIconButton(icon: Icons.settings_rounded, tooltip: 'Réglages', onPressed: ...),
// )
// ```
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_tokens.dart';
import 'pong_buttons.dart';
import 'pong_titles.dart';

class PongHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const PongHeaderBar({
    super.key,
    this.title,
    this.center,
    this.showBack = true,
    this.onBack,
    this.trailing,
  }) : assert(title == null || center == null,
            'Donner soit title, soit center');

  /// Titre d'écran, écrit normalement (« Classement ») : affiché en
  /// majuscules espacées.
  final String? title;

  /// Widget central à la place du titre (ex. `PongLogo(fontSize: 32)`).
  final Widget? center;

  /// Affiche le bouton retour (flèche) à gauche.
  final bool showBack;

  /// Action du bouton retour ; par défaut `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Élément à droite, 48 px de large (ex. `PongIconButton`).
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(PongSizes.headerBar);

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: PongSizes.headerBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PongSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: PongSizes.touchTarget,
                child: showBack
                    ? PongIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Retour',
                        color: PongColors.textPrimary,
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
              ),
              Expanded(
                child: Center(
                  child: center ??
                      (title == null ? null : PongScreenTitle(title)),
                ),
              ),
              SizedBox(width: PongSizes.touchTarget, child: trailing),
            ],
          ),
        ),
      ),
    );
  }
}
