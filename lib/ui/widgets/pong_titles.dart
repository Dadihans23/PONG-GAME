// Titres et textes espacés.
//
// - `PongLogo` : le mot « PONG » avec halo rose (chargement, accueil).
// - `PongScreenTitle` : titre d'écran espacé (« CLASSEMENT »), centré.
//   Normalement placé par `PongHeaderBar`, pas à la main.
// - `PongOverline` : sur-titre de section (« MODE DE JEU »), aligné à gauche.
// - `PongSpacedText` : tout texte à `letterSpacing` qu'on veut centrer.
//
// Écrire le texte normalement (« Classement ») : ces widgets le passent en
// majuscules. Jamais d'espaces entre les lettres (« C L A S S E M E N T »).
import 'package:flutter/material.dart';

import '../pong_text.dart';

/// Texte espacé correctement centré : Flutter ajoute l'espacement après
/// chaque lettre, y compris la dernière ; on compense par un décalage
/// à gauche de la même valeur.
class PongSpacedText extends StatelessWidget {
  const PongSpacedText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final spacing = style.letterSpacing ?? 0;
    return Padding(
      padding: EdgeInsets.only(
          left: textAlign == TextAlign.center ? spacing : 0),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Logo « PONG » : Black 900, espacement 0,45 em, halo rose.
/// 40 px sur l'écran de chargement, 32 px dans l'en-tête de l'accueil.
class PongLogo extends StatelessWidget {
  const PongLogo({super.key, this.fontSize = 40});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Pong',
      excludeSemantics: true,
      child: PongSpacedText(
        'PONG',
        style: PongText.logo.copyWith(
          fontSize: fontSize,
          letterSpacing: fontSize * 0.45,
        ),
      ),
    );
  }
}

/// Titre d'écran : 16 · 800 · 0,42 em · #B8B8C4, en majuscules, centré.
class PongScreenTitle extends StatelessWidget {
  const PongScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: PongSpacedText(text.toUpperCase(), style: PongText.screenTitle),
    );
  }
}

/// Sur-titre de section : 11 · 800 · 0,22 em · #6B6B7A, en majuscules.
class PongOverline extends StatelessWidget {
  const PongOverline(this.text, {super.key, this.color});

  final String text;

  /// Couleur, si différente du gris tertiaire par défaut.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: color == null
            ? PongText.overline
            : PongText.overline.copyWith(color: color),
      ),
    );
  }
}
