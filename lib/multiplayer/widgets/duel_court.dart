// Terrain du duel (maquettes D1 et D2).
//
// Pourquoi pas `GameCourt` (lib/game_ui/game_court.dart) ? Ce widget est
// taillé pour le solo : il lit un `PongEngine`, affiche le score solo, le
// pseudo, le record et la consigne « Tape l'écran », et dessine des
// raquettes de 80 px fixes. Le duel a deux scores, aucun record, et une
// raquette proportionnelle au terrain (0,27 × sa largeur, pour que la
// raquette dessinée corresponde à la zone de contact du moteur sur deux
// téléphones de tailles différentes). Ses pièces (raquette, balle, ligne
// médiane) sont privées et `GameCourt` ne doit pas changer pendant le
// duel : ce fichier en reprend donc exactement le rendu (mêmes jetons
// `PongColors`, `PongShadows`, `PongSizes`, mêmes positions
// `GameCourt.enemyY` / `playerY`, même cadre et même ligne en tirets de
// 12 px). Si le solo adopte un jour ces pièces, elles pourront passer
// dans `lib/ui/`.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pong_game/game_ui/game_court.dart';
import 'package:pong_game/multiplayer/screens/multiplayer_view_data.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Le terrain du duel : cadre, ligne médiane, scores de chaque côté (D1) ou
/// annonce du point (D2), raquettes et balle.
///
/// Tout ce qui est texte est dessiné SOUS les raquettes et la balle, et
/// jamais plus lumineux qu'elles pendant le jeu.
class DuelCourt extends StatelessWidget {
  const DuelCourt({
    super.key,
    required this.hud,
    required this.field,
    this.point,
  });

  /// Largeur de la raquette dessinée, en part de la largeur du terrain :
  /// elle correspond à la zone de contact du moteur du duel.
  static const double paddleWidthFactor = 0.27;

  final DuelHudData hud;
  final DuelFieldData field;

  /// Point qui vient d'être marqué : annonce au centre, sans balle.
  final DuelPointData? point;

  @override
  Widget build(BuildContext context) {
    final DuelPointData? point = this.point;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double paddleWidth = constraints.maxWidth * paddleWidthFactor;
        final DuelSide? loser = point?.scorer.other;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Décor : ne se repeint que s'il change (score, point marqué)
            Positioned.fill(
              child: RepaintBoundary(
                child: _CourtBackground(hud: hud, point: point),
              ),
            ),
            _CourtPaddle(
              x: field.opponentPaddleX,
              y: GameCourt.enemyY,
              width: paddleWidth,
              side: DuelSide.opponent,
              dimmed: loser == DuelSide.opponent,
            ),
            _CourtPaddle(
              x: field.myPaddleX,
              y: GameCourt.playerY,
              width: paddleWidth,
              side: DuelSide.me,
              dimmed: loser == DuelSide.me,
            ),
            // Pas de balle pendant l'annonce du point
            if (point == null) _CourtBall(x: field.ballX, y: field.ballY),
          ],
        );
      },
    );
  }
}

class _CourtBackground extends StatelessWidget {
  const _CourtBackground({required this.hud, required this.point});

  final DuelHudData hud;
  final DuelPointData? point;

  @override
  Widget build(BuildContext context) {
    final DuelPointData? point = this.point;
    // Le halo vient du bord où la balle est sortie (celui du perdant du
    // point), dans la couleur du gagnant
    final Gradient? halo = point == null
        ? null
        : LinearGradient(
            begin: point.scorer == DuelSide.me
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            end: point.scorer == DuelSide.me
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            colors: [
              PongColors.alpha(point.scorer.color, 0.14),
              PongColors.alpha(point.scorer.color, 0),
            ],
            stops: const [0, 0.4],
          );
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: PongDurations.normal,
            decoration: BoxDecoration(
              borderRadius: PongRadii.cardAll,
              border: Border.all(color: PongColors.courtLine),
              gradient: halo,
            ),
          ),
        ),
        // Ligne médiane en tirets de 12 px
        const Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: 2,
            width: double.infinity,
            child: CustomPaint(
                painter: _DashedLinePainter(PongColors.courtMidline)),
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: PongDurations.normal,
            child: point == null
                ? _GhostScores(key: const ValueKey('scores'), hud: hud)
                : _PointPanel(
                    key: ValueKey('point-${point.scorer.name}'),
                    hud: hud,
                    point: point,
                  ),
          ),
        ),
      ],
    );
  }
}

/// D1 : chaque score du côté de son joueur, teinté de sa couleur, avec les
/// barres « premier à 5 ». L'adversaire au-dessus de la ligne médiane, moi
/// en dessous.
class _GhostScores extends StatelessWidget {
  const _GhostScores({super.key, required this.hud});

  final DuelHudData hud;

  // Écart entre un bloc de score et la ligne médiane
  static const double _gap = 18;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${hud.myName} ${hud.myScore}, '
          '${hud.opponentName} ${hud.opponentScore}',
      excludeSemantics: true,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NameAndBars(hud: hud, side: DuelSide.opponent),
                    const SizedBox(height: 6),
                    _GhostScore(hud: hud, side: DuelSide.opponent),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: const Offset(0, 0.5),
              child: Padding(
                padding: const EdgeInsets.only(top: _gap),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GhostScore(hud: hud, side: DuelSide.me),
                    const SizedBox(height: 6),
                    _NameAndBars(hud: hud, side: DuelSide.me),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostScore extends StatelessWidget {
  const _GhostScore({required this.hud, required this.side});

  final DuelHudData hud;
  final DuelSide side;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${hud.scoreOf(side)}',
      style: PongText.gameScore.copyWith(
        color:
            PongColors.alpha(side.lightColor, side == DuelSide.me ? 0.3 : 0.28),
      ),
    );
  }
}

