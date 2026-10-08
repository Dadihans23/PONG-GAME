/// Constantes de la couche réseau locale.
library;

/// Port TCP préféré de la WebSocket du Host. S'il est occupé, le Host prend
/// un port libre et l'annonce par la découverte.
const int defaultGamePort = 47800;

/// Port UDP de la découverte (annonces du Host, sondes du Client).
const int discoveryPort = 47801;

/// Cadence d'envoi : `game_state` du Host et `paddle` du Client.
const int netSendRateHz = 30;

/// Intervalle entre deux envois à [netSendRateHz].
const Duration netSendInterval = Duration(microseconds: 1000000 ~/ netSendRateHz);
