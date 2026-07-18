package com.example.folder_sync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BackgroundScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AndroidBackgroundScheduler.rescheduleIfEnabled(context)

        if (intent?.action != ACTION_RUN_SCHEDULE) {
            return
        }

        showScheduleNotification(context)
    }

    private fun showScheduleNotification(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Schedule alerts",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows scheduled sync reminders."
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val contentIntent = PendingIntent.getActivity(context, 0, launchIntent, pendingFlags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("OpenBackup Schedule")
            .setContentText("Scheduled sync check is ready")
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()

        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (_: Exception) {
            return
        }
    }

    companion object {
        const val ACTION_RUN_SCHEDULE = "com.example.folder_sync.action.RUN_SCHEDULE"
        private const val CHANNEL_ID = "schedule_alerts"
        private const val NOTIFICATION_ID = 2002
    }
}
