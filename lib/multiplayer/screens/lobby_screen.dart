import 'package:flutter/material.dart';
import 'package:pong_game/multiplayer/widgets/duel_avatar.dart';
import 'package:pong_game/multiplayer/widgets/duel_countdown.dart';
import 'package:pong_game/multiplayer/widgets/duel_radar.dart';
import 'package:pong_game/multiplayer/widgets/duel_texts.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'multiplayer_view_data.dart';

/// Salon (maquettes L1 à L4). La structure ne change pas quand l'autre
/// joueur arrive : la place vide en pointillés se remplit, et « Prêt »,
/// déjà là mais inactif avec sa raison au-dessus, s'allume.
///
/// - L1, hôte seul : place vide, ondes « ta partie est visible » ;
/// - L2, deux joueurs : « Prêt » en rose ;
/// - L3, prêt : le bouton passe en secondaire (« Je ne suis plus prêt ») ;
/// - L4, compte à rebours : `data.countdown` non nul, plein écran.
///
/// Pas de bouton retour : on quitte par « Annuler la partie » (hôte) ou
/// « Quitter » (invité). Le retour Android appelle aussi [onLeave].
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.data,
    required this.onReadyChanged,
    required this.onLeave,
  });

  final LobbyViewData data;

  /// `true` : le joueur touche « Prêt » ; `false` : « Je ne suis plus prêt ».
  final ValueChanged<bool> onReadyChanged;

  /// « Annuler la partie » (hôte), « Quitter » (invité), ou retour Android.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final int? countdown = data.countdown;
    final LobbyPlayerViewData? other = data.other;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onLeave();
      },
      child: Stack(
        children: [
          PongPageScaffold(
            title: 'Salon',
            showBack: false,
            body: _LobbyBody(data: data, dimmed: countdown != null),
            bottomAction: countdown != null
                ? null
                : _LobbyActions(
                    data: data,
                    onReadyChanged: onReadyChanged,
                    onLeave: onLeave,
                  ),
          ),
          if (countdown != null)
            Positioned.fill(
              child: DuelCountdownOverlay(
                value: countdown,
                myName: data.me.name,
                opponentName: other?.name ?? '',
              ),
            ),
        ],
      ),
    );
  }
}

class _LobbyBody extends StatelessWidget {
  const _LobbyBody({required this.data, required this.dimmed});

  final LobbyViewData data;

  /// Hauteur d'écran (dp) sous laquelle les ondes rétrécissent (SM-A135F :
  /// 665 dp utiles).
  static const double _compactHeight = 720;

  /// Sous le compte à rebours : seules les deux lignes restent, estompées.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final LobbyPlayerViewData? other = data.other;
    final Widget meRow = _PlayerRow(
      player: data.me,
      side: DuelSide.me,
      subtitle: data.isHost ? 'Toi · hôte' : 'Toi',
    );
    final Widget otherRow = other == null
        ? const _EmptySlot()
        : _PlayerRow(
            player: other,
            side: DuelSide.opponent,
            subtitle: !data.isHost
                ? 'Hôte'
                : other.justJoined
                    ? 'Vient de rejoindre'
                    : 'Invité',
          );
    // L'hôte d'abord : côté invité, « toi » se retrouve en bas, comme sur
    // le terrain
    final List<Widget> rows =
        data.isHost ? [meRow, otherRow] : [otherRow, meRow];

