// Mise en forme des chiffres, dates et durées affichés au joueur, selon la
// langue de l'app (français, anglais, espagnol).
//
// ```dart
// final format = PongFormat.of(context);
// format.number(2400);              // « 2 400 » (fr, es), « 2,400 » (en)
// format.date(d);                   // « 12/09/2026 » (fr, es, en_GB), « 9/12/2026 » (en)
// format.duration(ms);              // « 1h 12m 5s », « 3m 20s », « 45s »
// ```
//
// Les quantités avec un mot (« 23 renvois ») sont des messages au pluriel
// de lib/l10n/ : le chiffre leur est passé déjà mis en forme.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class PongFormat {
  /// Mise en forme pour une langue (`fr`, `en_GB`, `es_MX`…).
  const PongFormat(this.locale);

  /// Mise en forme de la langue de l'app, pour [context].
  factory PongFormat.of(BuildContext context) =>
      PongFormat(Localizations.localeOf(context));

  /// Français : la mise en forme d'origine (tests, valeurs par défaut).
  static const PongFormat fr = PongFormat(Locale('fr'));

  final Locale locale;

  /// Espace insécable : un score ne se coupe jamais en fin de ligne.
  static const String nbsp = ' ';

  /// Séparateur de milliers : espace insécable en français et en espagnol
  /// (norme de la RAE, comprise de l'Espagne à l'Amérique latine), virgule
  /// en anglais.
  String get _thousands => locale.languageCode == 'en' ? ',' : nbsp;

  /// Nombre entier avec séparateur de milliers.
  String number(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_thousands);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Date courte, chiffres seuls, dans l'ordre de la langue et du pays
  /// (jj/mm/aaaa en français et en espagnol).
  String date(DateTime date) {
    if (locale.languageCode != 'en') {
      return '${_two(date.day)}/${_two(date.month)}/${date.year}';
    }
    try {
      return DateFormat.yMd(locale.toString()).format(date);
    } catch (_) {
      // Données de date de ce pays absentes : format américain
      return DateFormat.yMd('en').format(date);
    }
  }

  /// Durée lisible, sans les unités nulles de tête. Symboles h, m, s
  /// compris dans les trois langues, et courts pour les petites tuiles.
  String duration(int milliseconds) {
    final d = Duration(milliseconds: milliseconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
