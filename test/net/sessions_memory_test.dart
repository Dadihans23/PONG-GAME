import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/net/net.dart';

/// Battement de cœur accéléré pour les tests : coupure détectée en 600 ms.
/// Le délai reste large devant une pause de la boucle d'événements sur une
/// machine chargée (suite complète en parallèle), pour éviter les faux
/// « connexion perdue ».
const fastHeartbeat = HeartbeatConfig(
  pingInterval: Duration(milliseconds: 50),
  timeout: Duration(milliseconds: 600),
  checkInterval: Duration(milliseconds: 20),
);

/// Attend le premier événement qui vérifie [test].
Future<T> nextEvent<T extends SessionEvent>(Stream<SessionEvent> events, [bool Function(T)? test]) {
  return events
      .where((e) => e is T && (test == null || test(e)))
      .cast<T>()
      .first
      .timeout(const Duration(seconds: 10));
}

Future<void> settle([int ms = 30]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late MemoryTransport network;
  late HostSession host;
  late List<SessionEvent> hostEvents;
  final logs = <String>[];

  ClientSession newClient(String name) => ClientSession(
        playerName: name,
        transport: network,
        heartbeat: fastHeartbeat,
        welcomeTimeout: const Duration(seconds: 1),
        log: logs.add,
      );

  setUp(() async {
    logs.clear();
    network = MemoryTransport();
    host = HostSession(
      hostName: 'Awa',
      transport: network,
      requestedPort: 0,
      heartbeat: fastHeartbeat,
      joinTimeout: const Duration(milliseconds: 300), // < délai du battement de cœur
      log: logs.add,
    );
    hostEvents = [];
    host.events.listen(hostEvents.add);
    await host.start();
  });

  tearDown(() => host.close());

  test('un Client rejoint : welcome, PeerConnected des deux côtés', () async {
    final client = newClient('Hans');
    final clientConnected = nextEvent<PeerConnected>(client.events);
    final hostConnected = nextEvent<PeerConnected>(host.events);
    final result = await client.connect('local', host.port);

    expect(result, isA<JoinAccepted>());
    expect((result as JoinAccepted).hostName, 'Awa');
    expect((await clientConnected).name, 'Awa');
    expect((await hostConnected).name, 'Hans');
    expect(host.hasClient, isTrue);
    expect(host.clientName, 'Hans');
    expect(host.playerCount, 2);
    expect(client.isConnected, isTrue);
    await client.close();
  });

  test('échanges : ready, start, paddle, game_state, game_over, rematch', () async {
    final client = newClient('Hans');
    final clientEvents = <SessionEvent>[];
    client.events.listen(clientEvents.add);
    await client.connect('local', host.port);

    expect(client.sendReady(true), isTrue);
    expect(client.sendPaddle(0.4), isTrue);
    expect(client.sendPaddle(2.0), isTrue, reason: 'bornée à 1 avant envoi');
    expect(client.sendPaddle(double.nan), isFalse);
    expect(client.sendRematch(), isTrue);
    expect(host.sendReady(true), isTrue);
    expect(host.sendStart(3), isTrue);
    expect(host.sendGameState({'ball': {'x': 0.5}}), isTrue);
    expect(host.sendGameState({'ball': {'x': 0.6}}), isTrue);
    expect(host.sendGameOver(PlayerSide.host, state: {'score': [5, 2]}), isTrue);
    expect(host.sendRematch(), isTrue);
    await settle();

    final hostMessages = [for (final e in hostEvents.whereType<MessageReceived>()) e.message];
    expect(hostMessages.map((m) => m.type), ['ready', 'paddle', 'paddle', 'rematch']);
    expect(host.clientPaddleX, 1.0);

    final clientMessages = [for (final e in clientEvents.whereType<MessageReceived>()) e.message];
    expect(clientMessages.map((m) => m.type), ['ready', 'start', 'game_state', 'game_state', 'game_over', 'rematch']);
    expect(client.lastState!.state, {'ball': {'x': 0.6}});
    expect(client.lastState!.seq, 1);
    expect((clientMessages[4] as GameOverMessage).winner, PlayerSide.host);
    await client.close();
  });

  test('un 3e joueur est refusé (partie pleine), le 2e reste connecté', () async {
    final second = newClient('Hans');
    await second.connect('local', host.port);
    final third = newClient('Zoé');
    final result = await third.connect('local', host.port);

    expect(result, isA<JoinRejected>());
    expect((result as JoinRejected).reason, RejectReason.full);
    expect(third.isConnected, isFalse);
    await settle();
    expect(host.clientName, 'Hans');
    expect(second.isConnected, isTrue);
    expect(hostEvents.whereType<PeerConnected>(), hasLength(1));
    await second.close();
  });

  test('version incompatible : refus « version »', () async {
    final connection = await network.connect('local', host.port, timeout: const Duration(seconds: 1));
    final frames = <String>[];
    connection.frames.listen(frames.add);
    connection.send(const JoinMessage(name: 'Vieux', version: 99).encode());
    await connection.done.timeout(const Duration(seconds: 10));
    final reject = NetMessage.decode(frames.first) as RejectMessage;
    expect(reject.reason, RejectReason.version);
    expect(host.hasClient, isFalse);
  });

  test('pas de join dans le délai : refus « bad_request » et fermeture', () async {
    // Host dédié au battement de cœur très long : seul le délai de join doit
    // pouvoir fermer la connexion, même si la machine de test se fige.
    final strict = HostSession(
      hostName: 'Awa',
      transport: network,
      requestedPort: 0,
      heartbeat: const HeartbeatConfig(timeout: Duration(seconds: 30)),
      joinTimeout: const Duration(milliseconds: 200),
      log: logs.add,
    );
    final strictEvents = <SessionEvent>[];
    strict.events.listen(strictEvents.add);
    await strict.start();
    final connection = await network.connect('local', strict.port, timeout: const Duration(seconds: 1));
    final frames = <String>[];
    connection.frames.listen(frames.add);
    connection.send(const ReadyMessage(ready: true).encode()); // avant join : ignoré
    await connection.done.timeout(const Duration(seconds: 10));
    expect(frames.map(NetMessage.decode).whereType<RejectMessage>().single.reason, RejectReason.badRequest);
    expect(strictEvents, isEmpty);
    await strict.close();
  });

  test('messages invalides ou réservés au Host : ignorés, rien ne plante', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    final hostEnd = network.clientEnds.last;
    for (final frame in [
      'pas du json',
      '{"v":1,"type":"teleport"}',
      '{"v":1,"type":"paddle","seq":99,"x":7}',
      '{"v":1,"type":"game_state","seq":1,"state":{}}',
      '{"v":1,"type":"start","countdown":3}',
      '[]',
    ]) {
      hostEnd.send(frame);
    }
    await settle();
    expect(hostEvents.whereType<MessageReceived>(), isEmpty);
    expect(host.hasClient, isTrue);
    expect(logs.where((l) => l.contains('ignoré')), hasLength(6));
    // La liaison fonctionne toujours.
    client.sendPaddle(-0.2);
    await settle();
    expect(host.clientPaddleX, -0.2);
    await client.close();
  });

  test('raquettes reçues dans le désordre : seule la plus récente compte', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    final end = network.clientEnds.last;
    end.send(const PaddleMessage(seq: 5, x: 0.5).encode());
    end.send(const PaddleMessage(seq: 3, x: -0.9).encode());
    await settle();
    expect(host.clientPaddleX, 0.5);
    await client.close();
  });

  test('le Client part : le Host est prévenu (left) et accepte un autre joueur', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    final left = nextEvent<PeerDisconnected>(host.events);
    await client.close();
    expect((await left).reason, DisconnectReason.left);
    expect(host.hasClient, isFalse);
    expect(host.playerCount, 1);

    final next = newClient('Zoé');
    expect(await next.connect('local', host.port), isA<JoinAccepted>());
    expect(host.clientName, 'Zoé');
    await next.close();
  });

  test('le Client se ferme sans leave : le Host voit closed', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    final gone = nextEvent<PeerDisconnected>(host.events);
    await network.clientEnds.last.close(); // socket fermé brutalement
    expect((await gone).reason, DisconnectReason.closed);
  });

  test('le Host ferme la partie : le Client voit left', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    final lost = nextEvent<PeerDisconnected>(client.events);
    await host.close();
    expect((await lost).reason, DisconnectReason.left);
    expect(client.isConnected, isFalse);
  });

  test('coupure silencieuse (Wi-Fi perdu) : les deux côtés la détectent par le battement de cœur', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    final hostLost = nextEvent<PeerDisconnected>(host.events);
    final clientLost = nextEvent<PeerDisconnected>(client.events);
    final watch = Stopwatch()..start();
    network.clientEnds.last.cutSilently();

    expect((await hostLost).reason, DisconnectReason.timeout);
    expect((await clientLost).reason, DisconnectReason.timeout);
    // Le dernier message a pu arriver jusqu'à un intervalle de ping avant la
    // coupure : la détection prend au moins timeout - pingInterval.
    final minimum = fastHeartbeat.timeout - fastHeartbeat.pingInterval;
    expect(watch.elapsed, greaterThanOrEqualTo(minimum - const Duration(milliseconds: 20)));
    // Borne haute large : on vérifie que la coupure est détectée, sans
    // dépendre de la charge de la machine.
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(host.hasClient, isFalse);
  });

  test('connexion inactive maintenue par ping/pong au-delà du délai', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    await settle(fastHeartbeat.timeout.inMilliseconds * 4);
    expect(client.isConnected, isTrue);
    expect(host.hasClient, isTrue);
    expect(hostEvents.whereType<PeerDisconnected>(), isEmpty);
    expect(client.roundTripTime, isNotNull);
    expect(host.roundTripTime, isNotNull);
    await client.close();
  });

  test('aucun Host : JoinFailed, sans exception', () async {
    final client = newClient('Hans');
    final result = await client.connect('local', 1);
    expect(result, isA<JoinFailed>());
  });

  test('Host muet : JoinFailed après le délai de welcome', () async {
    final silent = await network.listen(port: 0);
    silent.connections.listen((_) {}); // accepte, ne répond jamais
    final client = newClient('Hans');
    final result = await client.connect('local', silent.port);
    expect(result, isA<JoinFailed>());
    await silent.close();
  });

  test('une session Client ne sert qu\'une fois', () async {
    final client = newClient('Hans');
    await client.connect('local', host.port);
    await client.close();
    expect(() => client.connect('local', host.port), throwsStateError);
  });

  test('fermer le Client pendant la connexion ne laisse rien ouvert', () async {
    final client = newClient('Hans');
    final pending = client.connect('local', host.port);
    await client.close();
    final result = await pending;
    expect(result, isNot(isA<JoinAccepted>()));
    await settle();
    expect(host.hasClient, isFalse);
  });

  test('close() du Host est idempotent', () async {
    await host.close();
    await host.close();
    expect(host.isRunning, isFalse);
  });
}
