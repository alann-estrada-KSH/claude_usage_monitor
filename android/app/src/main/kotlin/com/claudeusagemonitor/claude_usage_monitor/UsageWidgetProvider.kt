package com.claudeusagemonitor.claude_usage_monitor

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray

class UsageWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) update(context, manager, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
            for (id in ids) remove("widget_${id}_account_id")
        }.apply()
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"

        data class WidgetAccount(
            val id: String,
            val label: String,
            val provider: String,
            val fiveHour: Float,
            val weekly: Float,
            val hasError: Boolean,
            val sessionExpired: Boolean,
            val stale: Boolean,
        )

        fun readAccounts(context: Context): List<WidgetAccount> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val count = (prefs.all["flutter.usage_widget_count"] as? Number)?.toInt() ?: 0
            return (0 until count).map { index ->
                WidgetAccount(
                    id = prefs.getString("flutter.usage_widget_${index}_id", index.toString()) ?: index.toString(),
                    label = prefs.getString(
                        "flutter.usage_widget_${index}_label",
                        context.getString(R.string.app_name),
                    ) ?: context.getString(R.string.app_name),
                    provider = prefs.getString(
                        "flutter.usage_widget_${index}_provider",
                        "Claude",
                    ) ?: "Claude",
                    fiveHour = readNumber(prefs, "flutter.usage_widget_${index}_five_hour"),
                    weekly = readNumber(prefs, "flutter.usage_widget_${index}_weekly"),
                    hasError = prefs.getBoolean("flutter.usage_widget_${index}_has_error", false),
                    sessionExpired = prefs.getBoolean("flutter.usage_widget_${index}_session_expired", false),
                    stale = prefs.getBoolean("flutter.usage_widget_${index}_stale", true),
                )
            }
        }

        private fun readNumber(prefs: android.content.SharedPreferences, key: String): Float {
            return when (val value = prefs.all[key]) {
                is Number -> value.toFloat()
                is String -> value.toFloatOrNull() ?: -1f
                else -> -1f
            }
        }

        fun selectedAccount(context: Context, widgetId: Int): WidgetAccount? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val selectedId = prefs.getString("widget_${widgetId}_account_id", null)
            val accounts = selectedAccounts(context)
            return accounts.firstOrNull { it.id == selectedId } ?: accounts.firstOrNull()
        }

        fun selectedAccounts(context: Context): List<WidgetAccount> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val accounts = readAccounts(context)
            if (prefs.getBoolean("flutter.widget_all_accounts", true)) return accounts
            val selectedIds = runCatching {
                val json = prefs.getString("flutter.widget_account_ids_json", "[]") ?: "[]"
                JSONArray(json).let { array -> (0 until array.length()).map { array.getString(it) }.toSet() }
            }.getOrDefault(emptySet())
            return accounts.filter { it.id in selectedIds }
        }

        fun formatUsage(context: Context, account: WidgetAccount): String = when {
            account.hasError -> context.getString(R.string.widget_error)
            account.sessionExpired -> context.getString(R.string.widget_session_expired)
            account.fiveHour < 0f -> context.getString(R.string.widget_no_data)
        else -> context.getString(
            if (account.stale) R.string.widget_usage_stale_format else R.string.widget_usage_format,
            account.fiveHour.toInt(),
            account.weekly.toInt(),
        )
        }

        fun compactProviderName(provider: String): String = when {
            provider.startsWith("Codex") -> "Codex"
            provider.startsWith("Antigravity") -> "Antigravity"
            provider == "GitHub Copilot" -> "Copilot"
            provider == "OpenCode Go" -> "OpenCode"
            else -> provider
        }

        fun bindLaunch(context: Context, views: RemoteViews, rootId: Int, requestCode: Int) {
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(rootId, pendingIntent)
        }

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val account = selectedAccount(context, widgetId)
            val views = RemoteViews(context.packageName, R.layout.usage_widget)
            bindLaunch(context, views, R.id.widget_root, widgetId)
            if (account == null) {
                views.setTextViewText(R.id.widget_label, context.getString(R.string.app_name))
                views.setTextViewText(R.id.widget_provider, "")
                views.setTextViewText(R.id.widget_five_hour, context.getString(R.string.widget_no_accounts))
                views.setTextViewText(R.id.widget_weekly, "")
                views.setProgressBar(R.id.widget_five_progress, 100, 0, false)
                views.setProgressBar(R.id.widget_weekly_progress, 100, 0, false)
            } else {
                views.setTextViewText(R.id.widget_label, account.label)
                views.setTextViewText(
                    R.id.widget_provider,
                    compactProviderName(account.provider) + if (account.stale) " · " + context.getString(R.string.widget_stale) else "",
                )
                views.setProgressBar(
                    R.id.widget_five_progress,
                    100,
                    account.fiveHour.toInt().coerceIn(0, 100),
                    false,
                )
                views.setProgressBar(
                    R.id.widget_weekly_progress,
                    100,
                    account.weekly.toInt().coerceIn(0, 100),
                    false,
                )
                when {
                    account.hasError -> {
                        views.setTextViewText(R.id.widget_five_hour, context.getString(R.string.widget_error))
                        views.setTextViewText(R.id.widget_weekly, "")
                    }
                    account.sessionExpired -> {
                        views.setTextViewText(R.id.widget_five_hour, context.getString(R.string.widget_session_expired))
                        views.setTextViewText(R.id.widget_weekly, context.getString(R.string.widget_relogin))
                    }
                    account.fiveHour < 0f -> {
                        views.setTextViewText(R.id.widget_five_hour, context.getString(R.string.widget_session_pending))
                        views.setTextViewText(R.id.widget_weekly, context.getString(R.string.widget_weekly_pending))
                    }
                    else -> {
                        views.setTextViewText(
                            R.id.widget_five_hour,
                            context.getString(R.string.widget_percent, account.fiveHour.toInt()),
                        )
                        views.setTextViewText(
                            R.id.widget_weekly,
                            context.getString(
                                if (account.stale) R.string.widget_weekly_stale_format else R.string.widget_percent,
                                account.weekly.toInt(),
                            ),
                        )
                    }
                }
            }
            manager.updateAppWidget(widgetId, views)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, UsageWidgetProvider::class.java),
            )
            for (id in ids) update(context, manager, id)
        }
    }
}
