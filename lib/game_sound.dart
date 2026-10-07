import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Un son du jeu, avec son propre lecteur.
///
/// Sur Android, audioplayers 5.2.1 exécute chaque commande (stop, play...) sur
/// un fil d'exécution différent, sans ordre garanti ni verrou, alors que les
/// rappels du MediaPlayer arrivent sur le fil principal. Deux commandes non
/// attendues sur le même lecteur (`stop()` puis `play()`) peuvent donc libérer
/// le MediaPlayer pendant qu'il est préparé ou démarré : l'application se ferme
/// (`IllegalStateException` dans `MediaPlayer.getPlaybackParams`).
///
/// Cette classe évite ces situations :
/// - le son est chargé une seule fois, et son MediaPlayer n'est ni libéré ni
///   réinitialisé avant `dispose()` ;
/// - les commandes sont envoyées une par une, chacune après la fin de la
///   précédente ;
/// - rien n'est joué tant que le chargement n'est pas terminé.
class GameSound {
  /// [asset] est le chemin du son dans `assets/`, par exemple `sounds/hitball.mp3`.
  GameSound(this.asset, {this.loop = false}) {
    _queue = _load();
  }

  final String asset;
  final bool loop; // true : le son tourne en boucle jusqu'à stop()

  final AudioPlayer _player = AudioPlayer();
  late Future<void> _queue; // Se termine quand toutes les commandes envoyées sont finies
  int _lastRequest = 0; // Numéro de la dernière demande (play ou stop)
  bool _loaded = false;
  bool _disposed = false;

  Future<void> _load() async {
    try {
      // ReleaseMode.stop : à la fin du son, le lecteur revient au début sans
      // être libéré, il peut donc rejouer tout de suite
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.setSource(AssetSource(asset));
      _loaded = true;
    } catch (e) {
      debugPrint('Son $asset : chargement impossible : $e');
    }
  }

  /// Joue le son depuis le début, même s'il est déjà en cours.
  Future<void> play() => _send(restart: true);

  /// Arrête le son et le remet au début.
  Future<void> stop() => _send(restart: false);

  Future<void> _send({required bool restart}) {
    final int request = ++_lastRequest;
    return _queue = _queue.then((_) async {
      // Une demande plus récente remplace celle-ci : des appels très
      // rapprochés ne s'accumulent pas
      if (_disposed || !_loaded || request != _lastRequest) return;
      try {
        await _player.stop();
        if (restart && !_disposed && request == _lastRequest) {
          await _player.resume();
        }
      } catch (e) {
        debugPrint('Son $asset : lecture impossible : $e');
      }
    });
  }

  /// Arrête le son et libère le lecteur, après la commande en cours.
  Future<void> dispose() {
    if (_disposed) return _queue;
    _disposed = true;
    return _queue = _queue.then((_) async {
      try {
        await _player.dispose();
      } catch (e) {
        debugPrint('Son $asset : libération impossible : $e');
      }
    });
  }
}
