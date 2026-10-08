// Espacements, rayons, tailles et halos du système de design v2
// (maquette, sections 04, 05 et 08).
//
// Gabarit commun à tous les écrans : barre de titre 64 px (retour à gauche,
// titre espacé centré) · contenu défilant · action principale ancrée en bas,
// à 20 px du bord. `PongPageScaffold` (widgets/pong_page_scaffold.dart)
// applique ce gabarit.
import 'package:flutter/painting.dart';

import 'pong_colors.dart';

/// Échelle d'espacements : 8 · 12 · 16 · 24 (16 entre cartes, 24 entre groupes).
abstract final class PongSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Marge latérale de tous les écrans (360 de large -> 320 utiles).
  static const double screen = 20;

  /// Marge écran standard, à utiliser dans un `Padding`.
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: screen);
}

/// Rayons : 12 segments · 14 champs, icônes, boutons compacts · 16 boutons
/// et cartes · 18 cartes de choix · 24 dialogues.
abstract final class PongRadii {
  static const double segment = 12;
  static const double field = 14;
  static const double button = 16;
  static const double card = 16;
  static const double choiceCard = 18;
  static const double dialog = 24;

  static const BorderRadius segmentAll =
      BorderRadius.all(Radius.circular(segment));
  static const BorderRadius fieldAll = BorderRadius.all(Radius.circular(field));
  static const BorderRadius buttonAll =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius choiceCardAll =
      BorderRadius.all(Radius.circular(choiceCard));
  static const BorderRadius dialogAll =
      BorderRadius.all(Radius.circular(dialog));
}

/// Tailles fixes.
abstract final class PongSizes {
  /// Zone tactile minimale.
  static const double touchTarget = 48;

  /// Hauteur du bouton principal (et du bouton secondaire standard).
  static const double primaryButton = 56;

  /// Hauteur du champ de texte.
  static const double field = 56;

  /// Hauteur de la barre d'en-tête.
  static const double headerBar = 64;

  /// Hauteur des pastilles.
  static const double pill = 28;

  /// Raquettes (inchangées) et balle.
  static const double paddleWidth = 80;
  static const double paddleHeight = 15;
  static const double ball = 20;
}

/// Halos (`BoxShadow`) : ils signalent ce qui est vivant (action, balle,
/// record). Pas de flou d'arrière-plan.
abstract final class PongShadows {
  /// Bouton principal rose.
  static const List<BoxShadow> primaryButton = [
    BoxShadow(color: Color(0x80E91E63), blurRadius: 24),
    BoxShadow(color: Color(0x4DE91E63), blurRadius: 28, offset: Offset(0, 8)),
  ];

  /// Segment ou bouton sélectionné : petit halo rose.
  static const List<BoxShadow> selected = [
    BoxShadow(color: Color(0x4DE91E63), blurRadius: 14),
  ];

  /// Carte de choix sélectionnée.
  static const List<BoxShadow> selectedCard = [
    BoxShadow(color: Color(0x2EE91E63), blurRadius: 24),
  ];

  /// Ombre portée d'un dialogue.
  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, 24)),
  ];

  /// Balle : double halo blanc.
  static const List<BoxShadow> ball = [
    BoxShadow(color: Color(0xCCFFFFFF), blurRadius: 12),
    BoxShadow(color: Color(0x4DFFFFFF), blurRadius: 32),
  ];

  /// Raquette du joueur (bleue).
  static const List<BoxShadow> playerPaddle = [
    BoxShadow(color: Color(0x992196F3), blurRadius: 16),
  ];

  /// Raquette adverse (verte).
  static const List<BoxShadow> opponentPaddle = [
    BoxShadow(color: Color(0x8C4CAF50), blurRadius: 16),
  ];

  /// Halo d'une couleur quelconque (opacité 0 à 1).
  static List<BoxShadow> glow(Color color,
          {double opacity = 0.5, double blur = 24}) =>
      [BoxShadow(color: PongColors.alpha(color, opacity), blurRadius: blur)];
}

/// Durées d'animation d'interface (jamais en jeu).
abstract final class PongDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration shake = Duration(milliseconds: 450);
}
