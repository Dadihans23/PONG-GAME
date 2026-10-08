// État vide d'un écran (maquette, écran C2) : pastille ronde en pointillés,
// titre, phrase qui dit quoi faire. L'action (« Jouer ») se place dans le
// `bottomAction` de `PongPageScaffold`, pas ici.
//
// ```dart
// const PongEmptyState(
//   icon: Icons.emoji_events_rounded,
//   title: 'Aucun score enregistré',
//   message: 'Joue une partie solo : tes 10 meilleurs scores apparaîtront ici.',
// )
// ```
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';

class PongEmptyState extends StatelessWidget {
  const PongEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;

  /// Phrase qui dit au joueur comment remplir cet écran.
  final String? message;

  static const double _badgeSize = 88;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: 40, vertical: PongSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: const _DashedCirclePainter(
                fill: PongColors.surface,
                stroke: PongColors.border,
              ),
              child: SizedBox.square(
                dimension: _badgeSize,
                child: Icon(icon, size: 40, color: PongColors.textDisabled),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PongText.headline.copyWith(fontSize: 20),
            ),
            if (message != null) ...[
              const SizedBox(height: PongSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PongText.body.copyWith(
                    fontSize: 14, color: PongColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Disque plein bordé d'un contour en pointillés.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  static const int _dashes = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 0.5;
    canvas.drawCircle(center, radius, Paint()..color = fill);
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 2 * math.pi / _dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}
