import 'package:flutter/material.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Ce que le joueur choisit sur la carte de fin de partie.
enum GameOverAction { replay, leaderboard, statistics, home }

/// Bilan d'une partie terminée, affiché par [GameOverCard].
class GameSummary {
  const GameSummary({
    required this.score,
    required this.previousRecord,
    required this.isNewRecord,
    required this.hits,
    required this.duration,
    required this.maxSpeed,
    this.rank,
  });

  final int score;

  /// Meilleur score avant cette partie.
  final int previousRecord;

  /// La partie a battu un record existant (supérieur à 0).
  final bool isNewRecord;

  /// Renvois du joueur.
  final int hits;
  final Duration duration;

  /// Niveau de vitesse atteint (« VITESSE n »).
  final int maxSpeed;

  /// Rang au classement après enregistrement, `null` hors du classement.
  final int? rank;

  /// Meilleur score après cette partie.
  int get record => score > previousRecord ? score : previousRecord;
}

/// Carte sombre de fin de partie (maquette E1), passée à l'or pour une partie
/// record (E2). « Rejouer » est la seule action rose.
class GameOverCard extends StatelessWidget {
  const GameOverCard(
      {super.key, required this.summary, required this.onAction});

  final GameSummary summary;
  final ValueChanged<GameOverAction> onAction;

  @override
  Widget build(BuildContext context) {
    final bool gold = summary.isNewRecord;
    final int? rank = summary.rank;
    final l10n = context.l10n;
    final format = PongFormat.of(context);
    return PongDialogCard(
      accentColor: gold ? PongColors.record : null,
      padding: const EdgeInsets.fromLTRB(
          PongSpacing.screen, 28, PongSpacing.screen, PongSpacing.sm),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gold)
            // Réduite plutôt que coupée si la police système est très grande
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PongPill.signal(
                label: l10n.gameOverNewRecord,
                color: PongColors.record,
                icon: Icons.star_rounded,
              ),
            )
          else
            PongSpacedText(
              l10n.gameOverTitle.toUpperCase(),
              style: PongText.overline.copyWith(
                fontSize: 12,
                letterSpacing: 12 * 0.3,
                color: PongColors.textSecondary,
              ),
            ),
          const SizedBox(height: PongSpacing.xs + 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              format.number(summary.score),
              maxLines: 1,
              style: PongText.gameScore.copyWith(
                height: 1.1,
                color: gold ? PongColors.record : PongColors.textPrimary,
                shadows: gold
                    ? [
                        Shadow(
                          color: PongColors.alpha(PongColors.record, 0.4),
                          blurRadius: 28,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _subtitle(l10n, format),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PongFigureTile(
                    value: format.number(summary.hits),
                    label: l10n.gameOverHits(summary.hits)),
              ),
              const SizedBox(width: PongSpacing.xs),
              Expanded(
                child: PongFigureTile(
                    value: format.duration(summary.duration.inMilliseconds),
                    label: l10n.gameOverDuration),
              ),
              const SizedBox(width: PongSpacing.xs),
              Expanded(
                // Partie record : la place au classement remplace la vitesse
                child: gold && rank != null
                    ? PongFigureTile(
                        value: l10n.rankLabel(rank),
                        label: l10n.gameOverRank,
                        valueColor:
                            PongColors.podium(rank) ?? PongColors.textPrimary,
                      )
                    : PongFigureTile(
                        value: '${summary.maxSpeed}',
                        label: l10n.gameOverTopSpeed),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PongPrimaryButton(
          label: l10n.gameOverReplay,
          icon: Icons.replay_rounded,
          onPressed: () => onAction(GameOverAction.replay),
        ),
        Row(
          children: [
            Expanded(
              child: PongSecondaryButton(
                label: l10n.leaderboardTitle,
                icon: Icons.leaderboard_rounded,
                compact: true,
                onPressed: () => onAction(GameOverAction.leaderboard),
              ),
            ),
            const SizedBox(width: PongSpacing.xs),
            Expanded(
              child: PongSecondaryButton(
                label: l10n.statisticsTitle,
                icon: Icons.bar_chart_rounded,
                compact: true,
                onPressed: () => onAction(GameOverAction.statistics),
              ),
            ),
          ],
        ),
        Center(
          child: PongTextButton(
            label: l10n.gameOverHome,
            onPressed: () => onAction(GameOverAction.home),
          ),
        ),
      ],
    );
  }

  // « points · record 2 400 » ou « points · +250 sur l'ancien record »
  Widget _subtitle(AppLocalizations l10n, PongFormat format) {
    const TextStyle style = PongText.caption;
    if (summary.isNewRecord) {
      final gain = '+${format.number(summary.score - summary.previousRecord)}';
      final parts = splitAround(l10n.gameOverPointsOverRecord, gain);
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: parts.before),
            TextSpan(
              text: gain,
              style: const TextStyle(color: PongColors.record),
            ),
            TextSpan(text: parts.after),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      summary.record > 0
          ? l10n.gameOverPointsWithRecord(format.number(summary.record))
          : l10n.gameOverPoints,
      textAlign: TextAlign.center,
      style: style,
    );
  }
}
