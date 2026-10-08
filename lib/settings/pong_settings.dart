import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';

/// Réglages du joueur, enregistrés dans la boîte Hive `settings` (ouverte
/// dans `main()`).
///
/// Valeurs par défaut : son et vibration activés, sensibilité de la
/// raquette à [PaddleSensitivity.defaultValue]. Une valeur absente ou
/// illisible retombe sur sa valeur par défaut.
///
/// ```dart
/// final settings = PongSettings();
/// if (settings.vibrationEnabled) HapticFeedback.lightImpact();
/// final tilt = PaddleSensitivity.tiltControl(settings.paddleSensitivity);
/// ```
class PongSettings {
  /// [box] sert aux tests ; par défaut, la boîte `settings` déjà ouverte.
  PongSettings([Box<dynamic>? box]) : _box = box ?? Hive.box(boxName);

  final Box<dynamic> _box;

  /// Nom de la boîte Hive.
  static const String boxName = 'settings';

  // --- Clés Hive ------------------------------------------------------------
  static const String pseudoKey = 'pseudo';
  static const String musicKey = 'musicEnabled';
  static const String effectsKey = 'soundEffectsEnabled';
  static const String vibrationKey = 'vibrationEnabled';
  /// Sensibilité de 0 à 100.
  static const String sensitivityKey = 'paddleSensitivity100';

  /// Ancien cran de sensibilité (0 à 4), lu seulement si [sensitivityKey]
  /// est absente.
  static const String legacySensitivityKey = 'paddleSensitivity';

  // --- Pseudo ---------------------------------------------------------------
  /// Longueur maximale d'un pseudo : il tient sur une ligne du classement.
  static const int pseudoMaxLength = 20;

  /// Pseudo enregistré, ou `null` s'il n'y en a pas encore.
  String? get pseudo {
    final value = _box.get(pseudoKey);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  /// Enregistre [raw] nettoyé ; renvoie le pseudo gardé, ou `null` (rien
  /// n'est enregistré) s'il est vide.
  String? savePseudo(String raw) {
    final pseudo = cleanPseudo(raw);
    if (pseudo != null) _box.put(pseudoKey, pseudo);
    return pseudo;
  }

  /// Règles de l'accueil : espaces retirés aux bords, non vide, au plus
  /// [pseudoMaxLength] caractères. `null` si le pseudo est refusé.
  static String? cleanPseudo(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= pseudoMaxLength) return trimmed;
    return trimmed.substring(0, pseudoMaxLength).trimRight();
  }

  // --- Son ------------------------------------------------------------------
  /// Musiques d'ambiance, de pause et de chargement.
  bool get musicEnabled => _readBool(musicKey);
  set musicEnabled(bool value) => _box.put(musicKey, value);

  /// Effets sonores : renvoi, clic, record, fin de partie…
  bool get soundEffectsEnabled => _readBool(effectsKey);
  set soundEffectsEnabled(bool value) => _box.put(effectsKey, value);

  // --- Vibration ------------------------------------------------------------
  /// Retour haptique au renvoi, au record et à la fin de partie.
  bool get vibrationEnabled => _readBool(vibrationKey);
  set vibrationEnabled(bool value) => _box.put(vibrationKey, value);

  // --- Sensibilité de la raquette -----------------------------------------
  /// Sensibilité choisie, de 0 (douce) à 100 (vive). Sans valeur 0-100
  /// enregistrée, l'ancien cran (0 à 4) est converti
  /// ([PaddleSensitivity.fromLegacyNotch]) ; sinon, la valeur par défaut.
  int get paddleSensitivity {
    final value = _box.get(sensitivityKey);
    if (value is int) return PaddleSensitivity.clamp(value);
    final legacy = _box.get(legacySensitivityKey);
    if (legacy is int) {
      final converted = PaddleSensitivity.fromLegacyNotch(legacy);
      if (converted != null) return converted;
    }
    return PaddleSensitivity.defaultValue;
  }

  set paddleSensitivity(int value) =>
      _box.put(sensitivityKey, PaddleSensitivity.clamp(value));

  bool _readBool(String key) {
    final value = _box.get(key);
    return value is bool ? value : true;
  }
}
