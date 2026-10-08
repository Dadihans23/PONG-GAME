// Règles du classement local, sans dépendance à Flutter ni à Hive.
//
// Une entrée est une Map `{name, score, date}`, comme dans la boîte Hive
// `leaderboard`.

/// Nombre d'entrées gardées dans le classement.
const int leaderboardSize = 10;

/// Ajoute [entry] à [entries], trie par score décroissant et garde les
/// [leaderboardSize] meilleurs.
///
/// Retourne le nouveau classement et le rang de l'entrée ajoutée (1 = premier),
/// ou `null` si elle n'entre pas dans le classement.
({List<dynamic> entries, int? rank}) insertLeaderboardEntry(
    List<dynamic> entries, Map<String, dynamic> entry) {
  List<dynamic> sorted = List<dynamic>.from(entries)..add(entry);
  sorted.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  if (sorted.length > leaderboardSize) {
    sorted = sorted.sublist(0, leaderboardSize);
  }
  // L'entrée est retrouvée par identité : deux scores égaux ne se confondent pas
  final int index = sorted.indexWhere((e) => identical(e, entry));
  return (entries: sorted, rank: index < 0 ? null : index + 1);
}
