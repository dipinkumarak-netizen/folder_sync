package com.example.folder_sync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            AndroidBackgroundScheduler.rescheduleIfEnabled(context)
        }
    }
}
