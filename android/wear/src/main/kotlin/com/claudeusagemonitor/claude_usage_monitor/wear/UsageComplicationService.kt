package com.claudeusagemonitor.claude_usage_monitor.wear

import android.content.ComponentName
import android.content.Intent
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceService
import org.json.JSONObject

class UsageComplicationService : ComplicationDataSourceService() {
    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationDataSourceService.ComplicationRequestListener,
    ) {
        val payload = getSharedPreferences(WearDataListenerService.PREFS_NAME, MODE_PRIVATE)
            .getString(WearDataListenerService.KEY_PAYLOAD, null)
        val text = payload?.let { complicationText(JSONObject(it), request.complicationInstanceId) }
            ?: "--"
        val data: ComplicationData = ShortTextComplicationData.Builder(
            PlainComplicationText.Builder(text).build(),
            PlainComplicationText.Builder("Usage Monitor").build(),
        ).setTapAction(
            android.app.PendingIntent.getActivity(
                this,
                request.complicationInstanceId,
                Intent(this, WearMainActivity::class.java),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
            ),
        ).build()
        listener.onComplicationData(data)
    }

    override fun getPreviewData(type: ComplicationType): ComplicationData =
        ShortTextComplicationData.Builder(
            PlainComplicationText.Builder("5h --").build(),
            PlainComplicationText.Builder("Usage Monitor").build(),
        ).build()

    private fun complicationText(payload: JSONObject, instanceId: Int): String {
        val accounts = payload.optJSONArray("accounts") ?: return "--"
        val selected = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getString("complication_$instanceId", null)
        for (index in 0 until accounts.length()) {
            val account = accounts.getJSONObject(index)
            if (selected == null || selected == account.optString("id")) {
                val value = account.optDouble("fiveHourPercent", -1.0)
                return if (value < 0) "5h --" else "5h ${value.toInt()}%"
            }
        }
        return "--"
    }

    companion object {
        private const val PREFS_NAME = WearDataListenerService.PREFS_NAME
    }
}
