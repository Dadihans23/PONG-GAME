/// Protocole du duel en réseau local. Format détaillé : `lib/net/PROTOCOL.md`.
///
/// Chaque message est un objet JSON avec une version `v` et un `type`.
/// Le protocole transporte l'état du jeu sans le comprendre : `game_state`
/// et `game_over` contiennent une charge utile JSON fournie par le moteur.
///
/// Le décodage est défensif : JSON invalide, type inconnu, champ manquant ou
/// valeur hors bornes donnent `null` et une ligne de journal, jamais une
/// exception.
library;

import 'dart:convert';

import 'net_log.dart';

/// Version du protocole. À incrémenter à chaque changement incompatible.
const int protocolVersion = 1;

/// Taille maximale d'une trame, en caractères. Un `game_state` fait
/// quelques centaines d'octets ; au-delà de cette limite le message est
/// ignoré (à la réception) ou refusé (à l'envoi).
const int maxFrameLength = 8192;

/// Longueur maximale d'un pseudo, en caractères.
const int maxNameLength = 24;

/// Durée maximale d'un compte à rebours, en secondes.
const int maxCountdownSeconds = 10;

/// Bornes de la sensibilité de raquette annoncée dans `join` (0 à 100).
const int minPaddleSensitivity = 0;
const int maxPaddleSensitivity = 100;

/// Raison d'un refus de connexion par le Host.
enum RejectReason {
  /// Deux joueurs sont déjà dans la partie.
  full('full'),

  /// Version du protocole différente : les deux apps ne sont pas à jour.
  version('version'),

  /// Message `join` invalide ou absent dans le délai.
  badRequest('bad_request'),

  /// Le Host est en train de fermer la partie.
  closing('closing'),

  /// Raison inconnue (Host plus récent).
  unknown('unknown');

  const RejectReason(this.wire);

  final String wire;

  static RejectReason fromWire(String value) =>
      RejectReason.values.firstWhere((r) => r.wire == value, orElse: () => RejectReason.unknown);
}

/// Côté gagnant d'une partie, du point de vue du réseau.
enum PlayerSide {
  host('host'),
  client('client');

  const PlayerSide(this.wire);

  final String wire;

  static PlayerSide? fromWire(Object? value) {
    for (final side in PlayerSide.values) {
      if (side.wire == value) return side;
    }
    return null;
  }
}

/// Message du protocole.
sealed class NetMessage {
  const NetMessage();

  /// Valeur du champ `type`.
  String get type;

  /// Champs propres au message (sans `v` ni `type`).
  Map<String, Object?> fieldsToJson();

  Map<String, Object?> toJson() => {'v': protocolVersion, 'type': type, ...fieldsToJson()};

  /// Encode le message en une trame. Lève [NetEncodeException] si la valeur
  /// ne peut pas être encodée (NaN, objet non JSON) ou dépasse
  /// [maxFrameLength].
  String encode() {
    String frame;
    try {
      frame = jsonEncode(toJson());
    } on Object catch (e) {
      throw NetEncodeException('$type non encodable : $e');
    }
    if (frame.length > maxFrameLength) {
      throw NetEncodeException('$type trop long : ${frame.length} caractères');
    }
    return frame;
  }

  /// Décode une trame. Retourne `null` (et journalise la raison) si la trame
  /// est invalide. Ne lève jamais d'exception.
  static NetMessage? decode(String frame, {NetLogger log = defaultNetLogger}) {
    try {
      return _decode(frame);
    } on _Invalid catch (e) {
      log('message ignoré : ${e.reason}');
      return null;
    } on Object catch (e) {
      // Filet de sécurité : aucune trame ne doit faire planter l'app.
      log('message ignoré (erreur inattendue) : $e');
      return null;
    }
  }

