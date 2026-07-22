package com.example.folder_sync

import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKUP_FOREGROUND_SERVICE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title") ?: "OpenBackup"
                    val message = call.argument<String>("message") ?: "Backup is running"
                    result.success(startBackupForegroundService(title, message))
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_SCHEDULER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 60
                    result.success(
                        AndroidBackgroundScheduler.configure(
                            this,
                            enabled,
                            intervalMinutes
                        )
                    )
                }

                "cancel" -> {
                    AndroidBackgroundScheduler.cancel(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTANT_SYNC_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val rawPaths = call.argument<List<Any>>("paths") ?: emptyList()
                    val paths = rawPaths.mapNotNull { it as? String }
                    result.success(AndroidInstantSync.configure(this, enabled, paths))
                }

                "cancel" -> {
                    AndroidInstantSync.cancel(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_OPTIMIZATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }

                "requestIgnoreBatteryOptimizations" -> {
                    result.success(requestIgnoreBatteryOptimizations())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startBackupForegroundService(title: String, message: String): Boolean {
        return try {
            val intent = Intent(this, BackupForegroundService::class.java).apply {
                putExtra(BackupForegroundService.EXTRA_TITLE, title)
                putExtra(BackupForegroundService.EXTRA_MESSAGE, message)
            }
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

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        return try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        if (isIgnoringBatteryOptimizations()) {
            return true
        }

        return try {
            val requestIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(requestIntent)
            true
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    companion object {
        private const val BACKUP_FOREGROUND_SERVICE_CHANNEL =
            "openbackup/backup_foreground_service"
        private const val WIFI_STATUS_CHANNEL = "openbackup/wifi_status"
        private const val BACKGROUND_SCHEDULER_CHANNEL =
            "openbackup/background_scheduler"
        private const val INSTANT_SYNC_CHANNEL = "openbackup/instant_sync"
        private const val BATTERY_OPTIMIZATION_CHANNEL =
            "openbackup/battery_optimization"
    }
}
