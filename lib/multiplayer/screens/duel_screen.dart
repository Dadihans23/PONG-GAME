import 'package:flutter/material.dart';
import 'package:pong_game/game_ui/game_court.dart';
import 'package:pong_game/multiplayer/widgets/duel_court.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'multiplayer_view_data.dart';

/// Duel en cours (maquettes D1 et D2).
///
/// Même gabarit que le jeu solo : une bande de 72 px au-dessus du terrain,
/// qui ne recouvre jamais la raquette adverse, puis le terrain avec les
/// mêmes marges. Pas de bouton pause en duel : la bande n'affiche que le
/// format et l'état de la connexion. Aucun élément tactile pendant la
/// partie ; le retour Android appelle [onLeaveRequested].
class DuelScreen extends StatelessWidget {
  const DuelScreen({
    super.key,
    required this.hud,
    required this.field,
    this.point,
    this.onLeaveRequested,
  });

  final DuelHudData hud;

  /// Positions, déjà dans le repère de ce téléphone (moi en bas).
  final DuelFieldData field;

  /// Point marqué (D2) : annonce au centre pendant la remise en jeu.
  final DuelPointData? point;

  /// Retour Android pendant le duel (par exemple pour demander
  /// confirmation avec `DuelIncident.leaveDuel`). `null` : ignoré.
  final VoidCallback? onLeaveRequested;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onLeaveRequested?.call();
      },
      child: Scaffold(
        backgroundColor: PongColors.background,
        body: SafeArea(
          child: Column(
            children: [
              DuelHud(hud: hud),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(GameCourt.sideMargin, 0,
                      GameCourt.sideMargin, GameCourt.bottomMargin),
                  child: DuelCourt(hud: hud, field: field, point: point),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bande du haut du duel : « DUEL · PREMIER À 5 » et l'indicateur de
/// connexion, discret tant que tout va bien, rouge en cas de souci.
class DuelHud extends StatelessWidget {
  const DuelHud({super.key, required this.hud});

  /// Même hauteur que la bande du solo (`GameHud.height`).
  static const double height = 72;

  final DuelHudData hud;

  @override
  Widget build(BuildContext context) {
    final bool weak = hud.connection == DuelConnection.weak;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PongSpacing.screen),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'DUEL · PREMIER À ${hud.targetScore}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PongText.overline,
              ),
            ),
            Semantics(
              liveRegion: true,
              label: weak ? 'Connexion faible' : 'Connexion bonne',
              excludeSemantics: true,
              child: AnimatedSwitcher(
                duration: PongDurations.normal,
                child: weak
                    ? Row(
                        key: const ValueKey('weak'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Connexion faible',
                              style: PongText.statusLabel
                                  .copyWith(color: PongColors.errorText)),
                          const SizedBox(width: 6),
                          const Icon(Icons.network_wifi_1_bar_rounded,
                              size: 18, color: PongColors.error),
                        ],
                      )
                    : const Icon(Icons.wifi_rounded,
                        key: ValueKey('good'),
                        size: 18,
                        color: PongColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
