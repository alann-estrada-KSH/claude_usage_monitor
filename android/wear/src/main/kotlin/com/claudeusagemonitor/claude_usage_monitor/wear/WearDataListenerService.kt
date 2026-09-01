package com.claudeusagemonitor.claude_usage_monitor.wear

import android.content.ComponentName
import android.content.Context
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester

class WearDataListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED ||
                event.dataItem.uri.path != "/usage-monitor/usage") continue
            val json = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json")
                ?: continue
            val root = WearPayload.parse(json)
            if (WearPayload.accounts(root).isEmpty()) continue
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putString(KEY_PAYLOAD, json).apply()
            ComplicationDataSourceUpdateRequester.create(
                this,
                ComponentName(this, UsageComplicationService::class.java),
            ).requestUpdateAll()
        }
    }

    companion object {
        const val PREFS_NAME = "wear_usage"
        const val KEY_PAYLOAD = "payload"
    }
}