  static NetMessage _decode(String frame) {
    if (frame.length > maxFrameLength) {
      throw _Invalid('trame trop longue (${frame.length} caractères)');
    }
    Object? raw;
    try {
      raw = jsonDecode(frame);
    } on FormatException {
      throw _Invalid('JSON invalide');
    }
    if (raw is! Map<String, dynamic>) throw _Invalid('la trame n\'est pas un objet JSON');
    final type = raw['type'];
    if (type is! String) throw _Invalid('champ "type" absent');
    final version = raw['v'];
    if (version is! int) throw _Invalid('$type : champ "v" absent');
    final f = _Fields(type, raw);

    // `join` est décodé quelle que soit la version, pour que le Host puisse
    // répondre « version incompatible » au lieu d'ignorer le joueur.
    if (type == JoinMessage.wireType) {
      return JoinMessage(name: f.name('name'), version: version, sensitivity: f.sensitivity('sensitivity'));
    }
    if (version != protocolVersion) {
      throw _Invalid('$type : version $version, attendue $protocolVersion');
    }
    switch (type) {
      case WelcomeMessage.wireType:
        return WelcomeMessage(hostName: f.name('hostName'));
      case RejectMessage.wireType:
        return RejectMessage(RejectReason.fromWire(f.string('reason', maxLength: 32)));
      case ReadyMessage.wireType:
        return ReadyMessage(ready: f.boolean('ready'));
      case StartMessage.wireType:
        return StartMessage(countdown: f.integer('countdown', min: 0, max: maxCountdownSeconds));
      case PaddleMessage.wireType:
        return PaddleMessage(seq: f.seq(), x: f.unitDouble('x'));
      case GameStateMessage.wireType:
        return GameStateMessage(seq: f.seq(), state: f.object('state'));
      case GameOverMessage.wireType:
        final winner = PlayerSide.fromWire(raw['winner']);
        if (winner == null) throw _Invalid('game_over : champ "winner" invalide');
        return GameOverMessage(winner: winner, state: f.optionalObject('state'));
      case RematchMessage.wireType:
        return const RematchMessage();
      case LeaveMessage.wireType:
        return LeaveMessage(reason: f.optionalString('reason', maxLength: 64));
      case PingMessage.wireType:
        return PingMessage(f.integer('t', min: 0, max: _maxSafeInt));
      case PongMessage.wireType:
        return PongMessage(f.integer('t', min: 0, max: _maxSafeInt));
    }
    throw _Invalid('type inconnu "$type"');
  }
}

/// Le Client demande à rejoindre la partie. Premier message du Client.
class JoinMessage extends NetMessage {
  const JoinMessage({required this.name, this.version = protocolVersion, this.sensitivity});

  static const wireType = 'join';

  final String name;

  /// Sensibilité de raquette du Client (0 à 100), facultative : `null` si
  /// le Client ne l'annonce pas (app plus ancienne). Le Host applique alors
  /// la valeur par défaut. Bornée à [minPaddleSensitivity]..[maxPaddleSensitivity].
  final int? sensitivity;

  /// Version du protocole du Client (champ `v` de l'enveloppe).
  final int version;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toJson() => {'v': version, 'type': type, ...fieldsToJson()};

  @override
  Map<String, Object?> fieldsToJson() => {
        'name': name,
        if (sensitivity != null) 'sensitivity': sensitivity!.clamp(minPaddleSensitivity, maxPaddleSensitivity),
      };
}

/// Le Host accepte le Client.
class WelcomeMessage extends NetMessage {
  const WelcomeMessage({required this.hostName});

  static const wireType = 'welcome';

  final String hostName;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'hostName': hostName};
}

/// Le Host refuse le Client, puis ferme la connexion.
class RejectMessage extends NetMessage {
  const RejectMessage(this.reason);

  static const wireType = 'reject';

  final RejectReason reason;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'reason': reason.wire};
}

/// Un joueur signale qu'il est prêt (ou ne l'est plus). Dans les deux sens.
class ReadyMessage extends NetMessage {
  const ReadyMessage({required this.ready});

  static const wireType = 'ready';

  final bool ready;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'ready': ready};
}

/// Le Host lance la partie après un compte à rebours en secondes.
class StartMessage extends NetMessage {
  const StartMessage({required this.countdown});

  static const wireType = 'start';

  final int countdown;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'countdown': countdown};
}

/// Position de la raquette du Client, en coordonnées du court (-1 à 1),
/// jamais inversée.
class PaddleMessage extends NetMessage {
  const PaddleMessage({required this.seq, required this.x});

  static const wireType = 'paddle';

  final int seq;
  final double x;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'seq': seq, 'x': x};
}

