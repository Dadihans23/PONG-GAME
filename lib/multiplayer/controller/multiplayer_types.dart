/// Valeurs lisibles par les écrans du multijoueur : étapes, incidents,
/// résultat du duel. Aucune dépendance à Flutter ni au réseau.
library;

export '../../net/peer_link.dart' show DisconnectReason;

/// Rôle de ce téléphone dans la partie.
enum MultiplayerRole {
  /// Il a créé la partie et fait tourner le moteur (joueur 1).
  host,

  /// Il a rejoint la partie d'un autre (joueur 2).
  guest,
}

/// Étape du parcours, c'est-à-dire l'écran à montrer.
enum MultiplayerStage {
  /// Rien en cours : menu multijoueur (M1).
  idle,

  /// L'hôte ouvre sa partie (quelques millisecondes).
  creating,

  /// L'invité cherche des parties (J1, J2, J3 selon `browseStatus`).
  browsing,

  /// L'invité se connecte à une partie (J2, ligne en attente).
  connecting,

  /// Salon (L1, L2, L3).
  lobby,

  /// Compte à rebours 3-2-1, synchronisé sur les deux téléphones (L4).
  countdown,

  /// Duel en cours (D1, et D2 pendant la pause qui suit un point).
  playing,

  /// Duel terminé (V1, V2).
  finished,

  /// Incident à afficher (X1, X2, X3) : voir `incident`.
  incident,
}

/// Incident affiché à l'étape [MultiplayerStage.incident].
enum MultiplayerIncident {
  /// X1, côté hôte : l'invité est parti pendant le compte à rebours, le duel
  /// ou l'écran de fin. La partie reste ouverte ; action : retour au salon.
  opponentLeft,

  /// X2, côté invité : l'hôte a quitté (ou la connexion avec lui est
  /// perdue, voir `incidentReason`). La partie est terminée ; action :
  /// retour au menu.
  hostLeft,

  /// X3 : impossible de rejoindre la partie (voir `joinFailure`). Actions :
  /// réessayer, retour à la liste.
  joinFailed,

  /// X3 (même gabarit) : impossible d'ouvrir une partie ou de chercher
  /// (Wi-Fi coupé, port indisponible). Actions : réessayer, retour.
  networkUnavailable,

  /// L'app est passée en arrière-plan : la partie a été fermée (pas de pause
  /// en duel). Action : retour au menu.
  closedInBackground,
}

/// Pourquoi l'invité n'a pas pu rejoindre.
enum JoinFailure {
  /// Hôte injoignable, délai dépassé, réseau différent.
  unreachable,

  /// Deux joueurs sont déjà dans la partie.
  full,

  /// L'autre téléphone n'a pas la même version de l'app.
  versionMismatch,

  /// Refus pour une autre raison (partie en train de fermer…).
  refused,
}

/// État de la recherche de parties.
enum BrowseStatus {
  /// Recherche en cours, rien trouvé pour l'instant (J1).
  searching,

  /// Au moins une partie trouvée (J2).
  found,

  /// Rien trouvé après le délai de recherche, ou les parties ont disparu (J3).
  empty,
}

/// Où en est la revanche, sur l'écran de fin.
enum RematchStatus {
  /// Personne n'a demandé.
  none,

  /// J'ai demandé : « Tu veux rejouer · X n'a pas encore répondu ».
  waitingForOpponent,

  /// L'autre a demandé : « X veut rejouer ».
  opponentAsked,
}

/// Indicateur réseau du duel (D1) : rouge seulement en cas de souci.
enum ConnectionQuality { good, degraded }

/// Bord de l'écran de ce téléphone.
enum ScreenEdge { top, bottom }

/// Pause qui suit un point (D2), vue de ce téléphone.
class PointInfo {
  const PointInfo({
    required this.scoredByMe,
    required this.scorerName,
    required this.exitEdge,
    required this.resumeIn,
  });

  /// « POINT POUR <moi> » ou « POINT POUR <l'autre> ».
  final bool scoredByMe;
  final String scorerName;

  /// Bord par lequel la balle est sortie (côté du perdant du point), d'où
  /// vient le halo : en haut si j'ai marqué, en bas sinon.
  final ScreenEdge exitEdge;

  /// « Reprise dans n… » : secondes restantes, arrondies au supérieur (2, 1).
  final int resumeIn;

  @override
  bool operator ==(Object other) =>
      other is PointInfo &&
      other.scoredByMe == scoredByMe &&
      other.scorerName == scorerName &&
      other.exitEdge == exitEdge &&
      other.resumeIn == resumeIn;

  @override
  int get hashCode => Object.hash(scoredByMe, scorerName, exitEdge, resumeIn);

  @override
  String toString() =>
      'PointInfo(${scoredByMe ? 'moi' : scorerName}, ${exitEdge.name}, reprise dans $resumeIn)';
}

/// Résultat d'un duel terminé (V1, V2), vu de ce téléphone.
class DuelResult {
  const DuelResult({
    required this.won,
    required this.winnerName,
    required this.myScore,
    required this.opponentScore,
    required this.duration,
    required this.longestRally,
  });

  /// Victoire (V1) ou défaite (V2).
  final bool won;

  /// « <winnerName> gagne ! »
  final String winnerName;
  final int myScore;
  final int opponentScore;

  /// Durée du duel en temps de jeu (identique sur les deux téléphones).
  final Duration duration;

  /// « plus long échange : n renvois ».
  final int longestRally;

  @override
  bool operator ==(Object other) =>
      other is DuelResult &&
      other.won == won &&
      other.winnerName == winnerName &&
      other.myScore == myScore &&
      other.opponentScore == opponentScore &&
      other.duration == duration &&
      other.longestRally == longestRally;

  @override
  int get hashCode => Object.hash(
      won, winnerName, myScore, opponentScore, duration, longestRally);

  @override
  String toString() =>
      'DuelResult(${won ? 'victoire' : 'défaite'}, $winnerName, $myScore-$opponentScore, '
      '$duration, échange $longestRally)';
}
