import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/net/protocol.dart';

void main() {
  final logs = <String>[];
  void log(String m) => logs.add(m);

  setUp(logs.clear);

  NetMessage? decode(Object json) => NetMessage.decode(json is String ? json : jsonEncode(json), log: log);

  group('aller-retour encodage / décodage', () {
    final messages = <NetMessage>[
      const JoinMessage(name: 'Hans'),
      const JoinMessage(name: 'Hans', sensitivity: 65),
      const WelcomeMessage(hostName: 'Awa'),
      const RejectMessage(RejectReason.full),
      const RejectMessage(RejectReason.version),
      const ReadyMessage(ready: true),
      const StartMessage(countdown: 3),
      const PaddleMessage(seq: 12, x: -0.75),
      const GameStateMessage(seq: 7, state: {
        'ball': {'x': 0.1, 'y': -0.4},
        'score': [2, 3],
      }),
      const GameOverMessage(winner: PlayerSide.client, state: {'score': [4, 5]}),
      const GameOverMessage(winner: PlayerSide.host),
      const RematchMessage(),
      const LeaveMessage(reason: 'client_left'),
      const LeaveMessage(),
      const PingMessage(1234),
      const PongMessage(1234),
    ];

    for (final message in messages) {
      test(message.type, () {
        final frame = message.encode();
        final json = jsonDecode(frame) as Map<String, dynamic>;
        expect(json['type'], message.type);
        expect(json['v'], protocolVersion);
        final decoded = NetMessage.decode(frame, log: log);
        expect(decoded, isNotNull, reason: logs.join('\n'));
        expect(decoded.runtimeType, message.runtimeType);
        expect(decoded!.toJson(), message.toJson());
      });
    }
  });

  test('les champs inconnus sont tolérés (compatibilité ascendante)', () {
    final m = decode({'v': 1, 'type': 'paddle', 'seq': 1, 'x': 0.5, 'extra': true});
    expect(m, isA<PaddleMessage>());
  });

  test('join est décodé même avec une autre version, pour pouvoir la refuser', () {
    final m = decode({'v': 99, 'type': 'join', 'name': 'Futur'});
    expect(m, isA<JoinMessage>());
    expect((m as JoinMessage).version, 99);
  });

  group('join : sensibilité facultative', () {
    test('sans le champ : null, message valide (Client plus ancien)', () {
      final m = decode({'v': 1, 'type': 'join', 'name': 'Hans'}) as JoinMessage;
      expect(m.sensitivity, isNull);
      expect(const JoinMessage(name: 'Hans').toJson().containsKey('sensitivity'), isFalse);
    });

    test('avec le champ : lu tel quel, même version du protocole', () {
      final m = decode({'v': protocolVersion, 'type': 'join', 'name': 'Hans', 'sensitivity': 65}) as JoinMessage;
      expect(m.sensitivity, 65);
      expect(m.version, protocolVersion);
      final json = jsonDecode(const JoinMessage(name: 'Hans', sensitivity: 65).encode()) as Map<String, dynamic>;
      expect(json['sensitivity'], 65);
      expect(json['v'], 1);
    });

    test('hors bornes : bornée à 0..100, le join reste accepté', () {
      JoinMessage join(Object? value) =>
          decode({'v': 1, 'type': 'join', 'name': 'Hans', 'sensitivity': value}) as JoinMessage;
      expect(join(250).sensitivity, maxPaddleSensitivity);
      expect(join(-7).sensitivity, minPaddleSensitivity);
      expect(join(1e300).sensitivity, 100);
      expect(join(42.6).sensitivity, 43);
    });

    test('valeur illisible : ignorée (null), le join reste accepté', () {
      for (final value in ['vive', true, <int>[], null]) {
        final m = decode({'v': 1, 'type': 'join', 'name': 'Hans', 'sensitivity': value});
        expect(m, isA<JoinMessage>(), reason: '$value');
        expect((m as JoinMessage).sensitivity, isNull, reason: '$value');
      }
    });

    test("à l'envoi, une valeur hors bornes est bornée", () {
      final json = const JoinMessage(name: 'Hans', sensitivity: 400).toJson();
      expect(json['sensitivity'], 100);
    });
  });

  test('le pseudo est nettoyé des espaces', () {
    final m = decode({'v': 1, 'type': 'join', 'name': '  Hans  '}) as JoinMessage;
    expect(m.name, 'Hans');
  });

  test('raison de refus inconnue -> unknown, sans rejeter le message', () {
    final m = decode({'v': 1, 'type': 'reject', 'reason': 'banned'});
    expect((m as RejectMessage).reason, RejectReason.unknown);
  });

  group('trames invalides : ignorées, journalisées, jamais d\'exception', () {
    final invalid = <String, Object>{
      'JSON invalide': '{"type": "paddle", ',
      'texte vide': '',
      'tableau': '[1, 2]',
      'nombre': '42',
      'null': 'null',
      'type absent': {'v': 1, 'seq': 1, 'x': 0},
      'type non texte': {'v': 1, 'type': 3},
      'type inconnu': {'v': 1, 'type': 'teleport'},
      'version absente': {'type': 'ping', 't': 1},
      'version non entière': {'v': '1', 'type': 'ping', 't': 1},
      'autre version': {'v': 2, 'type': 'ping', 't': 1},
      'paddle sans x': {'v': 1, 'type': 'paddle', 'seq': 1},
      'paddle x texte': {'v': 1, 'type': 'paddle', 'seq': 1, 'x': '0.5'},
      'paddle x > 1': {'v': 1, 'type': 'paddle', 'seq': 1, 'x': 1.5},
      'paddle x < -1': {'v': 1, 'type': 'paddle', 'seq': 1, 'x': -3},
      'paddle x infini': '{"v":1,"type":"paddle","seq":1,"x":1e400}',
      'paddle seq négatif': {'v': 1, 'type': 'paddle', 'seq': -1, 'x': 0},
      'paddle seq décimal': {'v': 1, 'type': 'paddle', 'seq': 1.5, 'x': 0},
      'game_state sans state': {'v': 1, 'type': 'game_state', 'seq': 1},
      'game_state state liste': {'v': 1, 'type': 'game_state', 'seq': 1, 'state': [1]},
      'game_over gagnant inconnu': {'v': 1, 'type': 'game_over', 'winner': 'nobody'},
      'game_over state texte': {'v': 1, 'type': 'game_over', 'winner': 'host', 'state': 'x'},
      'start trop long': {'v': 1, 'type': 'start', 'countdown': 11},
      'start négatif': {'v': 1, 'type': 'start', 'countdown': -1},
      'ready non booléen': {'v': 1, 'type': 'ready', 'ready': 'yes'},
      'join sans pseudo': {'v': 1, 'type': 'join'},
      'join pseudo vide': {'v': 1, 'type': 'join', 'name': '   '},
      'join pseudo trop long': {'v': 1, 'type': 'join', 'name': 'x' * 25},
      'welcome sans nom': {'v': 1, 'type': 'welcome'},
      'reject sans raison': {'v': 1, 'type': 'reject'},
      'leave raison non texte': {'v': 1, 'type': 'leave', 'reason': 5},
      'ping sans t': {'v': 1, 'type': 'ping'},
    };

    invalid.forEach((label, json) {
      test(label, () {
        expect(decode(json), isNull);
        expect(logs, isNotEmpty);
      });
    });

    test('trame trop longue', () {
      final big = jsonEncode({'v': 1, 'type': 'game_state', 'seq': 1, 'state': {'pad': 'x' * maxFrameLength}});
      expect(NetMessage.decode(big, log: log), isNull);
      expect(logs.single, contains('trop longue'));
    });
  });

  group('encodage', () {
    test('NaN refusé proprement', () {
      expect(
        () => const GameStateMessage(seq: 1, state: {'x': double.nan}).encode(),
        throwsA(isA<NetEncodeException>()),
      );
    });

    test('message trop long refusé', () {
      expect(
        () => GameStateMessage(seq: 1, state: {'pad': 'x' * maxFrameLength}).encode(),
        throwsA(isA<NetEncodeException>()),
      );
    });

    test('un game_state réaliste tient largement dans la limite', () {
      final frame = const GameStateMessage(seq: 123456, state: {
        'status': 'playing',
        'ball': {'x': -0.123456789, 'y': 0.987654321, 'vx': 0.0012345, 'vy': -0.0023456},
        'paddles': {'host': 0.33333333, 'client': -0.6666666},
        'score': {'host': 4, 'client': 3},
        'events': ['hostHit'],
      }).encode();
      expect(frame.length, lessThan(400));
    });
  });
}
