import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Catégorie d'un son, coupée séparément dans les réglages.
enum SoundCategory {
  /// Musiques d'ambiance, de pause, de chargement.
  music,

  /// Bruitages : renvoi, clic, record, fin de partie…
  effect,
}

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
///
/// Les réglages coupent chaque catégorie avec [musicEnabled] et
/// [effectsEnabled]. Couper une catégorie arrête ses sons en cours ; la
/// réactiver relance les boucles qui jouaient (ou auraient dû jouer).
class GameSound {
  /// [asset] est le chemin du son dans `assets/`, par exemple `sounds/hitball.mp3`.
  ///
  /// Sans [category], un son en boucle est une musique, les autres sont des
  /// effets.
  GameSound(this.asset, {this.loop = false, SoundCategory? category})
      : category =
            category ?? (loop ? SoundCategory.music : SoundCategory.effect) {
    _live.add(this);
    _queue = _load();
  }

  final String asset;
  final bool loop; // true : le son tourne en boucle jusqu'à stop()
  final SoundCategory category;

  // --- Interrupteurs globaux (réglages) ------------------------------------
  static final Set<GameSound> _live = {}; // Sons créés et pas encore libérés
  static bool _musicEnabled = true;
  static bool _effectsEnabled = true;

  /// Musiques autorisées. `false` arrête tout de suite les musiques en cours.
  static bool get musicEnabled => _musicEnabled;
  static set musicEnabled(bool value) {
    if (value == _musicEnabled) return;
    _musicEnabled = value;
    _applyCategory(SoundCategory.music, value);
  }

  /// Effets sonores autorisés. `false` arrête les effets en cours.
  static bool get effectsEnabled => _effectsEnabled;
  static set effectsEnabled(bool value) {
    if (value == _effectsEnabled) return;
    _effectsEnabled = value;
    _applyCategory(SoundCategory.effect, value);
  }

  static bool _isEnabled(SoundCategory category) =>
      category == SoundCategory.music ? _musicEnabled : _effectsEnabled;

  static void _applyCategory(SoundCategory category, bool enabled) {
    for (final sound in _live.toList()) {
      if (sound.category != category) continue;
      if (!enabled) {
        sound._send(restart: false);
      } else if (sound.loop && sound._wanted) {
        sound._send(restart: true);
      }
    }
  }

  final AudioPlayer _player = AudioPlayer();
  late Future<void> _queue; // Se termine quand toutes les commandes envoyées sont finies
  int _lastRequest = 0; // Numéro de la dernière demande (play ou stop)
  bool _loaded = false;
  bool _disposed = false;
  bool _wanted = false; // Boucle demandée par play() et pas encore stoppée

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

  /// Joue le son depuis le début, même s'il est déjà en cours. Ne fait rien
  /// si sa catégorie est coupée (une boucle démarrera quand elle sera
  /// réactivée).
  Future<void> play() {
    if (loop) _wanted = true;
    if (!_isEnabled(category)) return _queue;
    return _send(restart: true);
  }

  /// Arrête le son et le remet au début.
  Future<void> stop() {
    _wanted = false;
    return _send(restart: false);
  }

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
    _wanted = false;
    _live.remove(this);
    return _queue = _queue.then((_) async {
      try {
        await _player.dispose();
      } catch (e) {
        debugPrint('Son $asset : libération impossible : $e');
      }
    });
  }
}
