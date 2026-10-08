/// Abstraction du transport : des trames texte entre deux pairs.
///
/// Le transport ne connaît ni le protocole ni le jeu. Il transporte des
/// chaînes (une trame = un message JSON) et signale la fin de la connexion.
/// Deux implémentations :
/// - `WebSocketTransport` (dart:io) pour le réseau local ;
/// - `MemoryTransport` pour les tests, sans socket.
///
/// Un futur transport en ligne (serveur FastAPI/WebSocket) n'aura qu'à
/// implémenter ces trois interfaces : les sessions et le jeu ne changent pas.
library;

import 'dart:async';

/// Une connexion ouverte avec un pair.
abstract class NetConnection {
  /// Trames texte reçues, dans l'ordre. Le flux se termine quand la
  /// connexion est fermée, par l'un ou l'autre côté. Écoutable une seule fois.
  Stream<String> get frames;

  /// Envoie une trame. Sans effet si la connexion est fermée.
  void send(String frame);

  /// Vrai tant que la connexion n'a pas été fermée.
  bool get isOpen;

  /// Adresse du pair, pour le journal (« 192.168.43.12:51234 »).
  String get remoteDescription;

  /// Se termine quand la connexion est fermée, quelle qu'en soit la cause.
  Future<void> get done;

  /// Ferme la connexion. Idempotent, ne lève jamais d'exception.
  Future<void> close();
}

/// Point d'écoute côté Host : reçoit les connexions entrantes.
abstract class NetListener {
  /// Connexions entrantes. Le flux se termine à la fermeture du point d'écoute.
  Stream<NetConnection> get connections;

  /// Port réellement utilisé (utile si le port demandé était 0 ou occupé).
  int get port;

  /// Arrête d'accepter des connexions. Ne ferme pas les connexions déjà
  /// acceptées : c'est la session qui s'en charge.
  Future<void> close();
}

/// Fabrique de connexions.
abstract class NetTransport {
  /// Ouvre un point d'écoute. Si [port] est occupé, l'implémentation peut
  /// se rabattre sur un port libre : lire [NetListener.port].
  Future<NetListener> listen({required int port});

  /// Se connecte à un Host. Lève [NetConnectException] en cas d'échec ou
  /// si [timeout] est dépassé.
  Future<NetConnection> connect(String host, int port, {required Duration timeout});
}

/// Échec de connexion (Host injoignable, délai dépassé, refus du socket…).
class NetConnectException implements Exception {
  NetConnectException(this.message);

  final String message;

  @override
  String toString() => 'NetConnectException: $message';
}
