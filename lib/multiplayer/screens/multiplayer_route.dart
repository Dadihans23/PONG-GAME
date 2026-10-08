import 'package:flutter/material.dart';

import 'multiplayer_menu_screen.dart';

/// Point d'entrée du multijoueur depuis l'accueil (« Jouer » avec la carte
/// Multijoueur sélectionnée). L'accueil attend le retour de cette route
/// pour relancer sa musique et rafraîchir le bilan victoires / défaites.
///
/// TODO(branchement) : remplacer les callbacks vides par le contrôleur
/// multijoueur (création du salon, recherche des parties).
Route<void> multiplayerMenuRoute({required String playerName}) {
  return MaterialPageRoute<void>(
    builder: (context) => MultiplayerMenuScreen(
      playerName: playerName,
      // TODO(branchement) : créer la partie et ouvrir le salon (LobbyScreen).
      onCreate: () {},
      // TODO(branchement) : lancer la recherche et ouvrir JoinScreen.
      onJoin: () {},
    ),
  );
}
