import 'duel_phase.dart';
import 'json_read.dart';
import 'player.dart';

/// Salon d'un duel : le Host (joueur 1), le joueur 2 s'il est là, et la
/// phase de la partie.
///
/// Le Host tient le salon de référence et le modifie par les méthodes
/// ci-dessous ; chacune respecte les transitions de [DuelPhase] et lève une
/// [StateError] si l'action n'est pas permise dans la phase actuelle. Le
/// Client reçoit le salon par [GameRoom.fromJson].
class GameRoom {
  GameRoom({required this.id, required Player host})
      : _host = host.copyWith(ready: false),
        _phase = DuelPhase.waiting;

  GameRoom._(this.id, this._host, this._guest, this._phase);

  /// Longueur maximale d'un identifiant de salon reçu du réseau.
  static const int maxIdLength = 64;

  final String id;
  Player _host;
  Player? _guest;
  DuelPhase _phase;

  Player get host => _host;
  Player? get guest => _guest;
  DuelPhase get phase => _phase;

  /// Nombre de joueurs présents (1 ou 2), pour la liste des parties.
  int get playerCount => _guest == null ? 1 : 2;

  /// Joueur à la place [slot] (le joueur 2 peut être absent).
  Player? playerIn(PlayerSlot slot) =>
      slot == PlayerSlot.player1 ? _host : _guest;

  /// Place du joueur [playerId], ou `null` s'il n'est pas dans le salon.
  PlayerSlot? slotOf(String playerId) {
    if (_host.id == playerId) return PlayerSlot.player1;
    if (_guest?.id == playerId) return PlayerSlot.player2;
    return null;
  }

  void _goTo(DuelPhase next) {
    if (!_phase.canTransitionTo(next)) {
      throw StateError('Transition interdite : ${_phase.name} → ${next.name}');
    }
    _phase = next;
  }

  /// Le joueur 2 rejoint le salon (phase `waiting` uniquement).
  void join(Player guest) {
    if (guest.id == _host.id) {
      throw StateError('Le joueur 2 a le même identifiant que le Host');
    }
    _goTo(DuelPhase.playerJoined);
    _guest = guest.copyWith(ready: false);
  }

  /// Change le statut « Prêt » d'un joueur, dans le salon uniquement. La
  /// phase passe à `ready` quand les deux sont prêts, et revient à
  /// `playerJoined` si l'un se retire.
  void setReady(String playerId, bool ready) {
    if (!_phase.isLobby) {
      throw StateError('« Prêt » impossible en phase ${_phase.name}');
    }
    switch (slotOf(playerId)) {
      case PlayerSlot.player1:
        _host = _host.copyWith(ready: ready);
      case PlayerSlot.player2:
        _guest = _guest!.copyWith(ready: ready);
      case null:
        throw StateError('Joueur inconnu : $playerId');
    }
    final bool allReady = _host.ready && _guest!.ready;
    if (allReady && _phase == DuelPhase.playerJoined) {
      _goTo(DuelPhase.ready);
    } else if (!allReady && _phase == DuelPhase.ready) {
      _goTo(DuelPhase.playerJoined);
    }
  }

  /// Les deux joueurs sont prêts : le compte à rebours commence.
  void startCountdown() => _goTo(DuelPhase.countdown);

  /// Fin du compte à rebours : la partie commence.
  void startPlaying() => _goTo(DuelPhase.playing);

  /// Un joueur a gagné.
  void finish() => _goTo(DuelPhase.finished);

  /// « Rejouer » : retour au salon avec les mêmes joueurs, chacun doit
  /// appuyer de nouveau sur « Prêt ».
  void rematch() {
    _goTo(DuelPhase.playerJoined);
    _clearReady();
  }

  /// Le joueur 2 quitte. Dans le salon, le Host attend un autre joueur ;
  /// pendant le compte à rebours, la partie ou l'écran de fin, la partie
  /// passe en `disconnected`.
  void guestLeft() {
    if (_guest == null) {
      throw StateError('Aucun joueur 2 dans le salon');
    }
    _goTo(_phase.isLobby ? DuelPhase.waiting : DuelPhase.disconnected);
    _guest = null;
    _clearReady();
  }

  /// Connexion perdue avec l'autre téléphone (côté Client : le Host est parti).
  void disconnect() => _goTo(DuelPhase.disconnected);

  /// Le Host rouvre son salon après une déconnexion (phase `disconnected`
  /// uniquement : dans le salon, c'est [guestLeft] qui ramène à `waiting`).
  void reopen() {
    if (_phase != DuelPhase.disconnected) {
      throw StateError('Rouvrir le salon impossible en phase ${_phase.name}');
    }
    _goTo(DuelPhase.waiting);
    _guest = null;
    _clearReady();
  }

  void _clearReady() {
    _host = _host.copyWith(ready: false);
    _guest = _guest?.copyWith(ready: false);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phase': _phase.name,
        'host': _host.toJson(),
        'guest': _guest?.toJson(),
      };

  /// Lève une [FormatException] si [json] est invalide ou incohérent
  /// (joueur 2 absent d'une partie en cours, phase `ready` sans deux
  /// joueurs prêts…).
  factory GameRoom.fromJson(Object? json) {
    final map = readObject(json, 'Salon');
    final String id = readString(map, 'id', maxLength: maxIdLength);
    final DuelPhase phase = readEnum(map, 'phase', DuelPhase.values);
    final Player host = Player.fromJson(map['host']);
    final Object? guestJson = map['guest'];
    final Player? guest = guestJson == null ? null : Player.fromJson(guestJson);

    final bool needsGuest =
        phase != DuelPhase.waiting && phase != DuelPhase.disconnected;
    if (needsGuest && guest == null) {
      throw FormatException('Salon en phase ${phase.name} sans joueur 2');
    }
    if (phase == DuelPhase.waiting && guest != null) {
      throw const FormatException('Salon en attente avec un joueur 2');
    }
    if (guest != null && guest.id == host.id) {
      throw const FormatException('Les deux joueurs ont le même identifiant');
    }
    if (phase == DuelPhase.ready && !(host.ready && guest!.ready)) {
      throw const FormatException(
          'Salon en phase ready sans deux joueurs prêts');
    }
    return GameRoom._(id, host, guest, phase);
  }

  @override
  String toString() => 'GameRoom($id, ${_phase.name}, $_host, $_guest)';
}
