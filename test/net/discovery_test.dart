// Découverte UDP en boucle locale (127.0.0.1) : les annonces et les sondes
// sont envoyées en unicast vers 127.0.0.1 au lieu du broadcast, avec des
// ports choisis par le système pour ne pas dépendre du port 47801.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/net/net.dart';

Future<List<InternetAddress>> loopback() async => [InternetAddress.loopbackIPv4];
Future<List<InternetAddress>> nowhere() async => const [];

Future<List<DiscoveredGame>> waitForList(
  DiscoveryBrowser browser,
  bool Function(List<DiscoveredGame>) test,
) async {
  if (test(browser.current)) return browser.current;
  return browser.games.firstWhere(test).timeout(const Duration(seconds: 10));
}

void main() {
  final toStop = <Future<void> Function()>[];

  tearDown(() async {
    for (final stop in toStop.reversed) {
      await stop();
    }
    toStop.clear();
  });

  Future<DiscoveryBrowser> startBrowser({int probePort = 1, BroadcastTargets targets = nowhere}) async {
    final browser = DiscoveryBrowser(
      listenPort: 0,
      probePort: probePort,
      probeInterval: const Duration(milliseconds: 100),
      expiry: const Duration(milliseconds: 400),
      targets: targets,
      multicastLock: const NoMulticastLock(),
      log: silentNetLogger,
    );
    await browser.start();
    toStop.add(browser.stop);
    return browser;
  }

  Future<DiscoveryAnnouncer> startAnnouncer({
    required int targetPort,
    BroadcastTargets targets = loopback,
    String name = 'Partie de Awa',
  }) async {
    final announcer = DiscoveryAnnouncer(
      gameName: name,
      gamePort: 47800,
      listenPort: 0,
      targetPort: targetPort,
      interval: const Duration(milliseconds: 100),
      targets: targets,
      multicastLock: const NoMulticastLock(),
      log: silentNetLogger,
    );
    await announcer.start();
    toStop.add(announcer.stop);
    return announcer;
  }

  test('les annonces du Host apparaissent dans la liste du Client', () async {
    final browser = await startBrowser();
    await startAnnouncer(targetPort: browser.port);

    final games = await waitForList(browser, (l) => l.isNotEmpty);
    final game = games.single;
    expect(game.name, 'Partie de Awa');
    expect(game.address, '127.0.0.1');
    expect(game.port, 47800);
    expect(game.players, 1);
    expect(game.maxPlayers, 2);
    expect(game.isFull, isFalse);
    expect(game.isCompatible, isTrue);
  });

  test('sonde du Client : le Host répond en direct, sans broadcast', () async {
    // L'annonceur n'a aucune cible de broadcast : seule la réponse à la
    // sonde peut faire apparaître la partie.
    final announcer = await startAnnouncer(targetPort: 1, targets: nowhere);
    final browser = await startBrowser(probePort: announcer.port, targets: loopback);
    final games = await waitForList(browser, (l) => l.isNotEmpty);
    expect(games.single.name, 'Partie de Awa');
  });

  test('le nombre de joueurs se met à jour, la partie pleine est signalée', () async {
    final browser = await startBrowser();
    final announcer = await startAnnouncer(targetPort: browser.port);
    await waitForList(browser, (l) => l.isNotEmpty);
    announcer.update(players: 2);
    final games = await waitForList(browser, (l) => l.isNotEmpty && l.single.players == 2);
    expect(games.single.isFull, isTrue);
  });

  test('une partie qui n\'est plus annoncée disparaît', () async {
    final browser = await startBrowser();
    final announcer = await startAnnouncer(targetPort: browser.port);
    await waitForList(browser, (l) => l.isNotEmpty);
    final watch = Stopwatch()..start();
    await announcer.stop();
    await waitForList(browser, (l) => l.isEmpty);
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(300));
  });

  test('deux parties sont listées séparément, triées par nom', () async {
    final browser = await startBrowser();
    await startAnnouncer(targetPort: browser.port, name: 'Partie de Zoé');
    await startAnnouncer(targetPort: browser.port, name: 'Partie de Awa');
    final games = await waitForList(browser, (l) => l.length == 2);
    expect(games.map((g) => g.name), ['Partie de Awa', 'Partie de Zoé']);
  });

  test('Actualiser vide la liste puis la reconstruit', () async {
    final browser = await startBrowser();
    await startAnnouncer(targetPort: browser.port);
    await waitForList(browser, (l) => l.isNotEmpty);
    browser.refresh();
    expect(browser.current, isEmpty);
    await waitForList(browser, (l) => l.isNotEmpty);
  });

  test('paquets invalides ou étrangers : ignorés', () async {
    final browser = await startBrowser();
    final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    void sendJson(Object json) =>
        sender.send(utf8.encode(json is String ? json : jsonEncode(json)), InternetAddress.loopbackIPv4, browser.port);
    final valid = {'app': 'pong_game', 'type': 'announce', 'v': 1, 'id': 'abc', 'name': 'X', 'port': 1, 'players': 1, 'max': 2};
    sendJson('pas du json');
    sendJson([1, 2, 3]);
    sendJson({...valid, 'app': 'autre_jeu'});
    sendJson({...valid, 'port': 70000});
    sendJson({...valid, 'players': 3});
    sendJson({...valid, 'name': ''});
    sendJson({...valid, 'name': 'x' * 41});
    sendJson({...valid, 'id': 5});
    sendJson({...valid, 'type': 'probe'});
    sendJson(utf8.decode(List.filled(1500, 0x61)));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(browser.current, isEmpty);
    sendJson(valid);
    final games = await waitForList(browser, (l) => l.isNotEmpty);
    expect(games.single.name, 'X');
    sender.close();
  });

  test('autre version du protocole : listée mais signalée incompatible', () async {
    final browser = await startBrowser();
    final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    sender.send(
      utf8.encode(jsonEncode({'app': 'pong_game', 'type': 'announce', 'v': 2, 'id': 'f', 'name': 'Futur', 'port': 1, 'players': 1, 'max': 2})),
      InternetAddress.loopbackIPv4,
      browser.port,
    );
    final games = await waitForList(browser, (l) => l.isNotEmpty);
    expect(games.single.isCompatible, isFalse);
    sender.close();
  });

  test('stop() est idempotent et ferme le flux', () async {
    final browser = await startBrowser();
    final done = browser.games.toList();
    await browser.stop();
    await browser.stop();
    await done.timeout(const Duration(seconds: 1));
  });

  test('cibles de broadcast par défaut : 255.255.255.255 et les /24 locaux', () async {
    final targets = await defaultBroadcastTargets();
    final addresses = targets.map((a) => a.address).toList();
    expect(addresses, contains('255.255.255.255'));
    expect(addresses.every((a) => a.endsWith('.255')), isTrue);
    expect(addresses, isNot(contains('127.0.0.255')));
  });
}
