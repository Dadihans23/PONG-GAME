/// Couche réseau du duel local. Point d'entrée unique pour les écrans :
/// `import 'package:pong_game/net/net.dart';`
///
/// Elle ne connaît aucune règle du jeu ; le moteur ne la connaît pas.
/// Voir `lib/net/PROTOCOL.md` pour le format des messages.
library;

export 'client_session.dart';
export 'discovery.dart';
export 'host_session.dart';
export 'memory_transport.dart';
export 'multicast_lock.dart';
export 'net_constants.dart';
export 'net_log.dart';
export 'peer_link.dart' show DisconnectReason, HeartbeatConfig;
export 'protocol.dart';
export 'rate_limiter.dart';
export 'session_events.dart';
export 'transport.dart';
export 'websocket_transport.dart';
