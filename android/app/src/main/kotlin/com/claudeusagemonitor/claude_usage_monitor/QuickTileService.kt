package com.claudeusagemonitor.claude_usage_monitor

import android.annotation.TargetApi
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

@TargetApi(Build.VERSION_CODES.N)
class QuickTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        refresh()
    }

    private fun refresh() {
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val count = prefs.getInt("flutter.usage_widget_count", 0)
        val tile = qsTile ?: return

        if (count == 0) {
            tile.label = "Usage Monitor"
            tile.state = Tile.STATE_INACTIVE
        } else {
            val label = prefs.getString("flutter.usage_widget_0_label", "Claude") ?: "Claude"
            val fiveHour = prefs.getFloat("flutter.usage_widget_0_five_hour", -1f)
            val weekly = prefs.getFloat("flutter.usage_widget_0_weekly", -1f)
            val hasError = prefs.getBoolean("flutter.usage_widget_0_has_error", false)
            val expired = prefs.getBoolean("flutter.usage_widget_0_session_expired", false)

            tile.label = label
            when {
                hasError -> {
                    tile.contentDescription = "Error fetching data"
                    tile.state = Tile.STATE_UNAVAILABLE
                }
                expired -> {
                    tile.contentDescription = "Session expired"
                    tile.state = Tile.STATE_UNAVAILABLE
                }
                fiveHour < 0 -> {
                    tile.contentDescription = "No data yet"
                    tile.state = Tile.STATE_INACTIVE
                }
                else -> {
                    tile.contentDescription =
                        "Session ${fiveHour.toInt()}%  ·  Weekly ${weekly.toInt()}%"
                    tile.state = Tile.STATE_ACTIVE
                }
            }
        }
        tile.updateTile()
    }
}
