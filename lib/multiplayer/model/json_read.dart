/// Lecture validante des données JSON reçues du réseau.
///
/// Chaque fonction lève une [FormatException] au message explicite quand le
/// champ manque, n'a pas le bon type ou sort de ses bornes : un message
/// malformé est rejeté proprement, il ne fait jamais planter l'application.
library;

/// [json] doit être un objet JSON ; [what] nomme l'objet dans les erreurs.
Map<dynamic, dynamic> readObject(Object? json, String what) {
  if (json is! Map) {
    throw FormatException(
        '$what : objet JSON attendu, reçu ${json.runtimeType}');
  }
  return json;
}

Object _require(Map<dynamic, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    throw FormatException('Champ « $key » manquant');
  }
  return value;
}

/// Nombre fini entre [min] et [max] (un entier JSON est accepté).
double readDouble(Map<dynamic, dynamic> json, String key,
    {required double min, required double max}) {
  final Object value = _require(json, key);
  if (value is! num) {
    throw FormatException('Champ « $key » : nombre attendu');
  }
  final double number = value.toDouble();
  if (!number.isFinite || number < min || number > max) {
    throw FormatException('Champ « $key » hors bornes ($min à $max) : $number');
  }
  return number;
}

/// Entier entre [min] et [max].
int readInt(Map<dynamic, dynamic> json, String key,
    {required int min, required int max}) {
  final Object value = _require(json, key);
  if (value is! int) {
    throw FormatException('Champ « $key » : entier attendu');
  }
  if (value < min || value > max) {
    throw FormatException('Champ « $key » hors bornes ($min à $max) : $value');
  }
  return value;
}

bool readBool(Map<dynamic, dynamic> json, String key) {
  final Object value = _require(json, key);
  if (value is! bool) {
    throw FormatException('Champ « $key » : booléen attendu');
  }
  return value;
}

/// Texte non vide (après suppression des espaces aux bords) d'au plus [maxLength] caractères.
String readString(Map<dynamic, dynamic> json, String key,
    {required int maxLength}) {
  final Object value = _require(json, key);
  if (value is! String) {
    throw FormatException('Champ « $key » : texte attendu');
  }
  final String text = value.trim();
  if (text.isEmpty || text.length > maxLength) {
    throw FormatException(
        'Champ « $key » : 1 à $maxLength caractères attendus');
  }
  return text;
}

/// Valeur d'énumération écrite par son nom (`Enum.name`).
T readEnum<T extends Enum>(
    Map<dynamic, dynamic> json, String key, List<T> values) {
  final Object value = _require(json, key);
  for (final T candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw FormatException('Champ « $key » : valeur inconnue « $value »');
}
