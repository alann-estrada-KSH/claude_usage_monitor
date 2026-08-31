package com.claudeusagemonitor.claude_usage_monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Starts normal app bootstrap, which refreshes accounts through Flutter. */
class TaskerRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REFRESH) return
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (now - preferences.getLong(KEY_LAST_REFRESH, 0L) < MIN_INTERVAL_MS) return
        preferences.edit().putLong(KEY_LAST_REFRESH, now).apply()
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(EXTRA_TASKER_REFRESH, true),
        )
    }

    companion object {
        const val ACTION_REFRESH =
            "com.claudeusagemonitor.claude_usage_monitor.TASKER_REFRESH"
        const val EXTRA_TASKER_REFRESH = "tasker_refresh"
        private const val PREFS_NAME = "tasker_refresh"
        private const val KEY_LAST_REFRESH = "last_refresh"
        private const val MIN_INTERVAL_MS = 30_000L
    }
}
