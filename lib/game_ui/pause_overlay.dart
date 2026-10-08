import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Voile de pause (maquette P1) : opaque à 80 %, sans flou (coûteux sur
/// entrée de gamme). Le terrain figé reste visible dessous.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.score,
    required this.record,
    required this.onResume,
    required this.onQuit,
  });

  final int score;
  final int record;
  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final String summary = record > 0
        ? 'Score ${PongFormat.number(score)} · Record ${PongFormat.number(record)}'
        : 'Score ${PongFormat.number(score)}';
    return ColoredBox(
      color: PongColors.scrim,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: PongSpacedText(
                    'PAUSE',
                    style: PongText.logo.copyWith(
                      fontSize: 32,
                      letterSpacing: 32 * 0.45,
                      shadows: const [],
                    ),
                  ),
                ),
                const SizedBox(height: PongSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note_rounded,
                        size: 16, color: PongColors.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PongText.caption),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                PongPrimaryButton(
                  label: 'Reprendre',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onResume,
                ),
                const SizedBox(height: PongSpacing.sm),
                PongTextButton(label: 'Quitter la partie', onPressed: onQuit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
