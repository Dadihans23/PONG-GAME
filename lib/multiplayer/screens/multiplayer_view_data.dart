// Données affichées par les écrans du multijoueur (maquette « Pong
// Multijoueur »). Ce sont de petites classes immuables, sans logique de jeu
// ni réseau : le contrôleur multijoueur les construit à partir de son état
// et les passe aux écrans, qui ne font que les afficher et remonter les
// gestes du joueur par des callbacks.
//
// Toutes les données sont vues depuis CE téléphone : « moi » est toujours le
// joueur qui tient l'appareil (bleu, en bas du terrain), « l'autre » son
// adversaire (vert, en haut).
import 'package:flutter/painting.dart';
import 'package:pong_game/multiplayer/duel_view.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Score à atteindre pour gagner un duel (décision de la roadmap).
const int duelTargetScore = 5;

/// Un des deux joueurs, vu depuis ce téléphone.
enum DuelSide {
  /// Le joueur qui tient ce téléphone : bleu, en bas.
  me,

  /// Son adversaire : vert, en haut.
  opponent;

  /// Couleur de sens : raquette, barres, pastilles.
  Color get color => this == me ? PongColors.player : PongColors.opponent;

  /// Variante claire, pour du texte et les chiffres.
  Color get lightColor =>
      this == me ? PongColors.playerLight : PongColors.opponentLight;

  DuelSide get other => this == me ? opponent : me;
}

// ---------------------------------------------------------------------------
// Rejoindre (J1, J2, J3)
// ---------------------------------------------------------------------------

/// Une partie annoncée sur le réseau local.
class DiscoveredGameViewData {
  const DiscoveredGameViewData({
    required this.id,
    required this.hostName,
    this.playerCount = 1,
    this.maxPlayers = 2,
  });

  /// Identifiant transmis tel quel à `onJoin`.
  final String id;

  /// Pseudo du joueur qui a créé la partie (« Partie de Tom »).
  final String hostName;
  final int playerCount;
  final int maxPlayers;

  /// Partie pleine : affichée grisée, « Complète », sans action.
  bool get isFull => playerCount >= maxPlayers;
}

/// État de l'écran Rejoindre.
///
/// | `searching` | `games` | Écran                                         |
/// |-------------|---------|-----------------------------------------------|
/// | oui         | vide    | J1 : ondes, « Recherche de parties… »         |
/// | oui / non   | non vide| J2 : liste, « Actualiser » en secondaire      |
/// | non         | vide    | J3 : aucune partie, conseils, « Actualiser »  |
class JoinViewData {
  const JoinViewData({
    this.searching = true,
    this.games = const [],
    this.joiningId,
  });

  /// La recherche tourne (ondes et point rose qui pulsent).
  final bool searching;
  final List<DiscoveredGameViewData> games;

  /// Partie que le joueur vient de toucher, en cours de connexion : sa
  /// ligne affiche « Connexion… » et les autres « Rejoindre » sont inactifs.
  final String? joiningId;
}

// ---------------------------------------------------------------------------
// Salon (L1 à L4)
// ---------------------------------------------------------------------------

/// Un joueur du salon.
class LobbyPlayerViewData {
  const LobbyPlayerViewData({
    required this.name,
    this.ready = false,
    this.justJoined = false,
  });

  final String name;
  final bool ready;

  /// L'invité vient d'arriver : « Vient de rejoindre » côté hôte.
  final bool justJoined;
}

/// État du salon, vu depuis ce téléphone.
///
/// L'hôte est toujours sur la première ligne, l'invité sur la seconde : côté
/// invité, « toi » est donc en bas, comme sur le terrain (maquette L3).
class LobbyViewData {
  const LobbyViewData({
    required this.isHost,
    required this.me,
    this.other,
    this.countdown,
  });

  /// Ce téléphone a créé la partie.
  final bool isHost;
  final LobbyPlayerViewData me;

  /// L'autre joueur, `null` tant que personne n'a rejoint (hôte seul, L1).
  final LobbyPlayerViewData? other;

