import 'dart:io';

import 'package:flutter/services.dart';

/// Verrou multicast du Wi-Fi Android.
///
/// Pour économiser la batterie, beaucoup de puces Wi-Fi Android filtrent les
/// paquets qui ne sont pas adressés à l'appareil (multicast, et sur certains
/// modèles le broadcast aussi), surtout écran éteint ou en économie
/// d'énergie. `WifiManager.MulticastLock` lève ce filtre. La découverte le
/// prend pendant qu'elle tourne et le rend à l'arrêt.
///
/// Implémenté par un `MethodChannel` minimal dans `MainActivity.kt`
/// (canal `pong_game/multicast_lock`, méthodes `acquire` et `release`).
abstract class MulticastLock {
  Future<void> acquire();
  Future<void> release();
}

/// Verrou adapté à la plateforme : réel sur Android, sans effet ailleurs.
MulticastLock platformMulticastLock() =>
    Platform.isAndroid ? AndroidMulticastLock() : const NoMulticastLock();

/// Aucun verrou (tests, autres plateformes).
class NoMulticastLock implements MulticastLock {
  const NoMulticastLock();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

/// Verrou Android par `MethodChannel`. Compté : le verrou natif est pris au
/// premier `acquire` et rendu au dernier `release`, même si le Host annonce
/// et qu'un navigateur tourne en même temps.
class AndroidMulticastLock implements MulticastLock {
  static const MethodChannel _channel = MethodChannel('pong_game/multicast_lock');
  static int _holders = 0;

  bool _held = false;

  @override
  Future<void> acquire() async {
    if (_held) return;
    _held = true;
    _holders++;
    if (_holders == 1) await _invoke('acquire');
  }

  @override
  Future<void> release() async {
    if (!_held) return;
    _held = false;
    _holders--;
    if (_holders == 0) await _invoke('release');
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on Object catch (_) {
      // Canal absent ou permission refusée : la découverte fonctionne quand
      // même sur la plupart des appareils (le broadcast passe sans verrou),
      // et les sondes du Client reçoivent une réponse directe.
    }
  }
}
