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
        val account = UsageWidgetProvider.readAccounts(applicationContext).firstOrNull()
        val tile = qsTile ?: return
        if (account == null) {
            tile.label = getString(R.string.app_name)
            tile.contentDescription = getString(R.string.widget_no_accounts)
            tile.state = Tile.STATE_INACTIVE
        } else {
            tile.label = account.label
            when {
                account.hasError -> {
                    tile.contentDescription = getString(R.string.widget_error)
                    tile.state = Tile.STATE_UNAVAILABLE
                }
                account.sessionExpired -> {
                    tile.contentDescription = getString(R.string.widget_session_expired)
                    tile.state = Tile.STATE_UNAVAILABLE
                }
                account.fiveHour < 0f -> {
                    tile.contentDescription = getString(R.string.widget_no_data)
                    tile.state = Tile.STATE_INACTIVE
                }
                else -> {
                    tile.contentDescription = getString(
                        if (account.stale) R.string.widget_usage_stale_format else R.string.widget_usage_format,
                        account.fiveHour.toInt(),
                        account.weekly.toInt(),
                    )
                    tile.state = Tile.STATE_ACTIVE
                }
            }
        }
        tile.updateTile()
    }
}
