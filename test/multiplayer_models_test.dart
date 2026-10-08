import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/multiplayer/model/duel_phase.dart';
import 'package:pong_game/multiplayer/model/game_room.dart';
import 'package:pong_game/multiplayer/model/game_state.dart';
import 'package:pong_game/multiplayer/model/player.dart';

// Aller-retour par du vrai texte JSON, comme sur le réseau
Object? throughJson(Map<String, dynamic> json) => jsonDecode(jsonEncode(json));

const hans = Player(id: 'host-1', name: 'Hans');
const awa = Player(id: 'client-2', name: 'Awa');

// Décodé depuis du texte : objets modifiables de type Map<String, dynamic>
Map<String, dynamic> validStateJson() => throughJson({
      'tick': 1234,
      'phase': 'playing',
      'ball': {'x': 0.1, 'y': -0.4, 'vx': 0.002, 'vy': -0.0025},
      'paddles': {'p1': 0.3, 'p2': -0.2},
      'score': {'p1': 2, 'p2': 1},
    }) as Map<String, dynamic>;

// Salon de Hans rejoint par Awa
GameRoom joinedRoom() => GameRoom(id: 'salon', host: hans)..join(awa);

// Salon dont les deux joueurs sont prêts
GameRoom readyRoom() => joinedRoom()
  ..setReady(hans.id, true)
  ..setReady(awa.id, true);

GameRoom playingRoom() => readyRoom()
  ..startCountdown()
  ..startPlaying();

