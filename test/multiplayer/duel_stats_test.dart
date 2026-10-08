import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/multiplayer/controller/duel_stats.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('pong_duel_stats');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('victoires et défaites dans la boîte stats, 0 par défaut', () async {
    final box = await Hive.openBox<dynamic>('stats_duel_test');
    final stats = HiveDuelStats(box);
    expect(stats.wins, 0);
    expect(stats.losses, 0);
    stats.recordDuel(won: true);
    stats.recordDuel(won: true);
    stats.recordDuel(won: false);
    expect(box.get(HiveDuelStats.winsKey), 2);
    expect(box.get(HiveDuelStats.lossesKey), 1);
    expect(stats.wins, 2);
    expect(stats.losses, 1);
  });

  test('valeur illisible traitée comme 0', () async {
    final box = await Hive.openBox<dynamic>('stats_duel_bad');
    await box.put(HiveDuelStats.winsKey, 'beaucoup');
    final stats = HiveDuelStats(box);
    expect(stats.wins, 0);
    stats.recordDuel(won: true);
    expect(stats.wins, 1);
  });

  test('boîte absente : aucune exception', () {
    final stats = HiveDuelStats();
    expect(stats.wins, 0);
    stats.recordDuel(won: false);
    expect(stats.losses, 0);
  });

  test('statistiques en mémoire', () {
    final stats = MemoryDuelStats()
      ..recordDuel(won: true)
      ..recordDuel(won: false)
      ..recordDuel(won: false);
    expect(stats.wins, 1);
    expect(stats.losses, 2);
  });
}
