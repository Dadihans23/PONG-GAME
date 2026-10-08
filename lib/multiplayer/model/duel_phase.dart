/// Phases d'une partie en duel, et transitions autorisées entre elles.
///
/// ```text
/// waiting ──► playerJoined ◄──► ready ──► countdown ──► playing ──► finished
///    ▲            │               │                                   │
///    └────────────┴───────────────┘  le joueur 2 quitte le salon      │
///                 ▲                                                   │
///                 └─────────────────── Rejouer ───────────────────────┘
///
/// playerJoined, ready, countdown, playing, finished ──► disconnected ──► waiting
/// ```
///
/// La phase est décidée par le Host ; le Client l'applique telle quelle.
enum DuelPhase {
  /// Salon ouvert, le Host attend un second joueur.
  waiting,

  /// Deux joueurs dans le salon, au moins un n'est pas prêt.
  playerJoined,

  /// Les deux joueurs sont prêts.
  ready,

  /// Compte à rebours avant le premier service.
  countdown,

  /// Partie en cours (pas de pause en duel).
  playing,

  /// Un joueur a gagné.
  finished,

  /// L'autre joueur est parti ou la connexion est perdue.
  disconnected;

  static const Map<DuelPhase, Set<DuelPhase>> _allowed = {
    waiting: {playerJoined},
    playerJoined: {waiting, ready, disconnected},
    ready: {waiting, playerJoined, countdown, disconnected},
    countdown: {playing, disconnected},
    playing: {finished, disconnected},
    finished: {playerJoined, disconnected},
    // Le Host rouvre son salon après le départ du joueur 2
    disconnected: {waiting},
  };

  /// La transition vers [next] est-elle autorisée ?
  bool canTransitionTo(DuelPhase next) => _allowed[this]!.contains(next);

  /// Phases du salon, avant le compte à rebours.
  bool get isLobby => this == playerJoined || this == ready;
}
