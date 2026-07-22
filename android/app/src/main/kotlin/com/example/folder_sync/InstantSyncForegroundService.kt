package com.example.folder_sync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.FileObserver
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.io.File

class InstantSyncForegroundService : Service() {
    private val observers = mutableListOf<FileObserver>()
    private val observedDirectories = mutableSetOf<String>()
    private val debounceHandler = Handler(Looper.getMainLooper())
    private val runInstantSync = Runnable { startInstantSyncHeadlessRun() }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!AndroidInstantSync.isEnabled(this)) {
            stopSelf()
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

        restartObservers()
        return START_STICKY
    }

    override fun onDestroy() {
        stopObservers()
        debounceHandler.removeCallbacks(runInstantSync)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun restartObservers() {
        stopObservers()
        for (path in AndroidInstantSync.configuredPaths(this)) {
            val directory = File(path)
            if (!directory.exists() || !directory.isDirectory) {
                continue
            }

            startWatchingDirectoryTree(directory)
        }

        if (observers.isEmpty()) {
            stopSelf()
        }
    }

    private fun stopObservers() {
        for (observer in observers) {
            observer.stopWatching()
        }
        observers.clear()
        observedDirectories.clear()
    }

    private fun startWatchingDirectoryTree(directory: File) {
        val directoryKey = try {
            directory.canonicalPath
        } catch (_: Exception) {
            directory.absolutePath
        }

        if (!observedDirectories.add(directoryKey)) {
            return
        }

        val observer = newObserver(directory)
        observer.startWatching()
        observers.add(observer)

        val children = try {
            directory.listFiles()
        } catch (_: Exception) {
            null
        } ?: return

        for (child in children) {
            if (child.isDirectory) {
                startWatchingDirectoryTree(child)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun newObserver(directory: File): FileObserver {
        val mask = FileObserver.CREATE or
            FileObserver.MODIFY or
            FileObserver.MOVED_TO or
            FileObserver.CLOSE_WRITE

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            object : FileObserver(directory, mask) {
                override fun onEvent(event: Int, path: String?) {
                    handleFileEvent(directory, event, path)
                }
            }
        } else {
            object : FileObserver(directory.absolutePath, mask) {
                override fun onEvent(event: Int, path: String?) {
                    handleFileEvent(directory, event, path)
                }
            }
        }
    }

    private fun handleFileEvent(directory: File, event: Int, path: String?) {
        val eventType = event and FileObserver.ALL_EVENTS
        if (path != null &&
            (eventType == FileObserver.CREATE || eventType == FileObserver.MOVED_TO)
        ) {
            val child = File(directory, path)
            if (child.isDirectory) {
                startWatchingDirectoryTree(child)
            }
        }

        scheduleInstantSync()
    }

    private fun scheduleInstantSync() {
        debounceHandler.removeCallbacks(runInstantSync)
        debounceHandler.postDelayed(runInstantSync, DEBOUNCE_MILLIS)
    }

    private fun startInstantSyncHeadlessRun() {
        val serviceIntent = Intent(this, HeadlessScheduleService::class.java).apply {
            putExtra(HeadlessScheduleService.EXTRA_DART_ENTRYPOINT, "instantSyncMain")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (_: Exception) {
            return
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Instant sync",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Watches local folders for instant sync."
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
            .setContentTitle("OpenBackup Instant Sync")
            .setContentText("Watching folders for changes")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "instant_sync"
        private const val NOTIFICATION_ID = 2004
        private const val DEBOUNCE_MILLIS = 5_000L
    }
}
