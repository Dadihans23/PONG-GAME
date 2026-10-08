/// Découverte des parties, vue du jeu : une partie annoncée, un annonceur
/// (côté Host) et un chercheur (côté Client).
///
/// Implémentations :
/// - `DiscoveryAnnouncer` / `DiscoveryBrowser` : broadcast UDP sur le réseau
///   local (`discovery.dart`) ;
/// - `MemoryDiscovery` : en mémoire, pour les tests.
///
/// Un futur serveur en ligne (liste des salons) n'aura qu'à implémenter ces
/// deux interfaces.
library;

import 'protocol.dart';

/// Une partie trouvée sur le réseau.
class DiscoveredGame {
  const DiscoveredGame({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.players,
    required this.maxPlayers,
    required this.version,
  });

  /// Identifiant aléatoire de l'annonce (une partie = un id).
  final String id;

  /// « Partie de <pseudo> ».
  final String name;

  /// Adresse IP du Host, lue sur le paquet reçu (pas dans son contenu).
  final String address;

  /// Port WebSocket du Host.
  final int port;
  final int players;
  final int maxPlayers;

  /// Version du protocole du Host.
  final int version;

  bool get isFull => players >= maxPlayers;

  /// Faux si le Host a une autre version de l'app : le rejoindre sera refusé.
  bool get isCompatible => version == protocolVersion;

  /// Peut-on tenter de la rejoindre ? (Ni pleine, ni d'une autre version.)
  bool get isJoinable => !isFull && isCompatible;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredGame &&
      other.id == id &&
      other.name == name &&
      other.address == address &&
      other.port == port &&
      other.players == players &&
      other.maxPlayers == maxPlayers &&
      other.version == version;

  @override
  int get hashCode => Object.hash(id, name, address, port, players, maxPlayers, version);

  @override
  String toString() => 'DiscoveredGame($name, $address:$port, $players/$maxPlayers, v$version)';
}

/// Côté Host : rend la partie visible des joueurs à proximité.
abstract interface class GameAdvertiser {
  /// Commence à annoncer. Peut lever une exception si le réseau est
  /// indisponible.
  Future<void> start();

  /// Met à jour le nombre de joueurs (ou le nom) et l'annonce aussitôt.
  void update({int? players, String? gameName});

  /// Arrête d'annoncer. Idempotent.
  Future<void> stop();
}

/// Côté Client : tient la liste des parties à proximité.
abstract interface class GameFinder {
  /// Liste des parties, émise à chaque changement.
  Stream<List<DiscoveredGame>> get games;

  /// Liste actuelle, triée par nom.
  List<DiscoveredGame> get current;

  /// Commence à chercher. Peut lever une exception si le réseau est
  /// indisponible.
  Future<void> start();

  /// Vide la liste et relance la recherche (bouton « Actualiser »).
  void refresh();

  /// Arrête de chercher. Idempotent.
  Future<void> stop();
}
