// Dialogue sombre (maquette, section 05) : carte rayon 24, surface #15151C,
// bordure 1 px, ombre portée, voile #050508 à 80 %. Remplace l'AlertDialog
// clair.
//
// - `PongDialogCard` : la carte elle-même (pastille d'icône, titre, message,
//   contenu libre, actions empilées). Utilisable aussi dans un overlay
//   (pause, fin de partie) posé au-dessus du terrain.
// - `showPongDialog` : l'ouvre par-dessus l'écran courant avec le bon voile.
//
// ```dart
// showPongDialog<void>(
//   context: context,
//   builder: (context) => PongDialogCard(
//     icon: Icons.link_off_rounded,
//     iconColor: PongColors.error,
//     title: 'Connexion perdue',
//     message: "L'autre joueur a quitté la partie.",
//     actions: [PongPrimaryButton(label: 'OK', onPressed: () => Navigator.pop(context))],
//   ),
// );
// ```
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';
import 'pong_cards.dart';

class PongDialogCard extends StatelessWidget {
  const PongDialogCard({
    super.key,
    this.icon,
    this.iconColor = PongColors.pinkLight,
    this.title,
    this.message,
    this.content,
    this.actions = const [],
    this.padding = const EdgeInsets.all(PongSpacing.lg),
  });

  /// Icône dans une pastille ronde teintée de `iconColor`.
  final IconData? icon;
  final Color iconColor;

  /// Titre court (20 · Bold).
  final String? title;

  /// Une phrase qui dit ce qui se passe et quoi faire.
  final String? message;

  /// Contenu libre sous le message (score, tuiles de chiffres…).
  final Widget? content;

  /// Boutons, empilés et étirés, espacés de 8 px. Au plus un
  /// `PongPrimaryButton`.
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final title = this.title;
    final message = this.message;
    final content = this.content;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        color: PongColors.surface,
        borderRadius: PongRadii.dialogAll,
        border: Border.fromBorderSide(BorderSide(color: PongColors.border)),
        boxShadow: PongShadows.dialog,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Center(
              child: PongIconBadge(
                icon: icon,
                color: iconColor,
                size: 56,
                iconSize: 28,
                circular: true,
              ),
            ),
            const SizedBox(height: PongSpacing.sm),
          ],
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(title,
                  textAlign: TextAlign.center, style: PongText.dialogTitle),
            ),
            const SizedBox(height: PongSpacing.sm),
          ],
          if (message != null)
            Text(
              message,
              textAlign: TextAlign.center,
              style: PongText.body
                  .copyWith(fontSize: 14, color: PongColors.textSecondary),
            ),
          if (content != null) ...[
            const SizedBox(height: PongSpacing.sm),
            content,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: PongSpacing.lg - 4),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: PongSpacing.xs),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }
}

/// Ouvre un dialogue Pong : voile #050508 à 80 %, marges latérales 20 px.
/// `barrierDismissible: false` par défaut : le joueur choisit une action.
Future<T?> showPongDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: PongColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: PongSpacing.screen, vertical: PongSpacing.lg),
      child: builder(context),
    ),
  );
}
