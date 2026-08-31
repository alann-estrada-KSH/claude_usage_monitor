package com.claudeusagemonitor.claude_usage_monitor.wear

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceService
import org.json.JSONObject

class ComplicationConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent.getIntExtra(
            ComplicationDataSourceService.EXTRA_CONFIG_COMPLICATION_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val accounts = mutableListOf<Pair<String, String>>()
        val payload = getSharedPreferences(WearDataListenerService.PREFS_NAME, MODE_PRIVATE)
            .getString(WearDataListenerService.KEY_PAYLOAD, null)
        payload?.let {
            val array = JSONObject(it).optJSONArray("accounts")
            if (array != null) for (index in 0 until array.length()) {
                val account = array.getJSONObject(index)
                accounts += account.optString("id") to account.optString("label")
            }
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
        }
        root.addView(TextView(this).apply { text = getString(R.string.complication_choose_account) })
        val spinner = Spinner(this)
        spinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, accounts.map { it.second })
        root.addView(spinner, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        root.addView(Button(this).apply {
            text = getString(R.string.complication_save)
            setOnClickListener {
                if (id != AppWidgetManager.INVALID_APPWIDGET_ID && accounts.isNotEmpty()) {
                    getSharedPreferences(WearDataListenerService.PREFS_NAME, MODE_PRIVATE)
                        .edit().putString("complication_$id", accounts[spinner.selectedItemPosition].first).apply()
                    setResult(RESULT_OK)
                }
                finish()
            }
        })
        setResult(RESULT_CANCELED)
        setContentView(root)
    }
}