  /// Chiffre du compte à rebours (3, 2, 1), `null` hors compte à rebours.
  /// Non nul : l'écran plein « Léa contre Tom » recouvre le salon (L4).
  final int? countdown;

  /// Pseudo de l'hôte, qui donne son nom à la partie.
  String get hostName => isHost ? me.name : (other?.name ?? '');
}

// ---------------------------------------------------------------------------
// Duel (D1, D2)
// ---------------------------------------------------------------------------

/// Qualité de la connexion, indiquée dans la bande du haut.
enum DuelConnection {
  /// Rien à signaler : icône Wi-Fi discrète.
  good,

  /// Messages en retard : icône et mot en rouge.
  weak,
}

/// Bande du haut et scores du duel.
class DuelHudData {
  const DuelHudData({
    required this.myName,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    this.targetScore = duelTargetScore,
    this.connection = DuelConnection.good,
  });

  final String myName;
  final String opponentName;
  final int myScore;
  final int opponentScore;

  /// Score à atteindre : nombre de barres et « PREMIER À 5 ».
  final int targetScore;
  final DuelConnection connection;

  int scoreOf(DuelSide side) => side == DuelSide.me ? myScore : opponentScore;
  String nameOf(DuelSide side) => side == DuelSide.me ? myName : opponentName;
}

/// Positions sur le terrain, déjà dans le repère de CE téléphone : -1 à 1,
/// `y = 1` en bas, ma raquette en bas et celle de l'adversaire en haut.
class DuelFieldData {
  const DuelFieldData({
    required this.ballX,
    required this.ballY,
    required this.myPaddleX,
    required this.opponentPaddleX,
  });

  /// Reprend la vue inversée calculée par `DuelView.of(state, viewer)`.
  DuelFieldData.fromView(DuelView view)
      : ballX = view.ballX,
        ballY = view.ballY,
        myPaddleX = view.myPaddleX,
        opponentPaddleX = view.opponentPaddleX;

  /// Balle et raquettes au centre, avant le premier service.
  static const DuelFieldData initial =
      DuelFieldData(ballX: 0, ballY: 0, myPaddleX: 0, opponentPaddleX: 0);

  final double ballX;
  final double ballY;
  final double myPaddleX;
  final double opponentPaddleX;
}

/// Un point vient d'être marqué (D2) : le score passe au premier plan, sans
/// balle, pendant la remise en jeu.
class DuelPointData {
  const DuelPointData({required this.scorer, this.resumeIn});

  /// Qui a marqué. La balle est sortie du côté de l'autre : le halo vient
  /// de ce bord-là, dans la couleur de [scorer].
  final DuelSide scorer;

  /// Secondes avant la reprise (« Reprise dans 2… »), `null` pour ne rien
  /// afficher.
  final int? resumeIn;
}

// ---------------------------------------------------------------------------
// Fin du duel (V1, V2)
// ---------------------------------------------------------------------------

/// Où en est la revanche.
enum RematchState {
  /// Personne n'a encore demandé : « Rejouer » en rose.
  none,

  /// J'ai touché « Rejouer » : bouton en attente, « Tom n'a pas encore
  /// répondu ».
  iAsked,

  /// L'autre a demandé le premier : « Tom veut rejouer », « Rejouer » en rose.
  opponentAsked,

  /// L'autre a quitté l'écran de fin : « Rejouer » inactif, avec la raison.
  opponentLeft,
}

/// Résultat d'un duel terminé.
class DuelResultData {
  const DuelResultData({
    required this.myName,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.duration,
    required this.longestRally,
    this.rematch = RematchState.none,
  });

  final String myName;
  final String opponentName;
  final int myScore;
  final int opponentScore;

  /// Durée du duel, du premier service au point gagnant.
  final Duration duration;

  /// Plus long échange, en renvois (les deux raquettes comptent).
  final int longestRally;
  final RematchState rematch;

  bool get won => myScore > opponentScore;
  String get winnerName => won ? myName : opponentName;
}
