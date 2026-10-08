// Palette du système de design v2 (maquette « Pong Design System », section 02).
//
// Chaque couleur est nommée par son RÔLE, pas par sa teinte : on écrit
// `PongColors.player` et non `Colors.blue`. Règles de sens :
// - rose plein (`pink`) : action principale de l'écran et sélection ;
// - bleu (`player`) : toi ; vert (`opponent`) : l'adversaire ;
// - or (`record`) : record ; rouge (`error`) : erreur ou déconnexion ;
// - podium (`gold`, `silver`, `bronze`) : classement uniquement.
//
// Les variantes « teinte » (`pinkTint`, `errorRing`…) sont les fonds et halos
// semi-transparents de la maquette, déjà calculés pour éviter `withOpacity`.
import 'package:flutter/painting.dart';

abstract final class PongColors {
  // --- Fonds & surfaces ---------------------------------------------------
  /// Noir pur : écran de chargement uniquement.
  static const Color black = Color(0xFF000000);

  /// Fond de tous les écrans et du terrain.
  static const Color background = Color(0xFF0B0B10);

  /// Cartes, dialogues, champs (opaque).
  static const Color surface = Color(0xFF15151C);

  /// Boutons secondaires, segments non sélectionnés, tuiles de chiffres.
  static const Color surfaceHigh = Color(0xFF1E1E28);

  /// Fond d'un bouton désactivé.
  static const Color surfaceDisabled = Color(0xFF1A1A22);

  /// Contour 1 px des boutons secondaires, champs et dialogues.
  static const Color border = Color(0xFF2A2A36);

  /// Contour 1 px, plus discret, des cartes et lignes de liste.
  static const Color borderSubtle = Color(0xFF23232D);

  /// Voile derrière un dialogue : #050508 à 80 %.
  static const Color scrim = Color(0xCC050508);

  // --- Texte -------------------------------------------------------------
  /// Texte principal (17:1 sur le fond).
  static const Color textPrimary = Color(0xFFF2F2F5);

  /// Corps de texte et libellés des boutons texte / tuiles.
  static const Color textBody = Color(0xFFC8C8D2);

  /// Titres d'écran espacés (« CLASSEMENT »).
  static const Color textTitle = Color(0xFFB8B8C4);

  /// Texte secondaire, légendes (7:1 sur le fond).
  static const Color textSecondary = Color(0xFF9E9EAB);

  /// Sur-titres, HUD de jeu.
  static const Color textTertiary = Color(0xFF6B6B7A);

  /// Texte et icône d'un élément désactivé ou non coché.
  static const Color textDisabled = Color(0xFF55556A);

  // --- Action ------------------------------------------------------------
  /// Rose néon : action principale, sélection.
  static const Color pink = Color(0xFFE91E63);

  /// Rose clair : liens et texte rose (contraste 6:1).
  static const Color pinkLight = Color(0xFFFF5C93);

  /// Teinte de fond d'un élément sélectionné (rose 16 %).
  static const Color pinkTint = Color(0x29E91E63);

  /// Teinte de fond d'une carte de choix sélectionnée (rose 8 %).
  static const Color pinkTintSoft = Color(0x14E91E63);

  /// `pinkTint` déjà posé sur `background`, opaque. Fond d'un segment
  /// sélectionné : le halo peint sous l'élément ne transparaît pas (en CSS
  /// il reste dehors, pas en Flutter).
  static const Color pinkTintSolid = Color(0xFF2F0E1D);

  /// `pinkTintSoft` déjà posé sur `background`, opaque (#1C0C16). Fond d'une
  /// carte de choix sélectionnée, pour la même raison.
  static const Color pinkTintSoftSolid = Color(0xFF1C0C16);

  /// Fond de la pastille d'icône rose (rose 18 %).
  static const Color pinkBadge = Color(0x2EE91E63);

  /// Anneau de focus d'un champ (rose 14 %).
  static const Color pinkRing = Color(0x24E91E63);

  // --- Jeu ---------------------------------------------------------------
  /// Bleu joueur : ta raquette, ton score.
  static const Color player = Color(0xFF2196F3);

  /// Bleu joueur éclairci, pour du texte sur fond teinté.
  static const Color playerLight = Color(0xFF64B5F6);

  /// Vert adversaire : IA ou autre joueur.
  static const Color opponent = Color(0xFF4CAF50);

  /// Balle : seul blanc pur du terrain.
  static const Color ball = Color(0xFFFFFFFF);

  /// Score « fantôme » en jeu : blanc 22 %.
  static const Color ghostScore = Color(0x38FFFFFF);

  /// Contour du terrain : blanc 7 %.
  static const Color courtLine = Color(0x12FFFFFF);

  /// Tirets de la ligne médiane du terrain : blanc 12 %.
  static const Color courtMidline = Color(0x1FFFFFFF);

  /// Reflet clair de la raquette du joueur quand elle renvoie la balle.
  static const Color playerFlash = Color(0xFF90CAF9);

  /// Case vide d'une jauge.
  static const Color gaugeEmpty = Color(0xFF22222C);

  // --- Signaux & données -------------------------------------------------
  /// Or record : nouveau record, meilleur score.
  static const Color record = Color(0xFFFFC93C);

  /// Succès : « Prêt », victoires.
  static const Color success = Color(0xFF66BB6A);

  /// Erreur : champ vide, déconnexion (contours, icônes).
  static const Color error = Color(0xFFFF5252);

  /// Texte d'un message d'erreur.
  static const Color errorText = Color(0xFFFF6B6B);

  /// Anneau autour d'un champ en erreur (rouge 12 %).
  static const Color errorRing = Color(0x1FFF5252);

  /// Violet bonus : power-ups (futur).
  static const Color bonus = Color(0xFF9575FF);

  /// Violet bonus éclairci, pour du texte sur fond teinté.
  static const Color bonusLight = Color(0xFFB3A0FF);

  /// Orange série : série de renvois, vitesse.
  static const Color streak = Color(0xFFFF9800);

  /// Bleu données : parties jouées.
  static const Color data = Color(0xFF448AFF);

  // --- Podium (classement uniquement) -------------------------------------
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  /// Couleur du podium pour un rang (1, 2, 3), ou `null` au-delà.
  static Color? podium(int rank) => switch (rank) {
        1 => gold,
        2 => silver,
        3 => bronze,
        _ => null,
      };

  /// Même couleur avec une opacité donnée (0 à 1), pour les teintes
  /// et halos calculés à partir d'une couleur de rôle.
  static Color alpha(Color color, double opacity) =>
      color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}
