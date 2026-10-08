import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/leaderboard_rules.dart';

Map<String, dynamic> entry(String name, int score) =>
    {'name': name, 'score': score, 'date': '2026-10-08T12:00:00.000'};

void main() {
  group('insertLeaderboardEntry', () {
    test('classement vide : premier', () {
      final result = insertLeaderboardEntry([], entry('Léa', 500));
      expect(result.rank, 1);
      expect(result.entries.length, 1);
    });

    test('trié par score décroissant, rang de la nouvelle entrée', () {
      final result = insertLeaderboardEntry(
        [entry('A', 900), entry('B', 300)],
        entry('Léa', 500),
      );
      expect(result.entries.map((e) => e['score']), [900, 500, 300]);
      expect(result.rank, 2);
    });

    test('garde les 10 meilleurs', () {
      final full = [for (int i = 1; i <= 10; i++) entry('J$i', i * 100)];
      final result = insertLeaderboardEntry(full, entry('Léa', 550));
      expect(result.entries.length, leaderboardSize);
      expect(result.entries.map((e) => e['score']).last, 200);
      expect(result.rank, 6);
    });

    test('hors du top 10 : rang null, classement inchangé', () {
      final full = [for (int i = 1; i <= 10; i++) entry('J$i', i * 100)];
      final result = insertLeaderboardEntry(full, entry('Léa', 50));
      expect(result.rank, isNull);
      expect(result.entries.map((e) => e['score']),
          [1000, 900, 800, 700, 600, 500, 400, 300, 200, 100]);
    });

    test('score égal à une entrée existante : la nouvelle est bien retrouvée',
        () {
      final result = insertLeaderboardEntry(
        [entry('A', 900), entry('B', 500), entry('C', 100)],
        entry('Léa', 500),
      );
      final int rank = result.rank!;
      expect(rank, anyOf(2, 3));
      expect(result.entries[rank - 1]['name'], 'Léa');
    });

    test('la liste reçue n\'est pas modifiée', () {
      final original = [entry('A', 900)];
      insertLeaderboardEntry(original, entry('Léa', 500));
      expect(original.length, 1);
    });
  });
}
