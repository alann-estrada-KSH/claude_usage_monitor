package com.claudeusagemonitor.claude_usage_monitor.wear

import android.app.Activity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

class WearMainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 20, 28, 20)
        }
        root.addView(TextView(this).apply {
            text = getString(R.string.watch_title)
            textSize = 20f
        })
        val payload = getSharedPreferences(WearDataListenerService.PREFS_NAME, MODE_PRIVATE)
            .getString(WearDataListenerService.KEY_PAYLOAD, null)
        if (payload == null) {
            root.addView(TextView(this).apply { text = getString(R.string.no_phone_data) })
        } else {
            val accounts = JSONObject(payload).optJSONArray("accounts")
            if (accounts == null || accounts.length() == 0) {
                root.addView(TextView(this).apply { text = getString(R.string.no_phone_data) })
            } else {
                for (index in 0 until accounts.length()) {
                    val account = accounts.getJSONObject(index)
                    root.addView(TextView(this).apply {
                        text = "${account.optString("label")}\n${account.optString("provider")}  ·  5h ${percent(account, "fiveHourPercent")}  ·  7d ${percent(account, "weeklyPercent")}"
                        setPadding(0, 14, 0, 14)
                    })
                }
            }
        }
        setContentView(root)
    }

    private fun percent(account: JSONObject, key: String): String {
        val value = account.optDouble(key, -1.0)
        return if (value < 0) "--" else "${value.toInt()}%"
    }
}
