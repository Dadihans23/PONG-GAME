// Bout en bout sur de vraies sockets en boucle locale (127.0.0.1) :
// HttpServer + WebSocketTransformer côté Host, WebSocket.connect côté Client.
//
// Ces tests n'initialisent pas le binding Flutter (pas de testWidgets) : le
// binding de test remplace HttpClient par un faux qui répond 400.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/net/net.dart';

Future<T> nextEvent<T extends SessionEvent>(Stream<SessionEvent> events) =>
    events.where((e) => e is T).cast<T>().first.timeout(const Duration(seconds: 10));

void main() {
  late HostSession host;

  setUp(() async {
    host = HostSession(hostName: 'Awa', requestedPort: 0, log: silentNetLogger);
    await host.start();
  });

  tearDown(() => host.close());

  ClientSession newClient(String name) => ClientSession(playerName: name, log: silentNetLogger);

  test('join, ready, paddle et game_state à 30 Hz pendant 1 s, puis départ du Client détecté', () async {
    final hostEvents = <SessionEvent>[];
    host.events.listen(hostEvents.add);
    final client = newClient('Hans');
    final clientEvents = <SessionEvent>[];
    client.events.listen(clientEvents.add);

    final result = await client.connect('127.0.0.1', host.port);
    expect(result, isA<JoinAccepted>());
    expect((result as JoinAccepted).hostName, 'Awa');
    expect(hostEvents.whereType<PeerConnected>().single.name, 'Hans');
    expect(host.clientName, 'Hans');

    client.sendReady(true);
    host.sendReady(true);
    host.sendStart(0);

    // Une seconde de jeu : chaque côté envoie 30 messages à 30 Hz. On attend
    // ensuite l'arrivée de tous les messages plutôt qu'une fenêtre de temps
    // fixe : le test reste fiable sur une machine chargée.
    const sends = netSendRateHz;
    List<PaddleMessage> paddles() => [
          for (final e in hostEvents.whereType<MessageReceived>())
            if (e.message is PaddleMessage) e.message as PaddleMessage,
        ];
    List<GameStateMessage> states() => [
          for (final e in clientEvents.whereType<MessageReceived>())
            if (e.message is GameStateMessage) e.message as GameStateMessage,
        ];
    var tick = 0;
    final allSent = Completer<void>();
    final watch = Stopwatch()..start();
    final timer = Timer.periodic(netSendInterval, (t) {
      tick++;
      final x = (tick % 20) / 10 - 1; // -1 → 0.9
      host.sendGameState({
        'tick': tick,
        'ball': {'x': x / 2, 'y': -x / 2},
        'paddles': {'host': x, 'client': host.clientPaddleX ?? 0},
        'score': {'host': 0, 'client': 0},
      });
      client.sendPaddle(-x);
      if (tick == sends) {
        t.cancel();
        allSent.complete();
      }
    });
    await allSent.future.timeout(const Duration(seconds: 20), onTimeout: timer.cancel);
    final sendDuration = watch.elapsed;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while ((paddles().length < sends || states().length < sends) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    host.sendGameOver(PlayerSide.client, state: {'score': {'host': 3, 'client': 5}});
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Les 30 envois prennent environ une seconde (bornes larges : la
    // résolution des minuteurs varie selon la machine et sa charge).
    expect(sendDuration, greaterThanOrEqualTo(const Duration(milliseconds: 900)));
    expect(paddles(), hasLength(sends), reason: 'aucune raquette perdue');
    expect(states(), hasLength(sends), reason: 'aucun état perdu');
    final received = states();
    for (var i = 1; i < received.length; i++) {
      expect(received[i].seq, greaterThan(received[i - 1].seq));
    }
    expect(received.last.state['tick'], sends);
    expect(paddles().last.x, closeTo(-((sends % 20) / 10 - 1), 1e-9));
    expect(hostEvents.whereType<MessageReceived>().first.message, isA<ReadyMessage>());
    expect(
      clientEvents.whereType<MessageReceived>().map((e) => e.message.type).toSet(),
      containsAll(['ready', 'start', 'game_state', 'game_over']),
    );
    expect(client.lastState!.state['tick'], sends);
    expect(host.roundTripTime, isNotNull);

    // Départ du Client : le Host le voit et repasse à 1 joueur.
    final left = nextEvent<PeerDisconnected>(host.events);
    await client.close();
    expect((await left).reason, DisconnectReason.left);
    expect(host.hasClient, isFalse);
  });

  test('le Host ferme : le Client est prévenu', () async {
    final client = newClient('Hans');
    expect(await client.connect('127.0.0.1', host.port), isA<JoinAccepted>());
    final lost = nextEvent<PeerDisconnected>(client.events);
    await host.close();
    expect((await lost).reason, DisconnectReason.left);
  });

  test('un 3e joueur est refusé, le 2e garde sa place', () async {
    final second = newClient('Hans');
    expect(await second.connect('127.0.0.1', host.port), isA<JoinAccepted>());
    final third = newClient('Zoé');
    final result = await third.connect('127.0.0.1', host.port);
    expect(result, isA<JoinRejected>());
    expect((result as JoinRejected).reason, RejectReason.full);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(second.isConnected, isTrue);
    expect(host.clientName, 'Hans');
    await second.close();
  });

  test('après le départ du Client, un autre peut rejoindre (retour au salon)', () async {
    final first = newClient('Hans');
    await first.connect('127.0.0.1', host.port);
    final left = nextEvent<PeerDisconnected>(host.events);
    await first.close();
    await left;
    final next = newClient('Zoé');
    expect(await next.connect('127.0.0.1', host.port), isA<JoinAccepted>());
    expect(host.clientName, 'Zoé');
    await next.close();
  });

  test('aucun Host sur ce port : JoinFailed rapide, sans exception', () async {
    final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = free.port;
    await free.close();
    final result = await newClient('Hans').connect('127.0.0.1', port);
    expect(result, isA<JoinFailed>());
  });

  test('requête HTTP ordinaire : 404, le serveur continue', () async {
    final http = HttpClient();
    final request = await http.get('127.0.0.1', host.port, '/');
    final response = await request.close();
    await response.drain<void>();
    expect(response.statusCode, HttpStatus.notFound);
    http.close();
    expect(await newClient('Hans').connect('127.0.0.1', host.port), isA<JoinAccepted>());
  });

  test('port demandé occupé : repli sur un port libre', () async {
    final busy = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final other = HostSession(hostName: 'Bis', requestedPort: busy.port, log: silentNetLogger);
    final port = await other.start();
    expect(port, isNot(busy.port));
    expect(await newClient('Hans').connect('127.0.0.1', port), isA<JoinAccepted>());
    await other.close();
    await busy.close(force: true);
  });
}
