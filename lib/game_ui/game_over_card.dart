import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Rang au classement : 1 → « 1er », 2 → « 2e ». Lettres normales : Archivo
/// n'a pas les exposants « ᵉʳ ».
String formatRank(int rank) => rank == 1 ? '1er' : '${rank}e';

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
    return PongDialogCard(
      accentColor: gold ? PongColors.record : null,
      padding: const EdgeInsets.fromLTRB(
          PongSpacing.screen, 28, PongSpacing.screen, PongSpacing.sm),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gold)
            // Réduite plutôt que coupée si la police système est très grande
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: PongPill.signal(
                label: 'Nouveau record !',
                color: PongColors.record,
                icon: Icons.star_rounded,
              ),
            )
          else
            PongSpacedText(
              'PARTIE TERMINÉE',
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
              PongFormat.number(summary.score),
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
          _subtitle(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child:
                    PongFigureTile(value: '${summary.hits}', label: 'renvois'),
              ),
              const SizedBox(width: PongSpacing.xs),
              Expanded(
                child: PongFigureTile(
                    value: PongFormat.duration(summary.duration.inMilliseconds),
                    label: 'durée'),
              ),
              const SizedBox(width: PongSpacing.xs),
              Expanded(
                // Partie record : la place au classement remplace la vitesse
                child: gold && rank != null
                    ? PongFigureTile(
                        value: formatRank(rank),
                        label: 'classement',
                        valueColor:
                            PongColors.podium(rank) ?? PongColors.textPrimary,
                      )
                    : PongFigureTile(
                        value: '${summary.maxSpeed}', label: 'vitesse max'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PongPrimaryButton(
          label: 'Rejouer',
          icon: Icons.replay_rounded,
          onPressed: () => onAction(GameOverAction.replay),
        ),
        Row(
          children: [
            Expanded(
              child: PongSecondaryButton(
                label: 'Classement',
                icon: Icons.leaderboard_rounded,
                compact: true,
                onPressed: () => onAction(GameOverAction.leaderboard),
              ),
            ),
            const SizedBox(width: PongSpacing.xs),
            Expanded(
              child: PongSecondaryButton(
                label: 'Statistiques',
                icon: Icons.bar_chart_rounded,
                compact: true,
                onPressed: () => onAction(GameOverAction.statistics),
              ),
            ),
          ],
        ),
        Center(
          child: PongTextButton(
            label: "Retour à l'accueil",
            onPressed: () => onAction(GameOverAction.home),
          ),
        ),
      ],
    );
  }

  // « points · record 2 400 » ou « points · +250 sur l'ancien record »
  Widget _subtitle() {
    const TextStyle style = PongText.caption;
    if (summary.isNewRecord) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'points · '),
            TextSpan(
              text:
                  '+${PongFormat.number(summary.score - summary.previousRecord)}',
              style: const TextStyle(color: PongColors.record),
            ),
            const TextSpan(text: " sur l'ancien record"),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      summary.record > 0
          ? 'points · record ${PongFormat.number(summary.record)}'
          : 'points',
      textAlign: TextAlign.center,
      style: style,
    );
  }
}
