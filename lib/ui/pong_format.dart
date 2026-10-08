// Mise en forme des chiffres et dates affichés au joueur, en français.
//
// - `PongFormat.number(2400)` → « 2 400 » (espace insécable entre milliers) ;
// - `PongFormat.date(d)` → « 12/09/2026 » ;
// - `PongFormat.duration(ms)` → « 1h 12m 5s », « 3m 20s », « 45s » ;
// - `PongFormat.count(23, 'renvoi', 'renvois')` → « 23 renvois ».
abstract final class PongFormat {
  /// Espace insécable : un score ne se coupe jamais en fin de ligne.
  static const String nbsp = ' ';

  /// Nombre entier avec séparateur de milliers.
  static String number(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(nbsp);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Date au format jj/mm/aaaa.
  static String date(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}';

  /// Durée lisible, sans les unités nulles de tête.
  static String duration(int milliseconds) {
    final d = Duration(milliseconds: milliseconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Quantité suivie du mot au singulier (0 ou 1) ou au pluriel.
  static String count(int value, String singular, String plural) =>
      '${number(value)}$nbsp${value <= 1 ? singular : plural}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
