import '../../net/net.dart';

/// Crée l'annonceur de la partie, une fois le port du Host connu.
typedef AdvertiserFactory = GameAdvertiser Function(
    {required String gameName, required int gamePort});

/// Crée le chercheur de parties.
typedef FinderFactory = GameFinder Function();

/// Ce dont le contrôleur a besoin pour joindre l'autre téléphone : le
/// transport des sessions et la découverte des parties.
///
/// Par défaut : WebSocket (`dart:io`) et broadcast UDP sur le réseau local.
/// Les tests passent [MultiplayerNetwork.memory]. Un futur serveur en ligne
/// fournira son propre transport et sa propre liste de salons, sans toucher
/// au contrôleur ni au jeu.
class MultiplayerNetwork {
  const MultiplayerNetwork({
    this.transport,
    this.advertiserFactory,
    this.finderFactory,
    this.heartbeat = const HeartbeatConfig(),
    this.log = defaultNetLogger,
    this.requestedPort = defaultGamePort,
  });

  /// Réseau en mémoire, pour les tests.
  factory MultiplayerNetwork.memory({
    required MemoryTransport transport,
    required MemoryDiscovery discovery,
    HeartbeatConfig heartbeat = const HeartbeatConfig(),
    NetLogger log = silentNetLogger,
  }) =>
      MultiplayerNetwork(
        transport: transport,
        advertiserFactory: ({required gameName, required gamePort}) =>
            discovery.advertiser(gameName: gameName, gamePort: gamePort),
        finderFactory: discovery.finder,
        heartbeat: heartbeat,
        log: log,
        requestedPort: 0,
      );

  /// `null` : WebSocket du réseau local.
  final NetTransport? transport;
  final AdvertiserFactory? advertiserFactory;
  final FinderFactory? finderFactory;
  final HeartbeatConfig heartbeat;
  final NetLogger log;

  /// Port préféré du Host.
  final int requestedPort;

  GameAdvertiser createAdvertiser(
          {required String gameName, required int gamePort}) =>
      advertiserFactory?.call(gameName: gameName, gamePort: gamePort) ??
      DiscoveryAnnouncer(gameName: gameName, gamePort: gamePort, log: log);

  GameFinder createFinder() =>
      finderFactory?.call() ?? DiscoveryBrowser(log: log);

  HostSession createHostSession(String hostName) => HostSession(
        hostName: hostName,
        transport: transport,
        requestedPort: requestedPort,
        heartbeat: heartbeat,
        log: log,
      );

  ClientSession createClientSession(String playerName) => ClientSession(
        playerName: playerName,
        transport: transport,
        heartbeat: heartbeat,
        log: log,
      );
}
