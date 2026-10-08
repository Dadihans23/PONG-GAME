import 'package:flutter/material.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Menu multijoueur (maquette M1) : créer une partie ou en rejoindre une.
///
/// Deux grandes cartes de navigation de même poids, sans bouton rose : c'est
/// la carte entière qui est la cible tactile. La condition réseau est
/// rappelée en bas, sans alarme.
class MultiplayerMenuScreen extends StatelessWidget {
  const MultiplayerMenuScreen({
    super.key,
    required this.playerName,
    required this.onCreate,
    required this.onJoin,
    this.creating = false,
    this.onBack,
  });

  /// Pseudo du joueur (« Tu joues en tant que Léa »).
  final String playerName;

  /// « Créer une partie » : ouvre le salon en tant qu'hôte.
  final VoidCallback onCreate;

  /// « Rejoindre une partie » : ouvre la recherche.
  final VoidCallback onJoin;

  /// La partie est en cours de création : la carte « Créer » affiche une
  /// roue et les deux cartes sont inactives.
  final bool creating;

  /// Retour ; par défaut, ferme l'écran.
  final VoidCallback? onBack;

  // Bleu « joueur » à 14 %, comme la pastille Contrôles de l'aide
  static const Color _joinTint = Color(0x242196F3);

  @override
  Widget build(BuildContext context) {
    return PongPageScaffold(
      title: 'Multijoueur',
      onBack: onBack,
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(PongSpacing.screen,
                  PongSpacing.sm, PongSpacing.screen, PongSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Tu joues en tant que ',
                      children: [
                        TextSpan(
                          text: playerName,
                          style: const TextStyle(
                              color: PongColors.textPrimary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PongText.caption
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: PongSpacing.md),
                  _MenuCard(
                    icon: Icons.add_rounded,
                    color: PongColors.pinkLight,
                    tint: PongColors.pinkTint,
                    glow: true,
                    title: 'Créer une partie',
                    subtitle: 'Ton ami la rejoint depuis son téléphone.',
                    busy: creating,
                    onTap: creating ? null : onCreate,
                  ),
                  const SizedBox(height: PongSpacing.md),
                  _MenuCard(
                    icon: Icons.login_rounded,
                    color: PongColors.playerLight,
                    tint: _joinTint,
                    title: 'Rejoindre une partie',
                    subtitle: "Trouve la partie d'un ami à proximité.",
                    onTap: creating ? null : onJoin,
                  ),
                  const Spacer(),
                  const SizedBox(height: PongSpacing.md),
                  const NetworkHint(
                    text: "Soyez sur le même Wi‑Fi, ou connecte-toi au "
                        "partage de connexion de l'autre. Pas besoin "
                        "d'Internet.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grande carte de navigation : pastille d'icône, chevron, titre, phrase.
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.glow = false,
    this.busy = false,
  });

  final IconData icon;

  /// Couleur de l'icône, et fond teinté de sa pastille.
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Halo rose autour de la pastille (création : l'action « vivante »).
  final bool glow;

  /// Roue à la place du chevron pendant la création.
  final bool busy;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null || busy;
    return PongPressable(
      onTap: onTap,
      width: double.infinity,
      pressedScale: 0.985,
      borderRadius: _radius,
      padding: const EdgeInsets.all(20),
      alignment: Alignment.topLeft,
      decoration: const BoxDecoration(
        color: PongColors.surface,
        border:
            Border.fromBorderSide(BorderSide(color: PongColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: PongRadii.cardAll,
                  boxShadow: glow && enabled
                      ? PongShadows.glow(PongColors.pink,
                          opacity: 0.2, blur: 20)
                      : null,
                ),
                child: PongIconBadge(
                  icon: icon,
                  color: enabled ? color : PongColors.textDisabled,
                  background: enabled ? tint : PongColors.surfaceHigh,
                  size: 56,
                  iconSize: 30,
                ),
              ),
              const Spacer(),
              if (busy)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: PongColors.pinkLight),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 26, color: PongColors.textTertiary),
            ],
          ),
          const SizedBox(height: 14),
          Text(title,
              style: PongText.dialogTitle.copyWith(
                  color: enabled
                      ? PongColors.textPrimary
                      : PongColors.textDisabled)),
          const SizedBox(height: PongSpacing.xxs),
          Text(
            subtitle,
            style: PongText.body
                .copyWith(fontSize: 14, color: PongColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Rappel discret de la condition réseau : icône Wi-Fi et une phrase, dans
/// un cadre fin, sans fond.
class NetworkHint extends StatelessWidget {
  const NetworkHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: PongSpacing.md, vertical: 14),
      decoration: const BoxDecoration(
        borderRadius: PongRadii.fieldAll,
        border:
            Border.fromBorderSide(BorderSide(color: PongColors.surfaceHigh)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_rounded, size: 20, color: PongColors.textBody),
          const SizedBox(width: PongSpacing.sm),
          Expanded(
            child: Text(text,
                style: PongText.caption
                    .copyWith(fontWeight: FontWeight.w400, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
