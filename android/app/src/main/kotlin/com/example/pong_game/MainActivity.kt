package com.example.pong_game

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Verrou multicast du Wi-Fi pour la découverte des parties (lib/net/multicast_lock.dart).
    // Sans lui, beaucoup de puces Wi-Fi filtrent les broadcasts UDP pour économiser la batterie.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pong_game/multicast_lock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> result.success(acquireMulticastLock())
                    "release" -> {
                        releaseMulticastLock()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireMulticastLock(): Boolean {
        return try {
            val lock = multicastLock ?: run {
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                wifi.createMulticastLock("pong_game_discovery").also { it.setReferenceCounted(false) }
            }
            multicastLock = lock
            if (!lock.isHeld) lock.acquire()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun releaseMulticastLock() {
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
        } catch (e: Exception) {
            // Déjà rendu.
        }
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }
}
