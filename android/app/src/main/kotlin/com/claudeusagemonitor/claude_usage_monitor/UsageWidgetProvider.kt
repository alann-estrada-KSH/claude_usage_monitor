package com.claudeusagemonitor.claude_usage_monitor

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class UsageWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) update(context, manager, id)
    }

    companion object {
        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val count = prefs.getInt("flutter.usage_widget_count", 0)
            val views = RemoteViews(context.packageName, R.layout.usage_widget)

            if (count == 0) {
                views.setTextViewText(R.id.widget_label, "Claude Usage Monitor")
                views.setTextViewText(R.id.widget_five_hour, "Session: --")
                views.setTextViewText(R.id.widget_weekly, "Weekly: --")
            } else {
                val label = prefs.getString("flutter.usage_widget_0_label", "Claude") ?: "Claude"
                val fiveHour = prefs.getFloat("flutter.usage_widget_0_five_hour", -1f)
                val weekly = prefs.getFloat("flutter.usage_widget_0_weekly", -1f)
                val hasError = prefs.getBoolean("flutter.usage_widget_0_has_error", false)
                val expired = prefs.getBoolean("flutter.usage_widget_0_session_expired", false)

                views.setTextViewText(R.id.widget_label, label)
                when {
                    hasError -> {
                        views.setTextViewText(R.id.widget_five_hour, "Session: error")
                        views.setTextViewText(R.id.widget_weekly, "Weekly: error")
                    }
                    expired -> {
                        views.setTextViewText(R.id.widget_five_hour, "Session expired")
                        views.setTextViewText(R.id.widget_weekly, "Re-login in app")
                    }
                    fiveHour < 0 -> {
                        views.setTextViewText(R.id.widget_five_hour, "Session: --")
                        views.setTextViewText(R.id.widget_weekly, "Weekly: --")
                    }
                    else -> {
                        views.setTextViewText(R.id.widget_five_hour, "Session: ${fiveHour.toInt()}%")
                        views.setTextViewText(R.id.widget_weekly, "Weekly: ${weekly.toInt()}%")
                    }
                }
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}
