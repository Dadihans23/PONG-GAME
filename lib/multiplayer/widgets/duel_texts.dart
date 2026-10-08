// Petites tournures françaises autour d'un pseudo, partagées par les écrans
// du multijoueur : l'élision (« Partie d'Inès », « En attente d'Inès… ») et
// l'initiale d'un avatar.
import 'package:flutter/widgets.dart';

abstract final class DuelTexts {
  // Voyelles, accentuées ou non : « de » devient « d' » devant elles.
  // Ni « h » (« de Hugo ») ni « y » (« de Yanis ») : on garde « de ».
  static const String _vowels = 'aeiouàâäéèêëîïôöùûüæœ';

  /// « de Tom » ou « d'Inès ».
  static String ofName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'de ton adversaire';
    final first = trimmed.characters.first.toLowerCase();
    return _vowels.contains(first) ? "d'$trimmed" : 'de $trimmed';
  }

  /// « Partie de Tom », « Partie d'Inès ».
  static String gameOf(String name) => 'Partie ${ofName(name)}';

  /// « En attente de Tom… », « En attente d'Inès… ».
  static String waitingFor(String name) => 'En attente ${ofName(name)}…';

  /// Initiale d'un avatar, en majuscule (« ? » pour un pseudo vide).
  static String initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
