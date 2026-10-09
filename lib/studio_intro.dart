import 'package:flutter/material.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Intro du studio, avant l'écran de chargement : le logo blanc centré sur
/// noir pur, en fondu d'entrée et de sortie ([duration] au total).
///
/// Un toucher n'importe où la passe. Silencieuse : le jingle de chargement
/// démarre avec la barre, qu'il accompagne du début à la fin. Avec la
/// réduction des animations du système, le logo s'affiche sans fondu.
class StudioIntro extends StatefulWidget {
  const StudioIntro({super.key, required this.next});

  /// Écran suivant (le chargement), qui remplace l'intro.
  final WidgetBuilder next;

  static const Duration fadeIn = Duration(milliseconds: 400);
  static const Duration hold = Duration(milliseconds: 700);
  static const Duration fadeOut = Duration(milliseconds: 400);

  /// Durée totale de l'intro.
  static const Duration duration = Duration(milliseconds: 1500);

  /// Fondu vers l'écran suivant (compté dans la durée du chargement).
  static const Duration transition = Duration(milliseconds: 250);

  @override
  State<StudioIntro> createState() => _StudioIntroState();
}

class _StudioIntroState extends State<StudioIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: StudioIntro.duration);

  /// Opacité du logo : 0 → 1, tenue, 1 → 0, en proportion des durées.
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: StudioIntro.fadeIn.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: ConstantTween(1.0),
      weight: StudioIntro.hold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: StudioIntro.fadeOut.inMilliseconds.toDouble(),
    ),
  ]).animate(_controller);

  bool _left = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leave();
    });
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Logo prêt avant la fin du fondu d'entrée
    precacheImage(const AssetImage(Brand.logoLight), context);
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    _controller.stop();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (context, _, __) => widget.next(context),
      transitionDuration:
          reduceMotion ? Duration.zero : StudioIntro.transition,
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Logo à 56 % de la largeur, entre 160 et 260 dp
    final width =
        (MediaQuery.sizeOf(context).width * 0.56).clamp(160.0, 260.0);
    final Widget logo = Image.asset(
      Brand.logoLight,
      width: width,
      height: width / Brand.logoLightAspectRatio,
      filterQuality: FilterQuality.medium,
      semanticLabel: Brand.studioName,
    );
    return Scaffold(
      backgroundColor: PongColors.black,
      body: Semantics(
        onTapHint: 'Passer',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: Center(
            child: reduceMotion
                ? logo
                : FadeTransition(
                    opacity: _opacity,
                    // Le logo reste annoncé par le lecteur d'écran pendant le fondu
                    alwaysIncludeSemantics: true,
                    child: logo,
                  ),
          ),
        ),
      ),
    );
  }
}