/// État du jeu envoyé par le Host. [state] est opaque pour le réseau :
/// c'est le `toJson()` du modèle de jeu.
class GameStateMessage extends NetMessage {
  const GameStateMessage({required this.seq, required this.state});

  static const wireType = 'game_state';

  final int seq;
  final Map<String, dynamic> state;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'seq': seq, 'state': state};
}

/// Fin de partie décidée par le Host. [state] est opaque (état final).
class GameOverMessage extends NetMessage {
  const GameOverMessage({required this.winner, this.state});

  static const wireType = 'game_over';

  final PlayerSide winner;
  final Map<String, dynamic>? state;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {
        'winner': winner.wire,
        if (state != null) 'state': state,
      };
}

/// Demande de revanche. Dans les deux sens ; le Host décide du départ.
class RematchMessage extends NetMessage {
  const RematchMessage();

  static const wireType = 'rematch';

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => const {};
}

/// Départ volontaire d'un joueur, juste avant la fermeture.
class LeaveMessage extends NetMessage {
  const LeaveMessage({this.reason});

  static const wireType = 'leave';

  final String? reason;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {if (reason != null) 'reason': reason};
}

/// Battement de cœur. [t] est renvoyé tel quel dans le `pong`.
class PingMessage extends NetMessage {
  const PingMessage(this.t);

  static const wireType = 'ping';

  final int t;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'t': t};
}

/// Réponse à un `ping`, avec le même [t].
class PongMessage extends NetMessage {
  const PongMessage(this.t);

  static const wireType = 'pong';

  final int t;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> fieldsToJson() => {'t': t};
}

/// Message impossible à encoder.
class NetEncodeException implements Exception {
  NetEncodeException(this.message);

  final String message;

  @override
  String toString() => 'NetEncodeException: $message';
}

const int _maxSafeInt = 9007199254740991;

class _Invalid implements Exception {
  _Invalid(this.reason);

  final String reason;
}

/// Lecture validée des champs d'un message.
class _Fields {
  _Fields(this.type, this.raw);

  final String type;
  final Map<String, dynamic> raw;

  Never _fail(String key, String what) => throw _Invalid('$type : champ "$key" $what');

  String string(String key, {required int maxLength}) {
    final value = raw[key];
    if (value is! String) _fail(key, 'absent ou non texte');
    if (value.length > maxLength) _fail(key, 'trop long');
    return value;
  }

  String? optionalString(String key, {required int maxLength}) {
    if (raw[key] == null) return null;
    return string(key, maxLength: maxLength);
  }

  /// Pseudo : texte non vide après `trim`, au plus [maxNameLength] caractères.
  String name(String key) {
    final value = string(key, maxLength: maxNameLength * 4).trim();
    if (value.isEmpty) _fail(key, 'vide');
    if (value.length > maxNameLength) _fail(key, 'trop long');
    return value;
  }

  bool boolean(String key) {
    final value = raw[key];
    if (value is! bool) _fail(key, 'absent ou non booléen');
    return value;
  }

  int integer(String key, {required int min, required int max}) {
    final value = raw[key];
    if (value is! int) _fail(key, 'absent ou non entier');
    if (value < min || value > max) _fail(key, 'hors bornes ($value)');
    return value;
  }

  int seq() => integer('seq', min: 0, max: _maxSafeInt);

  /// Réel fini entre -1 et 1 (coordonnée du court).
  double unitDouble(String key) {
    final value = raw[key];
    if (value is! num) _fail(key, 'absent ou non numérique');
    final d = value.toDouble();
    if (!d.isFinite || d < -1 || d > 1) _fail(key, 'hors bornes ($value)');
    return d;
  }

  /// Sensibilité facultative : absente, non numérique ou non finie →
  /// `null` (le message reste valide) ; sinon arrondie et bornée à
  /// [minPaddleSensitivity]..[maxPaddleSensitivity].
  int? sensitivity(String key) {
    final value = raw[key];
    if (value is! num || !value.isFinite) return null;
    return value.clamp(minPaddleSensitivity, maxPaddleSensitivity).round();
  }

  Map<String, dynamic> object(String key) {
    final value = raw[key];
    if (value is! Map<String, dynamic>) _fail(key, 'absent ou non objet');
    return value;
  }

  Map<String, dynamic>? optionalObject(String key) {
    if (raw[key] == null) return null;
    return object(key);
  }
}
