import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_view_data.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'duel_texts.dart';

/// Pastille ronde 44 px avec l'initiale du joueur, teintée de sa couleur
/// (bleu pour moi, vert pour l'autre) : le code couleur du terrain commence
/// dès le salon.
class DuelAvatar extends StatelessWidget {
  const DuelAvatar({
    super.key,
    required this.name,
    required this.side,
    this.muted = false,
  });

  /// Pastille vide en pointillés : la place que l'autre joueur viendra
  /// prendre (salon, hôte seul).
  static const Widget placeholder = _AvatarPlaceholder();

  static const double size = 44;

  final String name;
  final DuelSide side;

  /// Gris, pour une partie pleine.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color background = muted
        ? PongColors.surfaceHigh
        : PongColors.alpha(side.color, side == DuelSide.me ? 0.18 : 0.16);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          DuelTexts.initial(name),
          style: PongText.figure.copyWith(
            color: muted ? PongColors.textTertiary : side.lightColor,
          ),
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: DuelAvatar.size,
      child: CustomPaint(painter: DashedOutlinePainter.circle()),
    );
  }
}

/// Contour en pointillés d'un rectangle arrondi ou d'un cercle : place vide
/// du salon.
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({
    this.radius = PongRadii.card,
    this.color = PongColors.border,
    this.strokeWidth = 1.5,
  }) : _circle = false;

  const DashedOutlinePainter.circle({
    this.color = PongColors.faint,
    this.strokeWidth = 1.5,
  })  : radius = 0,
        _circle = true;

  final double radius;
  final Color color;
  final double strokeWidth;
  final bool _circle;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path();
    if (_circle) {
      path.addOval(rect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      // Pointillés répartis régulièrement sur tout le tour
      final int count = math.max(1, (metric.length / (_dash + _gap)).floor());
      final double step = metric.length / count;
      for (var i = 0; i < count; i++) {
        final double start = i * step;
        canvas.drawPath(
            metric.extractPath(start, start + step * _dash / (_dash + _gap)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate._circle != _circle;
}
