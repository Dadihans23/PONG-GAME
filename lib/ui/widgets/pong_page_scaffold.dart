// Gabarit commun des écrans (maquette, section 08) : barre de titre 64 px ·
// contenu · action principale ancrée en bas, à 20 px des bords.
//
// Le `body` gère lui-même son défilement et ses marges : en général un
// `ListView(padding: PongSpacing.screenPadding, …)`.
//
// ```dart
// PongPageScaffold(
//   title: 'Statistiques',
//   body: ListView(padding: PongSpacing.screenPadding, children: [...]),
//   bottomAction: PongPrimaryButton(label: 'Jouer', onPressed: _play),
// )
// ```
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_tokens.dart';
import 'pong_header_bar.dart';

class PongPageScaffold extends StatelessWidget {
  const PongPageScaffold({
    super.key,
    required this.body,
    this.title,
    this.header,
    this.showBack = true,
    this.onBack,
    this.trailing,
    this.bottomAction,
    this.backgroundColor = PongColors.background,
  });

  final Widget body;

  /// Titre de la barre d'en-tête. Sans `title` ni `header`, pas d'en-tête.
  final String? title;

  /// Barre d'en-tête personnalisée, à la place de celle construite avec
  /// `title`, `showBack`, `onBack` et `trailing`.
  final PreferredSizeWidget? header;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Zone ancrée en bas : le bouton principal, éventuellement avec un bouton
  /// texte dessous (dans une `Column(mainAxisSize: MainAxisSize.min)`).
  final Widget? bottomAction;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final bottomAction = this.bottomAction;
    final appBar = header ??
        (title == null
            ? null
            : PongHeaderBar(
                title: title,
                showBack: showBack,
                onBack: onBack,
                trailing: trailing,
              ));
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: SafeArea(
        top: appBar == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            if (bottomAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(PongSpacing.screen,
                    PongSpacing.sm, PongSpacing.screen, PongSpacing.screen),
                child: bottomAction,
              ),
          ],
        ),
      ),
    );
  }
}
