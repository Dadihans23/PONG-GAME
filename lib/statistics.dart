import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Statistiques (maquette ST1), par section de mode. Grille de 2 colonnes
/// pour les chiffres courts, pleine largeur pour les valeurs longues : une
/// statistique s'ajoute sans casser la page. Le multijoueur a sa propre
/// section : victoires, défaites, nombre de duels et barre de proportion
/// (clés `duelWins` et `duelLosses` de la boîte `stats`).
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = Hive.box('stats');
    final totalGames = stats.get('totalGames', defaultValue: 0) as int;
    final totalPlayTimeMs =
        stats.get('totalPlayTimeMs', defaultValue: 0) as int;
    final bestStreak = stats.get('bestStreak', defaultValue: 0) as int;
    final duelWins = stats.get('duelWins', defaultValue: 0) as int;
    final duelLosses = stats.get('duelLosses', defaultValue: 0) as int;
    final topScore =
        Hive.box<int>('scores').get('topscore', defaultValue: 0) ?? 0;
    final l10n = context.l10n;
    final format = PongFormat.of(context);

    return PongPageScaffold(
      title: l10n.statisticsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        children: [
          _StatSection(
            title: l10n.modeSolo,
            hint: totalGames == 0 ? l10n.statsSoloEmpty : null,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PongStatCard(
                        icon: Icons.sports_esports_rounded,
                        label: l10n.statsGamesPlayed,
                        value: format.number(totalGames),
                        color: PongColors.data,
                      ),
                    ),
                    const SizedBox(width: _StatSection.gap),
                    Expanded(
                      child: PongStatCard(
                        icon: Icons.emoji_events_rounded,
                        label: l10n.bestScore,
                        value: format.number(topScore),
                        color: PongColors.record,
                      ),
                    ),
                  ],
                ),
              ),
              PongStatRow(
                icon: Icons.timer_rounded,
                label: l10n.statsTotalTime,
                value: format.duration(totalPlayTimeMs),
                color: PongColors.pinkLight,
              ),
              PongStatRow(
                icon: Icons.local_fire_department_rounded,
                label: l10n.statsBestStreak,
                value: l10n.hitsCount(bestStreak, format.number(bestStreak)),
                color: PongColors.streak,
              ),
            ],
          ),
          _StatSection(
            title: l10n.modeMultiplayer,
            hint: duelWins + duelLosses == 0 ? l10n.statsMultiplayerEmpty : null,
            children: [_DuelRecordCard(wins: duelWins, losses: duelLosses)],
          ),
        ],
      ),
    );
  }
}

/// Une section de statistiques : sur-titre, phrase d'aide facultative,
/// cartes espacées de 10 px.
class _StatSection extends StatelessWidget {
  const _StatSection({
    required this.title,
    required this.children,
    this.hint,
  });

  final String title;
  final List<Widget> children;

  /// Phrase affichée sous le titre (ex. tant qu'aucune partie n'est jouée).
  final String? hint;

  static const double gap = 10;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.only(bottom: PongSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PongOverline(title),
          if (hint != null) ...[
            const SizedBox(height: PongSpacing.xs),
            Text(hint, style: PongText.caption),
          ],
          const SizedBox(height: PongSpacing.sm),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Bilan des duels : victoires à gauche (vert), nombre de duels au centre,
/// défaites à droite, et une barre qui montre la proportion d'un coup d'œil.
class _DuelRecordCard extends StatelessWidget {
  const _DuelRecordCard({required this.wins, required this.losses});

  final int wins;
  final int losses;

  @override
  Widget build(BuildContext context) {
    final int total = wins + losses;
    final l10n = context.l10n;
    final format = PongFormat.of(context);
    final String duels = l10n.duelsCount(total, format.number(total));
    final TextStyle label =
        PongText.caption.copyWith(fontWeight: FontWeight.w400);
    final TextStyle figure = PongText.keyFigure.copyWith(fontSize: 30);
    return PongCard(
      child: Semantics(
        container: true,
        label: l10n.statsDuelSemantics(wins, losses, duels),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.statsWins, style: label),
                      const SizedBox(height: PongSpacing.xxs),
                      Text(format.number(wins),
                          style: figure.copyWith(color: PongColors.success)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(duels, style: label),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l10n.statsLosses, style: label),
                      const SizedBox(height: PongSpacing.xxs),
                      Text(format.number(losses),
                          style: figure.copyWith(color: PongColors.textBody)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: total == 0
                    ? Container(color: PongColors.faint)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wins > 0)
                            Expanded(
                              flex: wins,
                              child: Container(color: PongColors.success),
                            ),
                          if (wins > 0 && losses > 0) const SizedBox(width: 2),
                          if (losses > 0)
                            Expanded(
                              flex: losses,
                              child: Container(color: PongColors.faint),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
