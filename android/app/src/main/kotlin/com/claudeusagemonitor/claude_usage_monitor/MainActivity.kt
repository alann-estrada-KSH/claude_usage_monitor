package com.claudeusagemonitor.claude_usage_monitor

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "claude_usage_monitor/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidgets") {
                    val manager = AppWidgetManager.getInstance(this)
                    val ids = manager.getAppWidgetIds(
                        ComponentName(this, UsageWidgetProvider::class.java)
                    )
                    for (id in ids) UsageWidgetProvider.update(this, manager, id)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
