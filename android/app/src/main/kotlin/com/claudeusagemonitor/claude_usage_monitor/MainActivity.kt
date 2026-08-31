package com.claudeusagemonitor.claude_usage_monitor

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var watchChannel: MethodChannel? = null

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
        watchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "claude_usage_monitor/watch",
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.data?.scheme == "claudeusagemonitor" && intent.data?.host == "sync") {
            watchChannel?.invokeMethod("refreshNow", null)
        }
    }
}