class _NameAndBars extends StatelessWidget {
  const _NameAndBars({required this.hud, required this.side});

  final DuelHudData hud;
  final DuelSide side;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            hud.nameOf(side).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PongText.hudLabel,
          ),
        ),
        const SizedBox(width: 10),
        PongBarGauge(
          filled: math.min(hud.scoreOf(side), hud.targetScore),
          count: hud.targetScore,
          color: PongColors.alpha(side.color, side == DuelSide.me ? 0.8 : 0.7),
          barWidth: 12,
          barHeight: 5,
          gap: 4,
        ),
      ],
    );
  }
}

/// D2 : « POINT POUR LÉA », le score en clair au premier plan, « Reprise
/// dans 2… ». Le score repose sur la ligne médiane, les noms dessous.
class _PointPanel extends StatelessWidget {
  const _PointPanel({super.key, required this.hud, required this.point});

  final DuelHudData hud;
  final DuelPointData point;

  @override
  Widget build(BuildContext context) {
    final DuelSide scorer = point.scorer;
    final int? resumeIn = point.resumeIn;
    final TextStyle scoreStyle = PongText.gameScore.copyWith(fontSize: 72);

    TextStyle scoreFor(DuelSide side) => side == scorer
        ? scoreStyle.copyWith(
            color: side.lightColor,
            shadows: [
              Shadow(color: PongColors.alpha(side.color, 0.5), blurRadius: 24),
            ],
          )
        : scoreStyle.copyWith(color: side.lightColor);

    return Semantics(
      liveRegion: true,
      label: 'Point pour ${hud.nameOf(scorer)}. '
          '${hud.myName} ${hud.myScore}, '
          '${hud.opponentName} ${hud.opponentScore}',
      excludeSemantics: true,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PongSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PointPill(
                        label: 'Point pour ${hud.nameOf(scorer)}',
                        color: scorer.color,
                        textColor: scorer == DuelSide.me
                            ? PongColors.playerFlash
                            : PongColors.opponentLight),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScoreCell(
                            child: Text('${hud.myScore}',
                                style: scoreFor(DuelSide.me))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('–',
                              style: scoreStyle.copyWith(
                                  fontSize: 48, color: PongColors.faint)),
                        ),
                        _ScoreCell(
                            child: Text('${hud.opponentScore}',
                                style: scoreFor(DuelSide.opponent))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: FractionalTranslation(
              translation: const Offset(0, 0.5),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScoreCell(child: _name(hud.myName)),
                        const SizedBox(width: 56),
                        _ScoreCell(child: _name(hud.opponentName)),
                      ],
                    ),
                    if (resumeIn != null) ...[
                      const SizedBox(height: 44),
                      Text('Reprise dans $resumeIn…',
                          style: PongText.caption
                              .copyWith(fontWeight: FontWeight.w400)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _name(String name) => Text(
        name.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: PongText.hudLabel,
      );
}

/// Colonne de largeur fixe : chaque nom reste sous son chiffre, même avec
/// des pseudos de longueurs différentes.
class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 96, child: Center(child: child));
}

/// Pastille d'annonce du point : celle de `PongPill.signal`, agrandie
/// (36 px, texte 13) parce qu'elle est le message principal de l'écran.
class _PointPill extends StatelessWidget {
  const _PointPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.md),
      decoration: BoxDecoration(
        color: PongColors.alpha(color, 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PongColors.alpha(color, 0.55)),
        boxShadow: PongShadows.glow(color, opacity: 0.3, blur: 24),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Center(
          widthFactor: 1,
          child: PongSpacedText(
            label.toUpperCase(),
            style: PongText.pillLabel.copyWith(
              fontSize: 13,
              letterSpacing: 13 * 0.2,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Raquette : couleur du joueur et son halo ; estompée (50 %, sans halo)
/// pour le perdant du point pendant l'annonce.
class _CourtPaddle extends StatelessWidget {
  const _CourtPaddle({
    required this.x,
    required this.y,
    required this.width,
    required this.side,
    required this.dimmed,
  });

  final double x;
  final double y;
  final double width;
  final DuelSide side;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(x, y),
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Container(
          width: width,
          height: PongSizes.paddleHeight,
          decoration: BoxDecoration(
            color: side.color,
            borderRadius: BorderRadius.circular(PongSizes.paddleHeight / 2),
            boxShadow: dimmed
                ? null
                : side == DuelSide.me
                    ? PongShadows.playerPaddle
                    : PongShadows.opponentPaddle,
          ),
        ),
      ),
    );
  }
}

class _CourtBall extends StatelessWidget {
  const _CourtBall({required this.x, required this.y});

  final double x;
  final double y;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(x, y),
      child: Container(
        width: PongSizes.ball,
        height: PongSizes.ball,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PongColors.ball,
          boxShadow: PongShadows.ball,
        ),
      ),
    );
  }
}

/// Ligne en tirets : 12 px pleins, 12 px vides (comme le solo).
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

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
