import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Compte à rebours plein écran (maquette L4) : « LÉA CONTRE TOM », le
/// chiffre dans un anneau rose, et ce qu'il faut faire pendant ces trois
/// secondes : prendre le téléphone à deux mains.
///
/// Chaque nouveau chiffre arrive avec un léger rebond, qui marque la
/// seconde sans rien ajouter à lire.
class DuelCountdownOverlay extends StatelessWidget {
  const DuelCountdownOverlay({
    super.key,
    required this.value,
    required this.myName,
    required this.opponentName,
  });

  final int value;
  final String myName;
  final String opponentName;

  static const double _ringSize = 180;

  @override
  Widget build(BuildContext context) {
    final TextStyle namesStyle = PongText.hudLabel.copyWith(
      fontSize: 12,
      letterSpacing: 12 * 0.3,
      color: PongColors.textSecondary,
    );
    // Material transparent : l'overlay peut se poser hors d'un Scaffold
    // (au-dessus du salon) sans le style de texte « sans Material »
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: const Color(0xD1050508), // #050508 à 82 %
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: PongSpacing.screen, vertical: PongSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Moi en bleu, l'autre en vert : les couleurs du terrain
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: myName.toUpperCase(),
                            style:
                                const TextStyle(color: PongColors.playerLight)),
                        const TextSpan(
                            text: '  CONTRE  ',
                            style: TextStyle(color: PongColors.textDisabled)),
                        TextSpan(
                            text: opponentName.toUpperCase(),
                            style: const TextStyle(
                                color: PongColors.opponentLight)),
                      ]),
                      maxLines: 1,
                      style: namesStyle,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: _ringSize,
                    height: _ringSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: PongColors.pink, width: 2),
                      boxShadow: PongShadows.glow(PongColors.pink,
                          opacity: 0.45, blur: 40),
                      // Lueur intérieure (« inset » de la maquette) : le
                      // centre reste opaque pour que le halo extérieur, peint
                      // sous l'anneau, ne transparaisse pas
                      gradient: const RadialGradient(
                        colors: [
                          PongColors.background,
                          PongColors.background,
                          PongColors.pinkTintSolid,
                        ],
                        stops: [0, 0.72, 1],
                      ),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 1.25, end: 1).animate(
                                CurvedAnimation(
                                    parent: animation, curve: Curves.easeOut)),
                            child: child,
                          ),
                        ),
                        child: Text(
                          '$value',
                          key: ValueKey(value),
                          style: PongText.gameScore.copyWith(
                            fontSize: 104,
                            color: PongColors.textPrimary,
                            shadows: [
                              Shadow(
                                  color: PongColors.alpha(PongColors.pink, 0.6),
                                  blurRadius: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PongSpacedText(
                      'PRENDS TON TÉLÉPHONE',
                      style: PongText.screenTitle.copyWith(
                        fontSize: 14,
                        letterSpacing: 14 * 0.3,
                        color: PongColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.screen_rotation_rounded,
                          size: 18, color: PongColors.textSecondary),
                      SizedBox(width: PongSpacing.xs),
                      Flexible(
                        child: Text('À deux mains, prêt à incliner',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PongText.caption),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
