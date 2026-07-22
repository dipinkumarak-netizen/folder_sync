package com.example.folder_sync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            AndroidBackgroundScheduler.rescheduleIfEnabled(context)
            startInstantSyncIfEnabled(context)
        }
    }

    private fun startInstantSyncIfEnabled(context: Context) {
        if (!AndroidInstantSync.isEnabled(context)) {
            return
        }

        val serviceIntent = Intent(context, InstantSyncForegroundService::class.java)
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
}
