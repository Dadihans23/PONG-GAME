// Langues de l'app : français (langue d'origine), anglais, espagnol.
//
// Un seul import pour les écrans :
//
//   import 'package:pong_game/l10n/l10n.dart';
//
//   Text(context.l10n.homePlay)
//
// Les textes vivent dans lib/l10n/app_fr.arb (modèle), app_en.arb et
// app_es.arb ; la classe AppLocalizations est générée par `flutter gen-l10n`
// (voir l10n.yaml). Jamais de texte affiché écrit en dur dans un écran.
//
// Ne passent jamais par ces textes : les valeurs enregistrées (Hive) ou
// envoyées sur le réseau (difficulté « Facile », nom de partie « Partie de
// Tom », pseudo « Joueur »…). Chaque téléphone traduit à l'affichage.
import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Langues proposées, dans l'ordre du sélecteur des Réglages.
const List<String> supportedLanguageCodes = ['fr', 'en', 'es'];

/// Langue de secours quand le téléphone est dans une autre langue.
const String fallbackLanguageCode = 'en';

/// Langue choisie dans les Réglages, enregistrée dans la boîte `settings`
/// sous la clé `language` ([code]).
enum AppLanguage {
  /// Suit la langue du téléphone (valeur par défaut).
  system('system', null),
  french('fr', 'Français'),
  english('en', 'English'),
  spanish('es', 'Español');

  const AppLanguage(this.code, this.nativeName);

  /// Valeur enregistrée : `system`, `fr`, `en` ou `es`.
  final String code;

  /// Nom de la langue écrit dans cette langue, jamais traduit (le joueur
  /// doit reconnaître la sienne). `null` pour [system].
  final String? nativeName;

  /// Langue imposée à l'app, `null` pour suivre le téléphone.
  Locale? get locale => this == system ? null : Locale(code);

  /// Valeur lue dans Hive ; toute valeur inconnue revient à [system].
  static AppLanguage fromCode(Object? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return system;
  }

  /// Langue d'un code `fr`, `en` ou `es` (sinon l'anglais).
  static AppLanguage ofLanguageCode(String code) {
    for (final language in values) {
      if (language != system && language.code == code) return language;
    }
    return english;
  }
}

/// Langue affichée par l'app pour les langues préférées du téléphone :
/// la première que l'app parle (quel que soit le pays : fr_CI, es_MX,
/// en_GB…), sinon l'anglais. Le pays est gardé : il règle le format des
/// dates (en_GB : jour avant le mois).
Locale resolveAppLocale(Iterable<Locale>? preferred) {
  for (final locale in preferred ?? const <Locale>[]) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return locale.countryCode == null || locale.countryCode!.isEmpty
          ? Locale(locale.languageCode)
          : Locale(locale.languageCode, locale.countryCode);
    }
  }
  return const Locale(fallbackLanguageCode);
}

/// Langue effective (`fr`, `en` ou `es`) pour un choix des Réglages et les
/// langues du téléphone.
String effectiveLanguageCode(AppLanguage choice, Iterable<Locale>? device) =>
    choice == AppLanguage.system
        ? resolveAppLocale(device).languageCode
        : choice.code;

/// Langue choisie, écoutée par l'app : la changer dans les Réglages
/// re-traduit tout de suite tous les écrans, sans redémarrer.
abstract final class AppLanguageSetting {
  static final ValueNotifier<AppLanguage> current =
      ValueNotifier(AppLanguage.system);
}

extension AppLocalizationsContext on BuildContext {
  /// Textes dans la langue de l'app.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppLocalizationsHelpers on AppLocalizations {
  /// Libellé d'une difficulté interne (« Facile », « Normal », « Difficile »,
  /// valeurs du moteur, jamais traduites).
  String difficultyLabel(String difficulty) => switch (difficulty) {
        'Facile' => difficultyEasy,
        'Normal' => difficultyNormal,
        _ => difficultyHard,
      };

  /// Rang au classement (1 à 10) : « 1er », « 2e » (fr), « 2nd » (en),
  /// « 2.º » (es). Lettres normales : Archivo n'a pas les exposants « ᵉʳ ».
  String rankLabel(int rank) => rankOrdinal('$rank');

  /// « Partie de Tom », « Partie d'Inès », « Tom's game »…
  String gameOfName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty
        ? gameOfOpponent
        : gameOf(frenchElision(trimmed), trimmed);
  }

  /// « En attente de Tom… », « Waiting for Tom… »…
  String waitingForName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty
        ? waitingForOpponent
        : waitingFor(frenchElision(trimmed), trimmed);
  }
}

// Voyelles, accentuées ou non : en français, « de » devient « d' » devant
// elles. Ni « h » (« de Hugo ») ni « y » (« de Yanis ») : on garde « de ».
const String _frenchVowels = 'aeiouàâäéèêëîïôöùûüæœ';

/// `yes` si un nom commence par une voyelle (« d'Inès »), sinon `other` :
/// choix des messages `gameOf` et `waitingFor`, utilisé par le français
/// seulement.
String frenchElision(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'other';
  final first = trimmed.characters.first.toLowerCase();
  return _frenchVowels.contains(first) ? 'yes' : 'other';
}

/// Coupe un message autour d'une valeur mise en avant (pseudo en gras,
/// gain en or…), quelle que soit sa place dans la phrase de chaque langue.
///
/// ```dart
/// final parts = splitAround(l10n.mpPlayingAs, playerName);
/// Text.rich(TextSpan(text: parts.before, children: [
///   TextSpan(text: playerName, style: bold),
///   TextSpan(text: parts.after),
/// ]));
/// ```
({String before, String after}) splitAround(
    String Function(String value) message, String value) {
  const marker = '\u{E000}';
  final text = message(marker);
  final index = text.indexOf(marker);
  if (index < 0) return (before: text, after: '');
  return (
    before: text.substring(0, index),
    after: text.substring(index + marker.length),
  );
}
