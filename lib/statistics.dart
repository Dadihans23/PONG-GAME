import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Statistiques (maquette ST1), par section de mode. Grille de 2 colonnes
/// pour les chiffres courts, pleine largeur pour les valeurs longues : une
/// statistique s'ajoute sans casser la page.
///
/// La section Multijoueur (victoires / défaites, barre de proportion)
/// s'ajoutera comme une deuxième `_StatSection` quand les duels
/// enregistreront leurs résultats.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = Hive.box('stats');
    final totalGames = stats.get('totalGames', defaultValue: 0) as int;
    final totalPlayTimeMs = stats.get('totalPlayTimeMs', defaultValue: 0) as int;
    final bestStreak = stats.get('bestStreak', defaultValue: 0) as int;
    final topScore =
        Hive.box<int>('scores').get('topscore', defaultValue: 0) ?? 0;

    return PongPageScaffold(
      title: 'Statistiques',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        children: [
          _StatSection(
            title: 'Solo',
            hint: totalGames == 0
                ? 'Joue ta première partie pour remplir ces chiffres.'
                : null,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PongStatCard(
                        icon: Icons.sports_esports_rounded,
                        label: 'Parties jouées',
                        value: PongFormat.number(totalGames),
                        color: PongColors.data,
                      ),
                    ),
                    const SizedBox(width: _StatSection.gap),
                    Expanded(
                      child: PongStatCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'Meilleur score',
                        value: PongFormat.number(topScore),
                        color: PongColors.record,
                      ),
                    ),
                  ],
                ),
              ),
              PongStatRow(
                icon: Icons.timer_rounded,
                label: 'Temps total de jeu',
                value: PongFormat.duration(totalPlayTimeMs),
                color: PongColors.pinkLight,
              ),
              PongStatRow(
                icon: Icons.local_fire_department_rounded,
                label: 'Meilleure série',
                value: PongFormat.count(bestStreak, 'renvoi', 'renvois'),
                color: PongColors.streak,
              ),
            ],
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
