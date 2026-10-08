/// Événements ponctuels du multijoueur, pour les sons et les vibrations.
///
/// Le contrôleur ne joue aucun son : l'écran écoute
/// `MultiplayerController.events` et appelle `GameSound` / la vibration
/// selon `PongSettings`.
library;

sealed class MultiplayerEvent {
  const MultiplayerEvent();
}

/// Côté hôte : un joueur vient de rejoindre le salon (L2, vibration courte).
class OpponentJoined extends MultiplayerEvent {
  const OpponentJoined(this.name);

  final String name;

  @override
  String toString() => 'OpponentJoined($name)';
}

/// L'autre joueur est parti (salon, duel ou écran de fin).
class OpponentLeft extends MultiplayerEvent {
  const OpponentLeft(this.name);

  final String name;

  @override
  String toString() => 'OpponentLeft($name)';
}

/// Un chiffre du compte à rebours s'affiche (3, 2, 1) : « bip » + vibration.
/// Émis au même instant sur les deux téléphones, à la latence près.
class CountdownTick extends MultiplayerEvent {
  const CountdownTick(this.value);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is CountdownTick && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CountdownTick($value)';
}

/// Fin du compte à rebours : la balle part.
class DuelStarted extends MultiplayerEvent {
  const DuelStarted();

  @override
  bool operator ==(Object other) => other is DuelStarted;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'DuelStarted()';
}

/// Une raquette a renvoyé la balle ([mine] : la mienne, pour la vibration).
class PaddleHit extends MultiplayerEvent {
  const PaddleHit({required this.mine});

  final bool mine;

  @override
  bool operator ==(Object other) => other is PaddleHit && other.mine == mine;

  @override
  int get hashCode => mine.hashCode;

  @override
  String toString() => 'PaddleHit(${mine ? 'moi' : 'adversaire'})';
}

/// Un point a été marqué ([mine] : par moi).
class PointScored extends MultiplayerEvent {
  const PointScored({required this.mine});

  final bool mine;

  @override
  bool operator ==(Object other) => other is PointScored && other.mine == mine;

  @override
  int get hashCode => mine.hashCode;

  @override
  String toString() => 'PointScored(${mine ? 'moi' : 'adversaire'})';
}

/// Le duel est terminé : victoire ([won]) ou défaite.
class DuelEnded extends MultiplayerEvent {
  const DuelEnded({required this.won});

  final bool won;

  @override
  bool operator ==(Object other) => other is DuelEnded && other.won == won;

  @override
  int get hashCode => won.hashCode;

  @override
  String toString() => 'DuelEnded(${won ? 'victoire' : 'défaite'})';
}

/// L'autre joueur demande la revanche.
class RematchRequested extends MultiplayerEvent {
  const RematchRequested(this.name);

  final String name;

  @override
  String toString() => 'RematchRequested($name)';
}
