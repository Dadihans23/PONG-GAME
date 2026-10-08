import 'package:hive_flutter/hive_flutter.dart';

/// Victoires et défaites en duel, enregistrées à la fin de chaque duel
/// terminé (un duel abandonné ne compte pas).
abstract interface class DuelStatsStore {
  int get wins;
  int get losses;

  void recordDuel({required bool won});
}

/// Statistiques dans la boîte Hive `stats` (ouverte au démarrage dans
/// `main()`), clés [winsKey] et [lossesKey], entiers, 0 par défaut.
///
/// Une erreur de Hive (boîte fermée, valeur illisible) est ignorée : elle ne
/// doit jamais interrompre un duel.
class HiveDuelStats implements DuelStatsStore {
  HiveDuelStats([this._box]);

  static const String boxName = 'stats';
  static const String winsKey = 'duelWins';
  static const String lossesKey = 'duelLosses';

  Box<dynamic>? _box;

  Box<dynamic>? get _store {
    try {
      return _box ??= Hive.box(boxName);
    } on Object catch (_) {
      return null;
    }
  }

  int _read(String key) {
    final value = _store?.get(key);
    return value is int && value >= 0 ? value : 0;
  }

  @override
  int get wins => _read(winsKey);

  @override
  int get losses => _read(lossesKey);

  @override
  void recordDuel({required bool won}) {
    final key = won ? winsKey : lossesKey;
    try {
      _store?.put(key, _read(key) + 1);
    } on Object catch (_) {
      // Statistique perdue, partie intacte.
    }
  }
}

/// Statistiques en mémoire, pour les tests.
class MemoryDuelStats implements DuelStatsStore {
  @override
  int wins = 0;

  @override
  int losses = 0;

  @override
  void recordDuel({required bool won}) {
    if (won) {
      wins++;
    } else {
      losses++;
    }
  }
}
