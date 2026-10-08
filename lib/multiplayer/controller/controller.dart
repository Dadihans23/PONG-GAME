/// Contrôleur du duel en réseau local. Point d'entrée unique pour les
/// écrans du multijoueur :
/// `import 'package:pong_game/multiplayer/controller/controller.dart';`
library;

export '../../net/game_discovery.dart' show DiscoveredGame;
export '../duel_view.dart';
export '../model/duel_phase.dart';
export '../model/game_room.dart';
export '../model/player.dart';
export 'duel_stats.dart';
export 'multiplayer_controller.dart';
export 'multiplayer_events.dart';
export 'multiplayer_network.dart';
export 'multiplayer_types.dart';
