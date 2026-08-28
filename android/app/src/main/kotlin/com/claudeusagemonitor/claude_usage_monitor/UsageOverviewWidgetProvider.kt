package com.claudeusagemonitor.claude_usage_monitor

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class UsageOverviewWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) update(context, manager, id)
    }

    companion object {
        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.usage_widget_overview)
            UsageWidgetProvider.bindLaunch(context, views, R.id.widget_root, widgetId)
            val accounts = UsageWidgetProvider.selectedAccounts(context)
            views.removeAllViews(R.id.widget_accounts)
            views.setViewVisibility(
                R.id.widget_empty,
                if (accounts.isEmpty()) android.view.View.VISIBLE else android.view.View.GONE,
            )
            for (account in accounts) {
                val row = RemoteViews(context.packageName, R.layout.usage_widget_account_row)
                row.setTextViewText(R.id.widget_account_label, account.label)
                row.setTextViewText(
                    R.id.widget_account_provider,
                    UsageWidgetProvider.compactProviderName(account.provider),
                )
                row.setTextViewText(
                    R.id.widget_account_five_value,
                    if (account.fiveHour >= 0f) {
                        context.getString(R.string.widget_five_compact, account.fiveHour.toInt())
                    } else {
                        UsageWidgetProvider.formatUsage(context, account)
                    },
                )
                row.setTextViewText(
                    R.id.widget_account_weekly_value,
                    if (account.weekly >= 0f) {
                        context.getString(R.string.widget_weekly_compact, account.weekly.toInt())
                    } else {
                        context.getString(R.string.widget_no_data)
                    },
                )
                row.setProgressBar(
                    R.id.widget_account_five_progress,
                    100,
                    account.fiveHour.toInt().coerceIn(0, 100),
                    false,
                )
                row.setProgressBar(
                    R.id.widget_account_weekly_progress,
                    100,
                    account.weekly.toInt().coerceIn(0, 100),
                    false,
                )
                views.addView(R.id.widget_accounts, row)
            }
            manager.updateAppWidget(widgetId, views)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, UsageOverviewWidgetProvider::class.java),
            )
            for (id in ids) update(context, manager, id)
        }
    }
}
