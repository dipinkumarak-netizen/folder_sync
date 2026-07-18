package com.example.folder_sync

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object AndroidBackgroundScheduler {
    private const val PREFS_NAME = "openbackup_background_scheduler"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_INTERVAL_MINUTES = "interval_minutes"
    private const val REQUEST_CODE = 2001
    private const val WINDOW_MILLIS = 5 * 60 * 1000L

    fun configure(context: Context, enabled: Boolean, intervalMinutes: Int): Boolean {
        val safeInterval = intervalMinutes.coerceAtLeast(15)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_INTERVAL_MINUTES, safeInterval)
            .apply()

        if (!enabled) {
            cancel(context)
            return true
        }

        scheduleNext(context, safeInterval)
        return true
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context))
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .apply()
    }

    fun rescheduleIfEnabled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            return
        }

        scheduleNext(context, prefs.getInt(KEY_INTERVAL_MINUTES, 60))
    }

    private fun scheduleNext(context: Context, intervalMinutes: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis = System.currentTimeMillis() + intervalMinutes * 60 * 1000L
        val operation = pendingIntent(context)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            alarmManager.setWindow(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                WINDOW_MILLIS,
                operation
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
        }
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, BackgroundScheduleReceiver::class.java).apply {
            action = BackgroundScheduleReceiver.ACTION_RUN_SCHEDULE
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }
}
