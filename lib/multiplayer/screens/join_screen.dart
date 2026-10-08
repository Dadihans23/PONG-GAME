import 'package:flutter/material.dart';
import 'package:pong_game/multiplayer/widgets/duel_avatar.dart';
import 'package:pong_game/multiplayer/widgets/duel_radar.dart';
import 'package:pong_game/multiplayer/widgets/duel_texts.dart';
import 'package:pong_game/ui/pong_ui.dart';

import 'multiplayer_view_data.dart';

/// Rejoindre une partie (maquettes J1, J2, J3). L'état affiché découle de
/// [JoinViewData] :
///
/// - J1, recherche sans résultat : ondes qui s'élargissent ;
/// - J2, parties trouvées : une ligne par partie, « Rejoindre » rose compact,
///   partie pleine grisée « Complète », « Actualiser » en secondaire ;
/// - J3, recherche terminée sans résultat : deux conseils numérotés et
///   « Actualiser » devient l'action principale.
class JoinScreen extends StatelessWidget {
  const JoinScreen({
    super.key,
    required this.data,
    required this.onJoin,
    required this.onRefresh,
    this.onBack,
  });

  final JoinViewData data;

  /// Le joueur touche « Rejoindre » sur la partie d'identifiant donné.
  final ValueChanged<String> onJoin;

  /// Relance la recherche (« Actualiser »).
  final VoidCallback onRefresh;

  /// Retour au menu ; par défaut, ferme l'écran.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bool hasGames = data.games.isNotEmpty;
    final Widget body;
    final Widget? bottomAction;
    if (hasGames) {
      body = _GameList(data: data, onJoin: onJoin);
      bottomAction = PongSecondaryButton(
        label: 'Actualiser',
        icon: Icons.refresh_rounded,
        onPressed: data.joiningId == null ? onRefresh : null,
      );
    } else if (data.searching) {
      body = const _Searching();
      bottomAction = null;
    } else {
      body = const _NoGame();
      bottomAction = PongPrimaryButton(
        label: 'Actualiser',
        icon: Icons.refresh_rounded,
        onPressed: onRefresh,
      );
    }
    return PongPageScaffold(
      title: 'Rejoindre',
      onBack: onBack,
      body: AnimatedSwitcher(
        duration: PongDurations.normal,
        child: KeyedSubtree(
          key: ValueKey(hasGames
              ? 'list'
              : data.searching
                  ? 'search'
                  : 'none'),
          child: body,
        ),
      ),
      bottomAction: bottomAction,
    );
  }
}

