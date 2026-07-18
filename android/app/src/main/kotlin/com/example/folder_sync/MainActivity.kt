package com.example.folder_sync

import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKUP_FOREGROUND_SERVICE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    result.success(startBackupForegroundService())
                }

                "stop" -> {
                    stopBackupForegroundService()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_STATUS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentSsid" -> result.success(currentWifiSsid())
                else -> result.notImplemented()
            }
        }
    }

    private fun startBackupForegroundService(): Boolean {
        return try {
            val intent = Intent(this, BackupForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun stopBackupForegroundService() {
        try {
            val intent = Intent(this, BackupForegroundService::class.java).apply {
                action = BackupForegroundService.ACTION_STOP
            }
            stopService(intent)
        } catch (_: Exception) {
            return
        }
    }

    private fun currentWifiSsid(): String? {
        return try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            val rawSsid = wifiManager.connectionInfo?.ssid ?: return null
            rawSsid
                .trim()
                .removeSurrounding("\"")
                .takeIf { it.isNotBlank() && it != "<unknown ssid>" }
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val BACKUP_FOREGROUND_SERVICE_CHANNEL =
            "openbackup/backup_foreground_service"
        private const val WIFI_STATUS_CHANNEL = "openbackup/wifi_status"
    }
}
