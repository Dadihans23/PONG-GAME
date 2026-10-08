// Styles de texte du système de design v2 (maquette, section 03).
//
// Police : Archivo, intégrée à l'app (assets/fonts, licence OFL), graisses
// 400, 500, 600, 700, 800 et 900. Aucun téléchargement au lancement.
//
// Règles :
// - Les titres espacés (« CLASSEMENT ») s'écrivent en MAJUSCULES SANS espaces
//   entre les lettres : l'espacement vient de `letterSpacing`. Les lecteurs
//   d'écran lisent ainsi un vrai mot. Pour centrer un texte espacé, utiliser
//   `PongSpacedText` (widgets/pong_titles.dart), qui compense l'espace ajouté
//   après la dernière lettre.
// - Tout chiffre qui change (score, compteur) utilise un style « tabulaire »
//   (`gameScore`, `keyFigure`, `listValue`, `figure`) pour qu'il ne danse pas.
// - Les couleurs par défaut sont celles de la maquette ; pour un autre rôle,
//   `PongText.keyFigure.copyWith(color: PongColors.data)`.
import 'package:flutter/painting.dart';

import 'pong_colors.dart';

abstract final class PongText {
  /// Nom de la famille déclarée dans pubspec.yaml.
  static const String fontFamily = 'Archivo';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Logo « PONG » : 40 · Black 900 · 0,45 em · halo rose.
  static const TextStyle logo = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    letterSpacing: 40 * 0.45,
    height: 1.1,
    color: PongColors.textPrimary,
    shadows: [Shadow(color: Color(0x8CE91E63), blurRadius: 24)],
  );

  /// Titre d'écran : 16 · ExtraBold 800 · 0,42 em · #B8B8C4.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 16 * 0.42,
    height: 1.2,
    color: PongColors.textTitle,
  );

  /// Libellé du bouton principal : 15 · ExtraBold 800 · 0,3 em.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 15 * 0.3,
    height: 1.2,
    color: PongColors.textPrimary,
  );

  /// Libellé des boutons secondaires et texte : 15 · Bold 700, non espacé.
  static const TextStyle buttonLabelPlain = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: PongColors.textPrimary,
  );

  /// Sur-titre de section : 11 · ExtraBold 800 · 0,22 em · #6B6B7A.
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 11 * 0.22,
    height: 1.3,
    color: PongColors.textTertiary,
  );

  /// Titre de carte : 17 · Bold 700.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: PongColors.textPrimary,
  );

  /// Titre de dialogue : 20 · Bold 700.
  static const TextStyle dialogTitle = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: PongColors.textPrimary,
  );

  /// Salutation / titre de contenu : 22 · Bold 700 (« Bonjour, Léa »).
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: PongColors.textPrimary,
  );

  /// Corps : 15 · Regular 400 · interligne 1,5.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: PongColors.textBody,
  );

  /// Légende : 13 · Medium 500 · #9E9EAB.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: PongColors.textSecondary,
  );

  /// Score de jeu : 64 · Black 900 · tabulaire · blanc 22 % (« fantôme »).
  static const TextStyle gameScore = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 64,
    fontWeight: FontWeight.w900,
    height: 1,
    color: PongColors.ghostScore,
    fontFeatures: _tabular,
  );

  /// Nom sous le score de jeu / HUD : 11 · ExtraBold 800 · 0,3 em.
  static const TextStyle hudLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 11 * 0.3,
    height: 1.3,
    color: PongColors.textTertiary,
  );

  /// Chiffre clé : 32 · ExtraBold 800 · tabulaire · couleur de donnée.
  static const TextStyle keyFigure = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: PongColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Valeur d'une ligne de liste (score du classement) : 20 · 800 · tabulaire.
  static const TextStyle listValue = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: PongColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Petit chiffre de tuile (récap de fin de partie) : 17 · 800 · tabulaire.
  static const TextStyle figure = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: PongColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Libellé de pastille-signal : 11 · ExtraBold 800 · 0,18 em.
  static const TextStyle pillLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 11 * 0.18,
    height: 1.2,
  );

  /// Libellé de pastille d'état (« Prêt ») : 12 · Bold 700.
  static const TextStyle statusLabel = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Libellé de segment : 14 · SemiBold 600 (ExtraBold 800 sélectionné).
  static const TextStyle segmentLabel = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: PongColors.textSecondary,
  );

  /// Libellé de tuile d'accès (icône + mot) : 12 · SemiBold 600.
  static const TextStyle tileLabel = TextStyle(
    fontFamily: fontFamily,
    letterSpacing: 0,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: PongColors.textBody,
  );
}
