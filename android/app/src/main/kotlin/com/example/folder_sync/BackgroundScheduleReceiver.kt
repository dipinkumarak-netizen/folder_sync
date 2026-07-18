package com.example.folder_sync

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

        val serviceIntent = Intent(context, HeadlessScheduleService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (_: Exception) {
            return
        }
    }

    companion object {
        const val ACTION_RUN_SCHEDULE = "com.example.folder_sync.action.RUN_SCHEDULE"
    }
}
