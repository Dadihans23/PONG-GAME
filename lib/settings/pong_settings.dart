import 'package:hive_flutter/hive_flutter.dart';

/// Réglages du joueur, enregistrés dans la boîte Hive `settings` (ouverte
/// dans `main()`).
///
/// Les valeurs par défaut reproduisent le comportement d'origine : son et
/// vibration activés, sensibilité de la raquette au cran du milieu
/// (multiplicateur 1). Une valeur absente ou illisible retombe sur sa
/// valeur par défaut.
///
/// ```dart
/// final settings = PongSettings();
/// if (settings.vibrationEnabled) HapticFeedback.lightImpact();
/// final speed = baseSpeed * settings.paddleSpeedMultiplier;
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
  static const String sensitivityKey = 'paddleSensitivity';

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
  /// Multiplicateur de la vitesse de la raquette, par cran, de « Très
  /// douce » à « Très vive ». Le cran du milieu (1,0) est le réglage
  /// d'origine.
  static const List<double> paddleSpeedMultipliers = [0.6, 0.8, 1.0, 1.25, 1.5];

  /// Nom de chaque cran, dans le même ordre.
  static const List<String> paddleSensitivityLabels = [
    'Très douce',
    'Douce',
    'Normale',
    'Vive',
    'Très vive',
  ];

  /// Cran par défaut : le milieu, comportement d'origine.
  static const int defaultPaddleSensitivity = 2;

  /// Cran choisi, de 0 à 4.
  int get paddleSensitivity {
    final value = _box.get(sensitivityKey);
    if (value is int &&
        value >= 0 &&
        value < paddleSpeedMultipliers.length) {
      return value;
    }
    return defaultPaddleSensitivity;
  }

  set paddleSensitivity(int value) => _box.put(sensitivityKey,
      value.clamp(0, paddleSpeedMultipliers.length - 1).toInt());

  /// Multiplicateur du cran choisi, à appliquer à la vitesse de la raquette.
  double get paddleSpeedMultiplier =>
      paddleSpeedMultipliers[paddleSensitivity];

  bool _readBool(String key) {
    final value = _box.get(key);
    return value is bool ? value : true;
  }
}
