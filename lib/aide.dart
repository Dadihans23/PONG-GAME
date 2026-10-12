import 'package:flutter/material.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/studio/studio_page.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Aide (maquette A1). Les icônes reprennent les couleurs de sens du jeu
/// (bleu = ta raquette, or = points, orange = vitesse) : l'aide enseigne
/// aussi le code couleur (rose = multijoueur, comme sa carte à l'accueil).
class AidePage extends StatelessWidget {
  const AidePage({super.key});

  static List<_HelpSection> _sections(AppLocalizations l10n) => [
        _HelpSection(
          icon: Icons.screen_rotation_rounded,
          color: PongColors.playerLight,
          background: PongColors.alpha(PongColors.player, 0.14),
          title: l10n.helpControlsTitle,
          text: l10n.helpControlsText,
        ),
        _HelpSection(
          icon: Icons.sports_tennis_rounded,
          color: PongColors.textPrimary,
          background: PongColors.alpha(PongColors.textPrimary, 0.08),
          title: l10n.helpGoalTitle,
          text: l10n.helpGoalText,
        ),
        _HelpSection(
          icon: Icons.star_rounded,
          color: PongColors.record,
          title: l10n.helpPointsTitle,
          text: l10n.helpPointsText,
        ),
        _HelpSection(
          icon: Icons.speed_rounded,
          color: PongColors.streak,
          title: l10n.helpSpeedTitle,
          text: l10n.helpSpeedText,
        ),
        _HelpSection(
          icon: Icons.pause_rounded,
          color: PongColors.textBody,
          background: PongColors.alpha(PongColors.textPrimary, 0.08),
          title: l10n.helpPauseTitle,
          text: l10n.helpPauseText,
        ),
        _HelpSection(
          icon: Icons.group_rounded,
          color: PongColors.pinkLight,
          background: PongColors.alpha(PongColors.pink, 0.14),
          title: l10n.modeMultiplayer,
          text: l10n.helpMultiplayerText,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PongPageScaffold(
      title: l10n.helpTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        children: [
          for (final (index, section) in _sections(l10n).indexed) ...[
            if (index > 0) const SizedBox(height: PongSpacing.xs),
            section,
          ],
          // Signature du studio, en retrait sous les règles : elle ouvre la
          // page « Le studio »
          const SizedBox(height: PongSpacing.xl),
          PongStudioSignature(onTap: () => StudioPage.open(context)),
        ],
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
