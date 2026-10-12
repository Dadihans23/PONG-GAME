// Page « Le studio », ouverte par la signature en bas des Réglages et de
// l'Aide (jamais pendant une partie). Retour Android : page précédente.
//
// Le joueur vient par curiosité : qui a fait le jeu ? La page le dit en une
// phrase, sous le logo posé au centre d'un petit terrain (le logo est au
// service, comme la balle), puis la présentation écrite dans l'administration
// du site. Les deux liens sortent de l'app : ils restent en retrait (pas de
// rose plein, rien à « gagner » ici), le site d'abord, le contact ensuite.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../ui/pong_ui.dart';
import 'studio_info.dart';

/// Ouvre une adresse hors de l'app ; `false` si rien ne l'a ouverte.
typedef StudioLinkLauncher = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

class StudioPage extends StatelessWidget {
  const StudioPage({super.key, this.studio, this.launcher});

  /// Présentation à afficher (tests) ; par défaut `Studio.current`, qui se
  /// met à jour si la réponse du site arrive pendant que la page est ouverte.
  final ValueListenable<StudioInfo>? studio;

  /// Ouverture des liens (tests) ; par défaut le navigateur du téléphone.
  final StudioLinkLauncher? launcher;

  /// Ouvre la page par-dessus l'écran courant.
  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const StudioPage()));

  static const String _versionLine =
      '${Brand.gameName} · version ${Brand.appVersion}';

  Future<void> _open(BuildContext context, String link) async {
    final url = Uri.tryParse(link);
    var opened = false;
    if (url != null) {
      try {
        opened = await (launcher ?? _openInBrowser)(url);
      } catch (_) {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    final host = url?.host.isNotEmpty == true ? url!.host : Brand.studioApiHost;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text("Le lien ne s'ouvre pas. Va sur $host depuis ton "
            'navigateur.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StudioInfo>(
      valueListenable: studio ?? Studio.current,
      builder: (context, info, _) => PongPageScaffold(
        title: 'Le studio',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(PongSpacing.screen,
              PongSpacing.xxs, PongSpacing.screen, PongSpacing.lg),
          children: [
            _StudioCourt(info: info),
            const SizedBox(height: PongSpacing.lg),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '${Brand.gameName} est un jeu de '),
                TextSpan(
                  text: info.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PongColors.textPrimary),
                ),
                const TextSpan(text: '.'),
              ]),
              style: PongText.headline.copyWith(color: PongColors.textBody),
            ),
            for (final paragraph in info.paragraphs) ...[
              const SizedBox(height: PongSpacing.sm),
              Text(paragraph, style: PongText.body),
            ],
          ],
        ),
        bottomAction: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PongSecondaryButton(
              label: 'Visiter le site',
              icon: Icons.open_in_new_rounded,
              onPressed: () => unawaited(_open(context, info.website)),
            ),
            const SizedBox(height: PongSpacing.xxs),
            PongTextButton(
              label: 'Écrire au studio',
              icon: Icons.open_in_new_rounded,
              color: PongColors.pinkLight,
              onPressed: () => unawaited(_open(context, info.contactUrl)),
            ),
            const SizedBox(height: PongSpacing.xs),
            const Text(
              _versionLine,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: PongText.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PongColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit terrain vu de haut : ligne médiane en tirets, raquette adverse
/// verte en haut, la tienne bleue en bas, et le logo du studio au centre, à
/// la place de la balle au service. Rien ne bouge : c'est une vitrine.
class _StudioCourt extends StatelessWidget {
  const _StudioCourt({required this.info});

  final StudioInfo info;

  static const double _height = 176;
  static const double _logoHeight = 40;
  static const Size _paddle = Size(44, 6);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border:
              Border.fromBorderSide(BorderSide(color: PongColors.courtLine)),
          borderRadius: PongRadii.cardAll,
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _MidlinePainter()),
              ),
              // Adversaire en haut, décalé à droite ; toi en bas, à gauche :
              // l'échange vient d'être servi.
              Positioned(
                top: PongSpacing.md,
                left: width * 0.62 - _paddle.width / 2,
                child: const _Paddle(
                  color: PongColors.opponent,
                  shadows: PongShadows.opponentPaddle,
                ),
              ),
              Positioned(
                bottom: PongSpacing.md,
                left: width * 0.36 - _paddle.width / 2,
                child: const _Paddle(
                  color: PongColors.player,
                  shadows: PongShadows.playerPaddle,
                ),
              ),
              Center(
                // Fond du terrain sous le logo : la médiane s'interrompt
                child: ColoredBox(
                  color: PongColors.background,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: PongSpacing.sm, vertical: PongSpacing.xs),
                    child: PongStudioLogo(
                      info: info,
                      height: _logoHeight,
                      maxWidth: width * 0.64,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Paddle extends StatelessWidget {
  const _Paddle({required this.color, required this.shadows});

  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _StudioCourt._paddle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          boxShadow: shadows,
        ),
      ),
    );
  }
}

/// Ligne médiane horizontale en tirets, comme sur le terrain de jeu
/// (12 px pleins, 12 px vides, 2 px d'épaisseur).
class _MidlinePainter extends CustomPainter {
  const _MidlinePainter();

  static const double _dash = 12;
  static const double _thickness = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PongColors.courtMidline;
    final top = (size.height - _thickness) / 2;
    for (double x = 0; x < size.width; x += _dash * 2) {
      canvas.drawRect(
          Rect.fromLTWH(x, top, math.min(_dash, size.width - x), _thickness),
          paint);
    }
  }

  @override
  bool shouldRepaint(_MidlinePainter oldDelegate) => false;
}
