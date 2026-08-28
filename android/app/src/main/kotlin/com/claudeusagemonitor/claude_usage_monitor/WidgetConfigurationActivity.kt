package com.claudeusagemonitor.claude_usage_monitor

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView

class WidgetConfigurationActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val accounts = UsageWidgetProvider.readAccounts(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }
        root.addView(TextView(this).apply {
            text = getString(R.string.widget_choose_account)
            textSize = 20f
        })

        if (accounts.isEmpty()) {
            root.addView(TextView(this).apply {
                text = getString(R.string.widget_no_accounts)
                setPadding(0, 24, 0, 24)
            })
        } else {
            val spinner = Spinner(this)
            spinner.adapter = ArrayAdapter(
                this,
                android.R.layout.simple_spinner_dropdown_item,
                accounts.map { it.label },
            )
            root.addView(
                spinner,
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            root.addView(Button(this).apply {
                text = getString(R.string.widget_save)
                setOnClickListener {
                    val selected = accounts[spinner.selectedItemPosition]
                    getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        .edit()
                        .putString("widget_${widgetId}_account_id", selected.id)
                        .apply()
                    UsageWidgetProvider.updateAll(this@WidgetConfigurationActivity)
                    setResult(
                        RESULT_OK,
                        Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                    )
                    finish()
                }
            })
        }
        setContentView(root)
    }
}
