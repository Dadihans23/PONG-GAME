import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Ondes roses autour d'une pastille « capteur » (maquettes J1 et L1) : on
/// comprend « je cherche autour de moi » ou « je suis visible » sans un mot
/// technique.
///
/// Les ondes partent de la pastille, s'élargissent et s'effacent en boucle.
/// Arrêtées (`animate: false`, ou animations coupées dans les réglages
/// d'accessibilité du téléphone), elles restent dessinées en anneaux fixes,
/// comme dans la maquette.
class DuelRadar extends StatefulWidget {
  const DuelRadar({
    super.key,
    this.size = 240,
    this.rings = 3,
    this.animate = true,
    this.badgeSize = 56,
  });

  /// Diamètre de l'onde la plus large.
  final double size;

  /// Nombre d'ondes (3 en recherche, 2 dans le salon).
  final int rings;
  final bool animate;

  /// Diamètre de la pastille centrale ; 0 = icône seule (salon).
  final double badgeSize;

  /// Durée d'un cycle : une onde va de la pastille au bord.
  static const Duration period = Duration(milliseconds: 2400);

  @override
  State<DuelRadar> createState() => _DuelRadarState();
}

class _DuelRadarState extends State<DuelRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DuelRadar.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DuelRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  bool get _running =>
      widget.animate && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_running) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double badge = widget.badgeSize;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _WavesPainter(
            progress: _controller,
            rings: widget.rings,
            innerRadius: badge > 0 ? badge / 2 : widget.size * 0.2,
            moving: _running,
          ),
          child: Center(
            child: badge > 0
                ? Container(
                    width: badge,
                    height: badge,
                    decoration: const BoxDecoration(
                      color: PongColors.pinkBadge,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sensors_rounded,
                        size: badge / 2, color: PongColors.pinkLight),
                  )
                : const Icon(Icons.sensors_rounded,
                    size: 28, color: PongColors.pinkLight),
          ),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter({
    required this.progress,
    required this.rings,
    required this.innerRadius,
    required this.moving,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final int rings;
  final double innerRadius;
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final double outer = size.shortestSide / 2 - 1;
    for (var i = 0; i < rings; i++) {
      // Position de l'onde entre la pastille (0) et le bord (1). Fixes,
      // les anneaux sont répartis régulièrement, comme dans la maquette
      final double t =
          moving ? (progress.value + i / rings) % 1 : (i + 1) / rings;
      final double radius = innerRadius + (outer - innerRadius) * t;
      // Plus l'onde s'éloigne, plus elle s'efface (40 % → 8 %)
      final double opacity = 0.4 - 0.32 * t;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = t < 0.4 ? 1.5 : 1
        ..color = PongColors.alpha(PongColors.pink, opacity);
      canvas.drawCircle(center, radius, paint);
    }
    // Halo doux autour de la pastille
    canvas.drawCircle(
      center,
      innerRadius + 8,
      Paint()
        ..color = PongColors.alpha(PongColors.pink, 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(_WavesPainter oldDelegate) =>
      oldDelegate.rings != rings ||
      oldDelegate.innerRadius != innerRadius ||
      oldDelegate.moving != moving;
}
