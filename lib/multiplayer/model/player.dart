import 'json_read.dart';

/// Place d'un joueur dans le duel.
///
/// - [player1] : le Host, qui crée la partie et fait tourner le moteur ;
///   sa raquette est **en bas** du terrain (`y = 1`).
/// - [player2] : le Client, qui rejoint la partie ; sa raquette est **en
///   haut** du terrain (`y = -1`). Il se voit en bas grâce à la vue
///   inversée (`DuelView`), jamais dans le moteur ni dans le protocole.
enum PlayerSlot {
  player1,
  player2;

  /// L'adversaire.
  PlayerSlot get opponent => this == player1 ? player2 : player1;
}

/// Un joueur du salon : identifiant, pseudo et statut « Prêt ».
class Player {
  const Player({required this.id, required this.name, this.ready = false});

  /// Longueur maximale d'un identifiant reçu du réseau.
  static const int maxIdLength = 64;

  /// Longueur maximale d'un pseudo (même règle que l'accueil,
  /// `PongSettings.pseudoMaxLength`, qui ne peut pas être importé ici sans Flutter).
  static const int maxNameLength = 20;

  final String id;
  final String name;
  final bool ready;

  Player copyWith({bool? ready}) => Player(id: id, name: name, ready: ready ?? this.ready);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ready': ready};

  /// Lève une [FormatException] si [json] est invalide.
  factory Player.fromJson(Object? json) {
    final map = readObject(json, 'Joueur');
    return Player(
      id: readString(map, 'id', maxLength: maxIdLength),
      name: readString(map, 'name', maxLength: maxNameLength),
      ready: readBool(map, 'ready'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Player && other.id == id && other.name == name && other.ready == ready;

  @override
  int get hashCode => Object.hash(id, name, ready);

  @override
  String toString() => 'Player($id, $name, prêt: $ready)';
}
