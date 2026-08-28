package com.claudeusagemonitor.claude_usage_monitor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "claude_usage_monitor/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidgets") {
                    UsageWidgetProvider.updateAll(this)
                    UsageOverviewWidgetProvider.updateAll(this)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