/// J1 : ondes et consigne, centrées.
class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DuelRadar(size: 240),
            const SizedBox(height: PongSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text('Recherche de parties…',
                  textAlign: TextAlign.center,
                  style: PongText.headline.copyWith(fontSize: 20)),
            ),
            const SizedBox(height: PongSpacing.md),
            Text(
              "Reste près de l'autre joueur, sur le même Wi‑Fi.",
              textAlign: TextAlign.center,
              style: PongText.body
                  .copyWith(fontSize: 14, color: PongColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// J3 : aucune partie, deux conseils numérotés.
class _NoGame extends StatelessWidget {
  const _NoGame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: PongSpacing.screen, vertical: PongSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox.square(
                dimension: 88,
                child: CustomPaint(
                  foregroundPainter: DashedOutlinePainter.circle(
                      color: PongColors.border, strokeWidth: 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: PongColors.surface, shape: BoxShape.circle),
                    child: Icon(Icons.wifi_off_rounded,
                        size: 40, color: PongColors.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Aucune partie trouvée',
                textAlign: TextAlign.center,
                style: PongText.headline.copyWith(fontSize: 20)),
            const SizedBox(height: PongSpacing.lg),
            const PongCard(
              child: Column(
                children: [
                  _Tip(
                    number: 1,
                    text: 'Vérifie que vous êtes sur le même Wi‑Fi ou '
                        'partage de connexion.',
                  ),
                  SizedBox(height: 14),
                  _Tip(
                    number: 2,
                    text: "Demande à l'autre joueur de toucher « Créer une "
                        'partie ».',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: PongColors.surfaceHigh, shape: BoxShape.circle),
            child: Text('$number',
                style: PongText.statusLabel.copyWith(
                    fontWeight: FontWeight.w800,
                    color: PongColors.textPrimary)),
          ),
          const SizedBox(width: PongSpacing.sm),
          Expanded(
            child: Text(text, style: PongText.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// J2 : état de la recherche et lignes de parties.
class _GameList extends StatelessWidget {
  const _GameList({required this.data, required this.onJoin});

  final JoinViewData data;
  final ValueChanged<String> onJoin;

  @override
  Widget build(BuildContext context) {
    final int count = data.games.length;
    final String found =
        '$count ${count == 1 ? 'partie' : 'parties'} à proximité';
    return ListView(
      padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
          PongSpacing.screen, PongSpacing.md),
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              _SearchDot(active: data.searching),
              const SizedBox(width: PongSpacing.xs),
              Expanded(
                child: Text(
                  data.searching ? '$found · recherche en cours' : found,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PongText.caption.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
        for (final game in data.games) ...[
          const SizedBox(height: 10),
          _GameTile(
            game: game,
            joining: data.joiningId == game.id,
            onJoin: data.joiningId == null && !game.isFull
                ? () => onJoin(game.id)
                : null,
          ),
        ],
      ],
    );
  }
}

/// Point rose qui pulse doucement tant que la recherche tourne ; gris sinon.
class _SearchDot extends StatefulWidget {
  const _SearchDot({required this.active});

  final bool active;

  @override
  State<_SearchDot> createState() => _SearchDotState();
}

class _SearchDotState extends State<_SearchDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_SearchDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
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
    if (!widget.active) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: PongColors.textDisabled, shape: BoxShape.circle),
      );
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: PongColors.pink,
          shape: BoxShape.circle,
          boxShadow: PongShadows.glow(PongColors.pink, opacity: 1, blur: 8),
        ),
      ),
    );
  }
}

/// Une partie trouvée : initiale de l'hôte, « Partie de Tom », nombre de
/// joueurs, action.
class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.joining,
    required this.onJoin,
  });

  final DiscoveredGameViewData game;
  final bool joining;
  final VoidCallback? onJoin;

  /// Largeur de ligne (hors marges) en dessous de laquelle l'initiale est
  /// masquée : 320 dp d'écran donnent 250, 360 dp en donnent 290.
  static const double _avatarMinWidth = 270;

  @override
  Widget build(BuildContext context) {
    final bool full = game.isFull;
    final Widget action;
    if (joining) {
      action = const _JoiningBadge();
    } else if (full) {
      action = Container(
        height: PongSizes.touchTarget,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: PongColors.surfaceDisabled,
          borderRadius: PongRadii.fieldAll,
        ),
        child: Text('Complète',
            style: PongText.buttonLabelPlain
                .copyWith(fontSize: 14, color: PongColors.textDisabled)),
      );
    } else {
      action = PongCompactButton(label: 'Rejoindre', onPressed: onJoin);
    }
    return PongCard(
      padding: const EdgeInsets.fromLTRB(PongSpacing.md, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            // Sur un écran étroit (320 dp), l'initiale cède sa place au nom
            // de la partie, qui sinon serait tronqué dès « Partie d… »
            if (constraints.maxWidth >= _avatarMinWidth) ...[
              DuelAvatar(
                  name: game.hostName, side: DuelSide.opponent, muted: full),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DuelTexts.gameOf(game.hostName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PongText.cardTitle.copyWith(
                        fontSize: 16,
                        color: full
                            ? PongColors.textSecondary
                            : PongColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(full ? Icons.group_rounded : Icons.person_rounded,
                          size: 15,
                          color: full
                              ? PongColors.textTertiary
                              : PongColors.textSecondary),
                      const SizedBox(width: PongSpacing.xxs),
                      Flexible(
                        child: Text(
                          '${game.playerCount} / ${game.maxPlayers} joueurs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PongText.caption.copyWith(
                              fontWeight: FontWeight.w400,
                              color: full
                                  ? PongColors.textTertiary
                                  : PongColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: PongSpacing.sm),
            action,
          ],
        ),
      ),
    );
  }
}

/// À la place de « Rejoindre » pendant la connexion : roue + « Connexion… ».
class _JoiningBadge extends StatelessWidget {
  const _JoiningBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PongSizes.touchTarget,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.sm),
      decoration: BoxDecoration(
        color: PongColors.alpha(PongColors.pink, 0.1),
        borderRadius: PongRadii.fieldAll,
        border: Border.all(color: PongColors.alpha(PongColors.pink, 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: PongColors.pinkLight),
          ),
          const SizedBox(width: PongSpacing.xs),
          Text('Connexion…',
              style: PongText.buttonLabelPlain
                  .copyWith(fontSize: 14, color: PongColors.pinkLight)),
        ],
      ),
    );
  }
}
