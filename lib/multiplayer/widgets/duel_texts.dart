// Initiale d'un avatar, partagée par les écrans du multijoueur. Les phrases
// autour d'un pseudo (« Partie d'Inès », « En attente de Tom… ») sont des
// messages de lib/l10n/ (`gameOfName`, `waitingForName`).
import 'package:flutter/widgets.dart';

abstract final class DuelTexts {
  /// Initiale d'un avatar, en majuscule (« ? » pour un pseudo vide).
  static String initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
