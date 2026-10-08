import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Aide (maquette A1). Les icônes reprennent les couleurs de sens du jeu
/// (bleu = ta raquette, or = points, orange = vitesse) : l'aide enseigne
/// aussi le code couleur (rose = multijoueur, comme sa carte à l'accueil).
class AidePage extends StatelessWidget {
  const AidePage({super.key});

  static final List<_HelpSection> _sections = [
    _HelpSection(
      icon: Icons.screen_rotation_rounded,
      color: PongColors.playerLight,
      background: PongColors.alpha(PongColors.player, 0.14),
      title: 'Contrôles',
      text: 'Incline le téléphone à gauche ou à droite pour déplacer ta '
          'raquette.',
    ),
    _HelpSection(
      icon: Icons.sports_tennis_rounded,
      color: PongColors.textPrimary,
      background: PongColors.alpha(PongColors.textPrimary, 0.08),
      title: 'Objectif',
      text: 'Renvoie la balle le plus longtemps possible. Si elle passe '
          "derrière toi, c'est fini.",
    ),
    const _HelpSection(
      icon: Icons.star_rounded,
      color: PongColors.record,
      title: 'Points',
      text: "+50 par renvoi, +100 quand l'adversaire rate.",
    ),
    const _HelpSection(
      icon: Icons.speed_rounded,
      color: PongColors.streak,
      title: 'Vitesse',
      text: 'La balle accélère tous les 4 renvois.',
    ),
    _HelpSection(
      icon: Icons.pause_rounded,
      color: PongColors.textBody,
      background: PongColors.alpha(PongColors.textPrimary, 0.08),
      title: 'Pause',
      text: 'Touche le bouton pause en haut à droite. Pas de pause en '
          'multijoueur.',
    ),
    _HelpSection(
      icon: Icons.group_rounded,
      color: PongColors.pinkLight,
      background: PongColors.alpha(PongColors.pink, 0.14),
      title: 'Multijoueur',
      text: 'Connectez-vous au même Wi‑Fi (ou au partage de connexion de '
          "l'un de vous). L'un crée la partie, l'autre la rejoint. Premier "
          'à 5 points.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PongPageScaffold(
      title: 'Aide',
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        itemCount: _sections.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: PongSpacing.xs),
        itemBuilder: (context, index) => _sections[index],
      ),
    );
  }
}

/// Une règle : pastille d'icône colorée, titre, phrase.
class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.background,
  });

  final IconData icon;
  final Color color;

  /// Fond de la pastille ; par défaut [color] à 12 %.
  final Color? background;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PongCard(
      padding: const EdgeInsets.all(14),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PongIconBadge(
              icon: icon,
              color: color,
              background: background,
              size: 40,
              iconSize: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title,
                        style: PongText.cardTitle.copyWith(fontSize: 15)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: PongText.caption
                        .copyWith(fontWeight: FontWeight.w400, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
