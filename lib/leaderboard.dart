import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Classement (maquette C1 / C2) : le podium (64 px, trophée, bordure de
/// métal) se détache du reste (56 px, date sur la même ligne). La liste
/// défile jusqu'au 10ᵉ. Vide, l'écran propose de jouer.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  /// Nombre de lignes affichées.
  static const int maxEntries = 10;

  /// Entrées du classement, triées par score décroissant.
  static List<LeaderboardEntry> readEntries() {
    final raw = Hive.box('leaderboard').get('entries', defaultValue: []) ?? [];
    final entries = [
      for (final item in raw as List)
        if (item is Map) LeaderboardEntry.fromMap(item),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return entries.take(maxEntries).toList();
  }

  /// Retour à l'accueil, premier écran de la pile, que le classement soit
  /// ouvert depuis l'accueil ou depuis la fin de partie.
  static void _backToHome(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final entries = readEntries();
    final l10n = context.l10n;
    if (entries.isEmpty) {
      return PongPageScaffold(
        title: l10n.leaderboardTitle,
        body: PongEmptyState(
          icon: Icons.emoji_events_rounded,
          title: l10n.leaderboardEmptyTitle,
          message: l10n.leaderboardEmptyMessage(maxEntries),
        ),
        bottomAction: PongPrimaryButton(
          label: l10n.homePlay,
          onPressed: () => _backToHome(context),
        ),
      );
    }
    return PongPageScaffold(
      title: l10n.leaderboardTitle,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: PongSpacing.xs),
        itemBuilder: (context, index) {
          final rank = index + 1;
          final podium = PongColors.podium(rank);
          return podium == null
              ? _RankRow(rank: rank, entry: entries[index])
              : _PodiumRow(rank: rank, color: podium, entry: entries[index]);
        },
      ),
    );
  }
}

/// Une ligne du classement, lue dans la boîte Hive `leaderboard`.
class LeaderboardEntry {
  const LeaderboardEntry({required this.name, required this.score, this.date});

  factory LeaderboardEntry.fromMap(Map map) {
    final score = map['score'];
    final date = map['date'];
    return LeaderboardEntry(
      name: map['name']?.toString(),
      score: score is int ? score : 0,
      date: date is String ? DateTime.tryParse(date) : null,
    );
  }

  /// Pseudo enregistré, `null` pour une ancienne ligne sans pseudo.
  final String? name;
  final int score;
  final DateTime? date;

  /// Pseudo à afficher (« Inconnu » s'il manque).
  String displayName(AppLocalizations l10n) =>
      name ?? l10n.leaderboardUnknownPlayer;

  /// Date de la partie dans la langue de l'app.
  String? formattedDate(PongFormat format) {
    final date = this.date;
    return date == null ? null : format.date(date);
  }
}

/// Rangs 1 à 3 : trophée et bordure aux couleurs du podium ; l'or a un halo.
class _PodiumRow extends StatelessWidget {
  const _PodiumRow({
    required this.rank,
    required this.color,
    required this.entry,
  });

  final int rank;
  final Color color;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = PongFormat.of(context);
    final row = PongListRow(
      leading: Icon(
        Icons.emoji_events_rounded,
        size: 26,
        color: color,
        semanticLabel: l10n.rankLabel(rank),
      ),
      title: entry.displayName(l10n),
      subtitle: entry.formattedDate(format),
      value: format.number(entry.score),
      borderColor: color,
    );
    if (rank != 1) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: PongRadii.cardAll,
        boxShadow: PongShadows.glow(color, opacity: 0.12, blur: 16),
      ),
      child: row,
    );
  }
}

/// Rangs 4 à 10 : ligne plus basse, numéro gris, date à côté du nom.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = PongFormat.of(context);
    final date = entry.formattedDate(format);
    final score = format.number(entry.score);
    final name = entry.displayName(l10n);
    final rankLabel = l10n.rankLabel(rank);
    return Semantics(
      label: date == null
          ? l10n.leaderboardRowSemantics(rankLabel, name, score)
          : l10n.leaderboardRowSemanticsWithDate(rankLabel, name, score, date),
      excludeSemantics: true,
      child: SizedBox(
        height: _height,
        child: PongCard(
          borderRadius: PongRadii.fieldAll,
          padding: const EdgeInsets.symmetric(horizontal: PongSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: PongText.figure
                      .copyWith(fontSize: 15, color: PongColors.textTertiary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: name,
                    children: [
                      if (date != null)
                        TextSpan(
                          text: ' · $date',
                          style: PongText.caption.copyWith(
                              fontSize: 12, color: PongColors.textTertiary),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PongText.cardTitle
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: PongSpacing.sm),
              Text(
                score,
                style: PongText.listValue.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PongColors.textBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
