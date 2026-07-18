package com.example.folder_sync

import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
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

    companion object {
        private const val BACKUP_FOREGROUND_SERVICE_CHANNEL =
            "openbackup/backup_foreground_service"
    }
}
