import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pong_game/game/pong_engine.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Effets passagers du terrain, calculés par l'écran de jeu à chaque image.
class CourtEffects {
  const CourtEffects({
    this.gold = 0,
    this.paddleFlash = false,
    this.popupProgress,
    this.popupX = 0,
  });

  /// Part de l'or sur le cadre, la ligne médiane et le score (0 à 1) :
  /// 1 au moment où le record tombe, puis retour au blanc.
  final double gold;

  /// La raquette du joueur vient de renvoyer la balle.
  final bool paddleFlash;

  /// Avancement du « +50 » qui monte au-dessus de la raquette (0 à 1),
  /// `null` s'il n'y en a pas.
  final double? popupProgress;

  /// Position X (coordonnées du moteur) de la raquette au moment du renvoi.
  final double popupX;
}

/// Le terrain (maquette G1, G2, G3) : cadre et ligne médiane discrets, score
/// « fantôme », raquettes et balle.
///
/// Les coordonnées du moteur (-1 à 1) couvrent exactement ce terrain : la
/// balle et les raquettes y sont placées avec `Alignment`, comme avant sur le
/// plein écran. Tout ce qui est texte est dessiné SOUS les raquettes et la
/// balle, et jamais plus lumineux qu'elles.
class GameCourt extends StatelessWidget {
  const GameCourt({
    super.key,
    required this.engine,
    required this.hasStarted,
    required this.isLive,
    required this.playerName,
    required this.record,
    required this.recordBeaten,
    this.effects = const CourtEffects(),
  });

  /// Marges du terrain dans l'écran : 12 px sur les côtés, 16 px en bas
  /// (la bande de HUD est au-dessus).
  static const double sideMargin = 12;
  static const double bottomMargin = 16;

  /// Position verticale des raquettes, en coordonnées du moteur.
  static const double enemyY = -0.9;
  static const double playerY = 0.9;

  final PongEngine engine;

  /// La partie a commencé (premier tap fait).
  final bool hasStarted;

  /// La partie tourne : ni pause, ni défaite. Les halos ne sont allumés
  /// que dans ce cas, comme dans la maquette.
  final bool isLive;
  final String playerName;

  /// Meilleur score d'avant la partie (« RECORD 2 400 »), masqué s'il vaut 0.
  final int record;

  /// Le record a été battu pendant cette partie : la pastille
  /// « Nouveau record » remplace la ligne « RECORD ».
  final bool recordBeaten;
  final CourtEffects effects;

  @override
  Widget build(BuildContext context) {
    final bool dead = engine.isPlayerDead;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Décor : ne se repeint que s'il change (score, or)
            Positioned.fill(
              child: RepaintBoundary(
                child: _CourtBackground(
                  hasStarted: hasStarted,
                  score: engine.playerScore,
                  playerName: playerName,
                  record: record,
                  recordBeaten: recordBeaten,
                  gold: effects.gold,
                  finishedWithRecord: dead && recordBeaten,
                ),
              ),
            ),
            if (!hasStarted) _StartPrompt(record: record),
            if (effects.popupProgress != null)
              _ScorePopup(
                progress: effects.popupProgress!,
                left: _paddleLeft(effects.popupX, width),
                paddleTop:
                    (playerY + 1) / 2 * (height - PongSizes.paddleHeight),
              ),
            _Paddle(
              x: engine.enemyX,
              y: enemyY,
              color: PongColors.opponent,
              shadows: isLive ? PongShadows.opponentPaddle : null,
            ),
            _Paddle(
              x: engine.playerX,
              y: playerY,
              color: PongColors.player,
              shadows: !isLive
                  ? null
                  : effects.paddleFlash
                      ? PongShadows.playerPaddleFlash
                      : PongShadows.playerPaddle,
            ),
            // Balle cachée après la défaite (maquette E1)
            if (!dead)
              _Ball(
                x: engine.ballX,
                y: engine.ballY,
                glow: isLive || !hasStarted,
              ),
          ],
        );
      },
    );
  }

  // Bord gauche de la raquette en pixels, pour une position X du moteur
  static double _paddleLeft(double x, double courtWidth) =>
      (x + 1) / 2 * (courtWidth - PongSizes.paddleWidth);
}

/// Cadre, ligne médiane, score fantôme, pseudo et record.
class _CourtBackground extends StatelessWidget {
  const _CourtBackground({
    required this.hasStarted,
    required this.score,
    required this.playerName,
    required this.record,
    required this.recordBeaten,
    required this.gold,
    required this.finishedWithRecord,
  });

  final bool hasStarted;
  final int score;
  final String playerName;
  final int record;
  final bool recordBeaten;
  final double gold;
  final bool finishedWithRecord;

