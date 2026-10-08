import 'package:flutter/material.dart';
import 'package:pong_game/multiplayer/widgets/duel_texts.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'multiplayer_view_data.dart';

/// Fin du duel, en plein écran (maquettes V1 et V2) : c'est la conclusion
/// d'un duel, elle mérite la place d'un écran plutôt qu'un dialogue.
///
/// « VICTOIRE » est le seul titre de l'app avec un halo rose. Sous le score,
/// la durée et le plus long échange (victoire) ou un mot d'encouragement
/// (défaite). En bas, la revanche selon [DuelResultData.rematch] :
///
/// - `none` : « Rejouer » en rose ;
/// - `iAsked` : bouton en attente « En attente de Tom… » et la ligne
///   « Tu veux rejouer · Tom n'a pas encore répondu » ;
/// - `opponentAsked` : « Tom veut rejouer » et « Rejouer » en rose ;
/// - `opponentLeft` : « Tom a quitté la partie », « Rejouer » inactif.
class DuelResultScreen extends StatelessWidget {
  const DuelResultScreen({
    super.key,
    required this.result,
    required this.onRematch,
    required this.onQuit,
    this.onCancelRematch,
  });

  final DuelResultData result;

  /// « Rejouer » : demander (ou accepter) la revanche.
  final VoidCallback onRematch;

  /// Toucher le bouton en attente : retirer sa demande. `null` = inerte.
  final VoidCallback? onCancelRematch;

  /// « Quitter », ou retour Android.
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final bool won = result.won;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onQuit();
      },
      child: Scaffold(
        backgroundColor: PongColors.background,
        body: Stack(
          children: [
            if (won)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 360,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.4),
                      radius: 0.9,
                      colors: [Color(0x38E91E63), Color(0x00E91E63)],
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: PongSpacing.screen,
                            vertical: PongSpacing.lg),
                        child: _Summary(result: result),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(PongSpacing.screen, 0,
                        PongSpacing.screen, PongSpacing.screen),
                    child: _RematchActions(
                      result: result,
                      onRematch: onRematch,
                      onCancelRematch: onCancelRematch,
                      onQuit: onQuit,
                    ),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final DuelResultData result;

  @override
  Widget build(BuildContext context) {
    final bool won = result.won;
    final TextStyle titleStyle = PongText.logo.copyWith(
      letterSpacing: 40 * 0.4,
      color: won ? PongColors.textPrimary : PongColors.textTitle,
      shadows: won
          ? [
              Shadow(
                  color: PongColors.alpha(PongColors.pink, 0.7), blurRadius: 28)
            ]
          : const [],
    );
    final String detail;
    if (won) {
      detail = '${PongFormat.duration(result.duration.inMilliseconds)} · '
          'plus long échange : '
          '${PongFormat.count(result.longestRally, 'renvoi', 'renvois')}';
    } else {
      // Défaite serrée : on encourage la revanche
      detail = result.opponentScore - result.myScore <= 2
          ? 'Si près ! La revanche ?'
          : 'La revanche ?';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child:
                PongSpacedText(won ? 'VICTOIRE' : 'DÉFAITE', style: titleStyle),
          ),
        ),
        const SizedBox(height: PongSpacing.sm),
        Text(
          '${result.winnerName} gagne !',
          textAlign: TextAlign.center,
          maxLines: 2,
          style: PongText.cardTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PongColors.textBody),
        ),
        const SizedBox(height: 52),
        Semantics(
          label: '${result.myName} ${result.myScore}, '
              '${result.opponentName} ${result.opponentScore}',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinalScore(
                score: result.myScore,
                name: result.myName,
                side: DuelSide.me,
                winner: won,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PongSpacing.lg),
                child: Text('–',
                    style: PongText.gameScore.copyWith(
                        fontSize: 40, color: PongColors.faint, height: 1.8)),
              ),
              _FinalScore(
                score: result.opponentScore,
                name: result.opponentName,
                side: DuelSide.opponent,
                winner: !won,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(detail,
            textAlign: TextAlign.center,
            style: PongText.caption.copyWith(fontWeight: FontWeight.w400)),
      ],
    );
  }
}

/// Score final d'un joueur : chiffre dans sa couleur (halo pour le
/// gagnant, estompé pour le perdant) et pseudo dessous.
class _FinalScore extends StatelessWidget {
  const _FinalScore({
    required this.score,
    required this.name,
    required this.side,
    required this.winner,
  });

  final int score;
  final String name;
  final DuelSide side;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Text(
            '$score',
            style: PongText.gameScore.copyWith(
              fontSize: 72,
              color: winner
                  ? side.lightColor
                  : PongColors.alpha(side.lightColor, 0.6),
              shadows: winner
                  ? [
                      Shadow(
                          color: PongColors.alpha(side.color, 0.45),
                          blurRadius: 24),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: PongSpacing.xs),
          Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: PongText.hudLabel.copyWith(color: PongColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RematchActions extends StatelessWidget {
  const _RematchActions({
    required this.result,
    required this.onRematch,
    required this.onCancelRematch,
    required this.onQuit,
  });

  final DuelResultData result;
  final VoidCallback onRematch;
  final VoidCallback? onCancelRematch;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final String other = result.opponentName;
    final String? status = switch (result.rematch) {
      RematchState.none => null,
      RematchState.iAsked => "Tu veux rejouer · $other n'a pas encore répondu",
      RematchState.opponentAsked => '$other veut rejouer',
      RematchState.opponentLeft => '$other a quitté la partie',
    };
    final Color dotColor = switch (result.rematch) {
      RematchState.opponentAsked => PongColors.pink,
      RematchState.opponentLeft => PongColors.textDisabled,
      _ => PongColors.success,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null) ...[
          Semantics(
            liveRegion: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: PongSpacing.xs),
                  Flexible(
                    child: Text(status,
                        textAlign: TextAlign.center,
                        style: PongText.caption
                            .copyWith(fontWeight: FontWeight.w400)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PongSpacing.xs),
        ],
        AnimatedSwitcher(
          duration: PongDurations.normal,
          child: result.rematch == RematchState.iAsked
              ? PongPendingButton(
                  key: const ValueKey('pending'),
                  label: DuelTexts.waitingFor(other),
                  onPressed: onCancelRematch,
                )
              : PongPrimaryButton(
                  key: const ValueKey('rematch'),
                  label: 'Rejouer',
                  icon: Icons.replay_rounded,
                  onPressed: result.rematch == RematchState.opponentLeft
                      ? null
                      : onRematch,
                ),
        ),
        const SizedBox(height: PongSpacing.xs),
        PongTextButton(label: 'Quitter', onPressed: onQuit),
      ],
    );
  }
}
