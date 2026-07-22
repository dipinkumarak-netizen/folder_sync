package com.example.folder_sync

import android.content.Context
import android.content.Intent
import android.os.Build

object AndroidInstantSync {
    private const val PREFS_NAME = "openbackup_instant_sync"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PATHS = "paths"

    fun configure(context: Context, enabled: Boolean, paths: List<String>): Boolean {
        val cleanPaths = paths
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled && cleanPaths.isNotEmpty())
            .putStringSet(KEY_PATHS, cleanPaths.toSet())
            .apply()

        val intent = Intent(context, InstantSyncForegroundService::class.java)
        return try {
            if (enabled && cleanPaths.isNotEmpty()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } else {
                context.stopService(intent)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    fun cancel(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .remove(KEY_PATHS)
            .apply()
        try {
            context.stopService(Intent(context, InstantSyncForegroundService::class.java))
        } catch (_: Exception) {
            return
        }
    }

    fun isEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
    }

    fun configuredPaths(context: Context): Set<String> {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getStringSet(KEY_PATHS, emptySet())
            ?: emptySet()
    }
}
