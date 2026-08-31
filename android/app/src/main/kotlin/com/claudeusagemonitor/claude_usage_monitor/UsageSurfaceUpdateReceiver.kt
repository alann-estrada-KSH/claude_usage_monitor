package com.claudeusagemonitor.claude_usage_monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class UsageSurfaceUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_UPDATE) return
        UsageWidgetProvider.updateAll(context)
        UsageOverviewWidgetProvider.updateAll(context)
        val pendingResult = goAsync()
        val payload = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString("flutter.wear_usage_payload", null) ?: EMPTY_PAYLOAD
        val request = PutDataMapRequest.create("/usage-monitor/usage").apply {
            dataMap.putString("json", payload)
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(request)
            .addOnCompleteListener { pendingResult.finish() }
    }

    companion object {
        const val ACTION_UPDATE =
            "com.claudeusagemonitor.claude_usage_monitor.UPDATE_SURFACES"
        private const val EMPTY_PAYLOAD = "{\"version\":1,\"accounts\":[]}"
        private const val PREFS_NAME = "FlutterSharedPreferences"
    }
}