void main() {
  group('Player', () {
    test('aller-retour JSON', () {
      const player = Player(id: 'abc', name: 'Hans', ready: true);
      expect(Player.fromJson(throughJson(player.toJson())), player);
    });

    test('pseudo nettoyé des espaces aux bords', () {
      expect(Player.fromJson({'id': 'a', 'name': '  Hans ', 'ready': false}).name, 'Hans');
    });

    test('données invalides : FormatException', () {
      final invalid = <Object?>[
        null,
        'Hans',
        [1, 2],
        {'name': 'Hans', 'ready': false}, // id manquant
        {'id': 'a', 'ready': false}, // pseudo manquant
        {'id': 'a', 'name': 'Hans'}, // prêt manquant
        {'id': '', 'name': 'Hans', 'ready': false},
        {'id': 'a', 'name': '   ', 'ready': false},
        {'id': 'a', 'name': 'x' * 21, 'ready': false},
        {'id': 'a' * 65, 'name': 'Hans', 'ready': false},
        {'id': 42, 'name': 'Hans', 'ready': false},
        {'id': 'a', 'name': 'Hans', 'ready': 'oui'},
      ];
      for (final json in invalid) {
        expect(() => Player.fromJson(json), throwsFormatException, reason: '$json');
      }
    });

    test('adversaire de chaque place', () {
      expect(PlayerSlot.player1.opponent, PlayerSlot.player2);
      expect(PlayerSlot.player2.opponent, PlayerSlot.player1);
    });
  });

  group('GameState', () {
    test('aller-retour JSON', () {
      const state = GameState(
        tick: 98765,
        phase: DuelPhase.playing,
        ballX: -0.123456789,
        ballY: 0.987654321,
        ballVX: 0.0021,
        ballVY: -0.0035,
        paddle1X: 1.0,
        paddle2X: -1.0,
        score1: 4,
        score2: 3,
      );
      expect(GameState.fromJson(throughJson(state.toJson())), state);
    });

    test('lecture d\'un message valide, entiers acceptés pour les positions', () {
      final json = validStateJson();
      (json['ball'] as Map)['x'] = 0;
      (json['paddles'] as Map)['p1'] = 1;
      final state = GameState.fromJson(throughJson(json));
      expect(state.tick, 1234);
      expect(state.phase, DuelPhase.playing);
      expect(state.ballX, 0.0);
      expect(state.ballY, -0.4);
      expect(state.ballVY, -0.0025);
      expect(state.paddle1X, 1.0);
      expect(state.paddle2X, -0.2);
      expect(state.scoreOf(PlayerSlot.player1), 2);
      expect(state.scoreOf(PlayerSlot.player2), 1);
      expect(state.paddleOf(PlayerSlot.player2), -0.2);
      expect(state.winner, isNull);
    });

    test('gagnant déduit du score', () {
      final json = validStateJson();
      json['score'] = {'p1': 2, 'p2': 5};
      json['phase'] = 'finished';
      expect(GameState.fromJson(json).winner, PlayerSlot.player2);
    });

    test('chaque champ manquant est rejeté', () {
      for (final key in ['tick', 'phase', 'ball', 'paddles', 'score']) {
        final json = validStateJson()..remove(key);
        expect(() => GameState.fromJson(json), throwsFormatException, reason: key);
      }
      for (final entry in {
        'ball': ['x', 'y', 'vx', 'vy'],
        'paddles': ['p1', 'p2'],
        'score': ['p1', 'p2'],
      }.entries) {
        for (final key in entry.value) {
          final json = validStateJson();
          (json[entry.key] as Map).remove(key);
          expect(() => GameState.fromJson(json), throwsFormatException, reason: '${entry.key}.$key');
        }
      }
    });

    test('valeurs hors bornes ou de mauvais type rejetées', () {
      final mutations = <String, void Function(Map<String, dynamic>)>{
        'balle hors du terrain': (j) => (j['ball'] as Map)['x'] = 1.5,
        'balle sous le terrain': (j) => (j['ball'] as Map)['y'] = -1.01,
        'vitesse absurde': (j) => (j['ball'] as Map)['vx'] = 0.5,
        'vitesse non finie': (j) => (j['ball'] as Map)['vy'] = double.nan,
        'position infinie': (j) => (j['paddles'] as Map)['p1'] = double.infinity,
        'raquette hors du terrain': (j) => (j['paddles'] as Map)['p2'] = -2,
        'position en texte': (j) => (j['ball'] as Map)['x'] = '0.5',
        'score négatif': (j) => (j['score'] as Map)['p1'] = -1,
        'score au-delà de 5': (j) => (j['score'] as Map)['p2'] = 6,
        'score décimal': (j) => (j['score'] as Map)['p2'] = 1.5,
        'deux gagnants': (j) => j['score'] = {'p1': 5, 'p2': 5},
        'pas négatif': (j) => j['tick'] = -1,
        'pas décimal': (j) => j['tick'] = 12.5,
        'phase inconnue': (j) => j['phase'] = 'paused',
        'phase en nombre': (j) => j['phase'] = 3,
        'balle pas un objet': (j) => j['ball'] = [0.1, 0.2],
        'score pas un objet': (j) => j['score'] = '2-1',
      };
      for (final entry in mutations.entries) {
        final json = validStateJson();
        entry.value(json);
        expect(() => GameState.fromJson(json), throwsFormatException, reason: entry.key);
      }
    });

    test('ce qui n\'est pas un objet est rejeté', () {
      for (final json in <Object?>[null, 42, 'état', <int>[], true]) {
        expect(() => GameState.fromJson(json), throwsFormatException, reason: '$json');
      }
    });

    test('n\'importe quel JSON reçu donne un état ou une FormatException, jamais autre chose', () {
      final samples = <Object?>[
        jsonDecode('{}'),
        jsonDecode('{"ball": null, "paddles": {}, "score": {}}'),
        jsonDecode('{"tick": 1, "phase": "playing", "ball": {"x": {}, "y": [], "vx": null, "vy": false}}'),
        jsonDecode('[{"tick": 1}]'),
        jsonDecode('"game_state"'),
        jsonDecode('{"tick": 1e400}'),
      ];
      for (final json in samples) {
        expect(() => GameState.fromJson(json), throwsFormatException, reason: '$json');
      }
    });
  });

  group('Machine à états des phases', () {
    // Table attendue, écrite indépendamment du code
    const expected = <DuelPhase, Set<DuelPhase>>{
      DuelPhase.waiting: {DuelPhase.playerJoined},
      DuelPhase.playerJoined: {DuelPhase.waiting, DuelPhase.ready, DuelPhase.disconnected},
      DuelPhase.ready: {DuelPhase.waiting, DuelPhase.playerJoined, DuelPhase.countdown, DuelPhase.disconnected},
      DuelPhase.countdown: {DuelPhase.playing, DuelPhase.disconnected},
      DuelPhase.playing: {DuelPhase.finished, DuelPhase.disconnected},
      DuelPhase.finished: {DuelPhase.playerJoined, DuelPhase.disconnected},
      DuelPhase.disconnected: {DuelPhase.waiting},
    };

    test('toutes les transitions, autorisées et interdites', () {
      for (final from in DuelPhase.values) {
        for (final to in DuelPhase.values) {
          expect(from.canTransitionTo(to), expected[from]!.contains(to), reason: '${from.name} → ${to.name}');
        }
      }
    });

    test('pas de pause : aucune phase ne quitte playing sauf la fin ou la déconnexion', () {
      expect(DuelPhase.values.where(DuelPhase.playing.canTransitionTo).toSet(),
          {DuelPhase.finished, DuelPhase.disconnected});
    });
  });

  group('GameRoom', () {
    test('salon neuf : en attente, Host seul et pas prêt', () {
      final room = GameRoom(id: 'salon', host: hans.copyWith(ready: true));
      expect(room.phase, DuelPhase.waiting);
      expect(room.guest, isNull);
      expect(room.playerCount, 1);
      expect(room.host.ready, isFalse);
      expect(room.playerIn(PlayerSlot.player1), room.host);
      expect(room.playerIn(PlayerSlot.player2), isNull);
    });

    test('parcours complet : rejoindre, prêts, compte à rebours, jeu, fin, rejouer', () {
      final room = GameRoom(id: 'salon', host: hans);

      room.join(awa);
      expect(room.phase, DuelPhase.playerJoined);
      expect(room.playerCount, 2);
      expect(room.slotOf(awa.id), PlayerSlot.player2);
      expect(room.slotOf(hans.id), PlayerSlot.player1);
      expect(room.slotOf('inconnu'), isNull);

      room.setReady(hans.id, true);
      expect(room.phase, DuelPhase.playerJoined);
      room.setReady(awa.id, true);
      expect(room.phase, DuelPhase.ready);

      room.startCountdown();
      expect(room.phase, DuelPhase.countdown);
      room.startPlaying();
      expect(room.phase, DuelPhase.playing);
      room.finish();
      expect(room.phase, DuelPhase.finished);

      room.rematch();
      expect(room.phase, DuelPhase.playerJoined);
      expect(room.host.ready, isFalse);
      expect(room.guest!.ready, isFalse);
      expect(room.guest!.id, awa.id);
    });

    test('un joueur retire son « Prêt » : retour à playerJoined', () {
      final room = readyRoom();
      room.setReady(awa.id, false);
      expect(room.phase, DuelPhase.playerJoined);
      expect(room.host.ready, isTrue);
    });

    test('le joueur 2 arrive pas prêt, même s\'il l\'annonce', () {
      final room = GameRoom(id: 'salon', host: hans)..join(awa.copyWith(ready: true));
      expect(room.guest!.ready, isFalse);
      expect(room.phase, DuelPhase.playerJoined);
    });

    test('transitions interdites : StateError et salon inchangé', () {
      final cases = <String, (GameRoom Function(), void Function(GameRoom))>{
        'compte à rebours sans joueur 2': (() => GameRoom(id: 's', host: hans), (r) => r.startCountdown()),
        'compte à rebours sans les deux prêts': (joinedRoom, (r) => r.startCountdown()),
        'jouer sans compte à rebours': (readyRoom, (r) => r.startPlaying()),
        'finir sans jouer': (() => readyRoom()..startCountdown(), (r) => r.finish()),
        'rejouer pendant la partie': (playingRoom, (r) => r.rematch()),
        'prêt pendant la partie': (playingRoom, (r) => r.setReady(awa.id, false)),
        'prêt sans joueur 2': (() => GameRoom(id: 's', host: hans), (r) => r.setReady(hans.id, true)),
        'prêt d\'un inconnu': (joinedRoom, (r) => r.setReady('inconnu', true)),
        'deuxième joueur 2': (joinedRoom, (r) => r.join(const Player(id: 'x', name: 'X'))),
        'joueur 2 avec l\'identifiant du Host': (
          () => GameRoom(id: 's', host: hans),
          (r) => r.join(const Player(id: 'host-1', name: 'Copie'))
        ),
        'déconnexion sans joueur 2': (() => GameRoom(id: 's', host: hans), (r) => r.disconnect()),
        'départ sans joueur 2': (() => GameRoom(id: 's', host: hans), (r) => r.guestLeft()),
        'rouvrir un salon actif': (joinedRoom, (r) => r.reopen()),
      };
      for (final entry in cases.entries) {
        final room = entry.value.$1();
        final before = jsonEncode(room.toJson());
        expect(() => entry.value.$2(room), throwsStateError, reason: entry.key);
        expect(jsonEncode(room.toJson()), before, reason: '${entry.key} : salon modifié');
      }
    });

    test('le joueur 2 quitte le salon : le Host attend un autre joueur', () {
      for (final room in [joinedRoom(), readyRoom()]) {
        room.guestLeft();
        expect(room.phase, DuelPhase.waiting);
        expect(room.guest, isNull);
        expect(room.host.ready, isFalse);
        // Un autre joueur peut rejoindre
        room.join(const Player(id: 'c3', name: 'Koffi'));
        expect(room.phase, DuelPhase.playerJoined);
      }
    });

    test('le joueur 2 quitte pendant la partie : déconnexion, puis salon rouvert', () {
      for (final room in [readyRoom()..startCountdown(), playingRoom(), playingRoom()..finish()]) {
        room.guestLeft();
        expect(room.phase, DuelPhase.disconnected);
        expect(room.guest, isNull);
        room.reopen();
        expect(room.phase, DuelPhase.waiting);
      }
    });

    test('côté Client : le Host part pendant la partie', () {
      final room = playingRoom()..disconnect();
      expect(room.phase, DuelPhase.disconnected);
    });

    test('aller-retour JSON dans chaque phase', () {
      final rooms = [
        GameRoom(id: 'salon', host: hans),
        joinedRoom()..setReady(awa.id, true),
        readyRoom(),
        readyRoom()..startCountdown(),
        playingRoom(),
        playingRoom()..finish(),
        playingRoom()..guestLeft(),
      ];
      for (final room in rooms) {
        final copy = GameRoom.fromJson(throughJson(room.toJson()));
        expect(copy.id, room.id, reason: room.phase.name);
        expect(copy.phase, room.phase, reason: room.phase.name);
        expect(copy.host, room.host, reason: room.phase.name);
        expect(copy.guest, room.guest, reason: room.phase.name);
      }
    });

    test('le salon reçu suit la même machine à états', () {
      final copy = GameRoom.fromJson(throughJson(readyRoom().toJson()));
      expect(() => copy.startPlaying(), throwsStateError);
      copy.startCountdown();
      expect(copy.phase, DuelPhase.countdown);
    });

    test('salon invalide ou incohérent : FormatException', () {
      Map<String, dynamic> valid() => joinedRoom().toJson();
      final mutations = <String, void Function(Map<String, dynamic>)>{
        'identifiant manquant': (j) => j.remove('id'),
        'identifiant vide': (j) => j['id'] = '',
        'phase inconnue': (j) => j['phase'] = 'paused',
        'Host manquant': (j) => j.remove('host'),
        'Host malformé': (j) => j['host'] = {'id': 'a'},
        'joueur 2 malformé': (j) => j['guest'] = 'Awa',
        'partie sans joueur 2': (j) => j
          ..['phase'] = 'playing'
          ..['guest'] = null,
        'attente avec un joueur 2': (j) => j['phase'] = 'waiting',
        'phase ready sans les deux prêts': (j) => j['phase'] = 'ready',
        'deux joueurs avec le même identifiant': (j) => (j['guest'] as Map)['id'] = hans.id,
      };
      for (final entry in mutations.entries) {
        final json = throughJson(valid()) as Map<String, dynamic>;
        entry.value(json);
        expect(() => GameRoom.fromJson(json), throwsFormatException, reason: entry.key);
      }
      expect(() => GameRoom.fromJson(null), throwsFormatException);
      expect(() => GameRoom.fromJson([1]), throwsFormatException);
    });
  });
}
