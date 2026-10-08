import 'peer_link.dart';
import 'protocol.dart';

/// Événement d'une session (Host ou Client), à écouter par l'écran ou le
/// contrôleur de partie.
sealed class SessionEvent {
  const SessionEvent();
}

/// Le pair est connecté et accepté.
/// Host : un Client a envoyé un `join` valide. Client : le Host a répondu
/// `welcome`.
class PeerConnected extends SessionEvent {
  const PeerConnected(this.name);

  /// Pseudo du pair.
  final String name;
}

/// Le pair est parti ou la connexion est perdue.
/// Host : le Client est parti, le Host reste en écoute (retour au salon).
/// Client : le Host est parti, la session est terminée.
class PeerDisconnected extends SessionEvent {
  const PeerDisconnected(this.reason);

  final DisconnectReason reason;
}

/// Message de jeu reçu du pair, déjà validé et filtré selon le rôle.
class MessageReceived extends SessionEvent {
  const MessageReceived(this.message);

  final NetMessage message;
}
