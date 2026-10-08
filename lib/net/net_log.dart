import 'dart:developer' as developer;

/// Journal de la couche réseau.
///
/// Toute la couche réseau journalise par ce type au lieu d'appeler `print`.
/// Les tests passent leur propre fonction pour vérifier qu'un message
/// invalide a bien été ignoré.
typedef NetLogger = void Function(String message);

/// Journal par défaut : visible dans `flutter logs` / DevTools sous le nom
/// `pong.net`, sans rien afficher en production.
void defaultNetLogger(String message) {
  developer.log(message, name: 'pong.net');
}

/// Journal muet.
void silentNetLogger(String message) {}
