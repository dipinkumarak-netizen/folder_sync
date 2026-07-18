package com.example.folder_sync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class HeadlessScheduleService : Service() {
    private var flutterEngine: FlutterEngine? = null
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable { stopHeadlessRun() }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (flutterEngine != null) {
            return START_NOT_STICKY
        }

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startHeadlessDart()
        timeoutHandler.postDelayed(timeoutRunnable, TIMEOUT_MILLIS)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        destroyFlutterEngine()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startHeadlessDart() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)

        val engine = FlutterEngine(this)
        GeneratedPluginRegistrant.registerWith(engine)
        registerHeadlessChannels(engine)

        flutterEngine = engine
        val entrypoint = DartExecutor.DartEntrypoint(
            loader.findAppBundlePath(),
            "scheduledSyncMain"
        )
        engine.dartExecutor.executeDartEntrypoint(entrypoint)
    }

    private fun registerHeadlessChannels(engine: FlutterEngine) {
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            HEADLESS_SCHEDULER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "complete" -> {
                    result.success(null)
                    timeoutHandler.post { stopHeadlessRun() }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            WIFI_STATUS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "currentSsid" -> result.success(currentWifiSsid())
                else -> result.notImplemented()
            }
        }
    }

    private fun stopHeadlessRun() {
        destroyFlutterEngine()
        stopForegroundCompat()
        stopSelf()
    }

    private fun destroyFlutterEngine() {
        timeoutHandler.removeCallbacks(timeoutRunnable)
        flutterEngine?.destroy()
        flutterEngine = null
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Scheduled sync",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Runs scheduled sync rules in the background."
        }

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val contentIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("OpenBackup Schedule")
            .setContentText("Scheduled sync is running")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    companion object {
        private const val HEADLESS_SCHEDULER_CHANNEL = "openbackup/headless_scheduler"
        private const val WIFI_STATUS_CHANNEL = "openbackup/wifi_status"
        private const val CHANNEL_ID = "scheduled_sync"
        private const val NOTIFICATION_ID = 2003
        private const val TIMEOUT_MILLIS = 10 * 60 * 1000L
    }
}