  @override
  Widget build(BuildContext context) {
    final Color frameColor = finishedWithRecord
        ? PongColors.alpha(PongColors.record, 0.2)
        : Color.lerp(PongColors.courtLine,
            PongColors.alpha(PongColors.record, 0.3), gold)!;
    final Color midlineColor = Color.lerp(PongColors.courtMidline,
        PongColors.alpha(PongColors.record, 0.35), gold)!;
    final Color scoreColor = Color.lerp(
        PongColors.ghostScore, PongColors.alpha(PongColors.record, 0.5), gold)!;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: PongRadii.cardAll,
              border: Border.all(color: frameColor),
            ),
          ),
        ),
        // Ligne médiane en tirets de 12 px
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: 2,
            width: double.infinity,
            child: CustomPaint(painter: _DashedLinePainter(midlineColor)),
          ),
        ),
        if (hasStarted) ...[
          // Au-dessus de la ligne médiane : record, ou pastille de nouveau record
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: Align(
              alignment: Alignment.center,
              child: FractionalTranslation(
                translation: const Offset(0, -1),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: recordBeaten
                      ? const PongPill.signal(
                          label: 'Nouveau record',
                          color: PongColors.record,
                          icon: Icons.star_rounded,
                        )
                      : record > 0
                          ? PongSpacedText(
                              'RECORD ${PongFormat.number(record)}',
                              style: PongText.hudLabel)
                          : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          // Sous la ligne médiane : score fantôme et pseudo
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: FractionalTranslation(
                translation: const Offset(0, 0.5),
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 20, left: PongSpacing.lg, right: PongSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        PongFormat.number(score),
                        maxLines: 1,
                        style: PongText.gameScore.copyWith(
                          color: scoreColor,
                          shadows: gold > 0
                              ? [
                                  Shadow(
                                    color: PongColors.alpha(
                                        PongColors.record, 0.3 * gold),
                                    blurRadius: 24,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PongSpacedText(playerName.toUpperCase(),
                          style: PongText.hudLabel),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Avant le premier tap : anneaux autour de la balle, consigne et record.
class _StartPrompt extends StatelessWidget {
  const _StartPrompt({required this.record});

  final int record;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: PongColors.alpha(PongColors.ball, 0.06)),
            ),
          ),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: PongColors.alpha(PongColors.ball, 0.14)),
              boxShadow:
                  PongShadows.glow(PongColors.ball, opacity: 0.08, blur: 30),
            ),
          ),
          // Consigne sous les anneaux
          FractionalTranslation(
            translation: const Offset(0, 0.5),
            child: Padding(
              padding: const EdgeInsets.only(top: 104),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PongSpacedText(
                    "TAPE L'ÉCRAN",
                    style: PongText.screenTitle.copyWith(
                      fontSize: 20,
                      letterSpacing: 20 * 0.4,
                      color: PongColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.screen_rotation_rounded,
                          size: 18, color: PongColors.textSecondary),
                      SizedBox(width: PongSpacing.xs),
                      Flexible(
                        child: Text('Incline le téléphone pour bouger',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PongText.caption),
                      ),
                    ],
                  ),
                  if (record > 0) ...[
                    const SizedBox(height: PongSpacing.xl),
                    PongSpacedText('RECORD ${PongFormat.number(record)}',
                        style: PongText.hudLabel),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « +50 » bleu qui monte et s'efface au-dessus de la raquette du joueur.
class _ScorePopup extends StatelessWidget {
  const _ScorePopup({
    required this.progress,
    required this.left,
    required this.paddleTop,
  });

  // Distance de montée et position de départ au-dessus de la raquette
  static const double rise = 28;
  static const double startAbovePaddle = 34;

  final double progress;
  final double left;
  final double paddleTop;

  @override
  Widget build(BuildContext context) {
    final double eased = Curves.easeOut.transform(progress);
    // Pleinement visible au début, s'efface sur la seconde moitié
    final double opacity =
        (1 - math.max(0.0, progress - 0.5) * 2).clamp(0.0, 1.0);
    return Positioned(
      left: left + 4,
      top: paddleTop - startAbovePaddle - rise * eased,
      child: IgnorePointer(
        child: Text(
          '+50',
          style: PongText.figure.copyWith(
            fontSize: 14,
            color: PongColors.alpha(PongColors.playerLight, opacity),
          ),
        ),
      ),
    );
  }
}

class _Paddle extends StatelessWidget {
  const _Paddle({
    required this.x,
    required this.y,
    required this.color,
    this.shadows,
  });

  final double x;
  final double y;
  final Color color;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(x, y),
      child: Container(
        width: PongSizes.paddleWidth,
        height: PongSizes.paddleHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(PongSizes.paddleHeight / 2),
          boxShadow: shadows,
        ),
      ),
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball({required this.x, required this.y, required this.glow});

  final double x;
  final double y;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(x, y),
      child: Container(
        width: PongSizes.ball,
        height: PongSizes.ball,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PongColors.ball,
          boxShadow: glow ? PongShadows.ball : null,
        ),
      ),
    );
  }
}

/// Ligne en tirets : 12 px pleins, 12 px vides.
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  static const double dash = 12;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += dash * 2) {
      canvas.drawRect(
          Rect.fromLTWH(x, 0, math.min(dash, size.width - x), size.height),
          paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