    return ListView(
      padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
          PongSpacing.screen, PongSpacing.md),
      children: [
        Visibility.maintain(
          visible: !dimmed,
          child: Padding(
            padding: const EdgeInsets.only(bottom: PongSpacing.md + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    DuelTexts.gameOf(data.hostName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PongText.headline.copyWith(fontSize: 24),
                  ),
                ),
                const SizedBox(height: PongSpacing.xxs),
                Text('Duel · premier à $duelTargetScore points',
                    style: PongText.caption
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ),
        Opacity(
          // Presque effacées : le compte à rebours se lit sans les lignes
          // du salon en travers
          opacity: dimmed ? 0.3 : 1,
          child: Column(
            children: [
              rows[0],
              const SizedBox(height: PongSpacing.sm),
              rows[1],
            ],
          ),
        ),
        if (other == null && !dimmed) ...[
          const SizedBox(height: PongSpacing.lg),
          Center(
            // Plus petites sur un écran court, pour que la phrase reste
            // visible au-dessus de « Prêt » sans défiler
            child: DuelRadar(
                size: MediaQuery.sizeOf(context).height < _compactHeight
                    ? 88
                    : 120,
                rings: 2,
                badgeSize: 0),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                'Ta partie est visible par les joueurs à proximité.',
                textAlign: TextAlign.center,
                style: PongText.body.copyWith(fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ligne d'un joueur : initiale, pseudo, rôle, statut. Contour vert quand
/// il est prêt.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.side,
    required this.subtitle,
  });

  final LobbyPlayerViewData player;
  final DuelSide side;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: AnimatedContainer(
        duration: PongDurations.normal,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: PongSpacing.md),
        decoration: BoxDecoration(
          color: PongColors.surface,
          borderRadius: PongRadii.cardAll,
          border: Border.all(
            color: player.ready
                ? PongColors.alpha(PongColors.success, 0.4)
                : PongColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            DuelAvatar(name: player.name, side: side),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PongText.cardTitle.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  // Deux lignes possibles à 320 dp (« Vient de
                  // rejoindre » à côté de la pastille d'état)
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PongText.caption.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: PongSpacing.xs),
            player.ready
                ? const PongPill.status(
                    label: 'Prêt',
                    color: PongColors.success,
                    icon: Icons.check_rounded,
                  )
                : const PongPill.status(
                    label: 'En attente',
                    icon: Icons.hourglass_top_rounded,
                  ),
          ],
        ),
      ),
    );
  }
}

/// Place libre, en pointillés : ce qu'on attend.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: CustomPaint(
        painter: const DashedOutlinePainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PongSpacing.md),
          child: Row(
            children: [
              DuelAvatar.placeholder,
              const SizedBox(width: 14),
              Expanded(
                child: Text("En attente d'un joueur…",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PongText.body
                        .copyWith(color: PongColors.textTertiary, height: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raison, bouton Prêt (ou « Je ne suis plus prêt »), sortie.
class _LobbyActions extends StatelessWidget {
  const _LobbyActions({
    required this.data,
    required this.onReadyChanged,
    required this.onLeave,
  });

  final LobbyViewData data;
  final ValueChanged<bool> onReadyChanged;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final LobbyPlayerViewData? other = data.other;
    final bool meReady = data.me.ready;

    final String hint;
    Color hintColor = PongColors.textSecondary;
    if (other == null) {
      hint = "Disponible dès qu'un joueur te rejoint";
      hintColor = PongColors.textTertiary;
    } else if (meReady) {
      hint = DuelTexts.waitingFor(other.name);
    } else if (other.ready) {
      hint = "${other.name} t'attend. À toi !";
    } else {
      hint = 'La partie démarre quand vous êtes prêts tous les deux';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(hint,
              textAlign: TextAlign.center,
              style: PongText.caption
                  .copyWith(fontWeight: FontWeight.w400, color: hintColor)),
        ),
        const SizedBox(height: PongSpacing.sm),
        AnimatedSwitcher(
          duration: PongDurations.normal,
          child: meReady
              ? PongSecondaryButton(
                  key: const ValueKey('notReady'),
                  label: 'Je ne suis plus prêt',
                  onPressed: () => onReadyChanged(false),
                )
              : PongPrimaryButton(
                  key: const ValueKey('ready'),
                  label: 'Prêt',
                  onPressed: other == null ? null : () => onReadyChanged(true),
                ),
        ),
        const SizedBox(height: PongSpacing.xs),
        PongTextButton(
          label: data.isHost ? 'Annuler la partie' : 'Quitter',
          onPressed: onLeave,
        ),
      ],
    );
  }
}
