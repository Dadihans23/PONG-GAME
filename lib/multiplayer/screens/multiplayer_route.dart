import 'package:flutter/material.dart';

import '../multiplayer_flow.dart';

/// Point d'entrée du multijoueur depuis l'accueil (« Jouer » avec la carte
/// Multijoueur sélectionnée). L'accueil attend le retour de cette route
/// pour relancer sa musique et rafraîchir le bilan victoires / défaites.
///
/// Une seule route pour tout le parcours : [MultiplayerFlow] affiche le
/// menu, la recherche, le salon, le duel et la fin selon l'étape du
/// contrôleur, qu'il crée à l'entrée et libère à la sortie.
Route<void> multiplayerMenuRoute({required String playerName}) {
  return MaterialPageRoute<void>(
    builder: (context) => MultiplayerFlow(playerName: playerName),
  );
}
