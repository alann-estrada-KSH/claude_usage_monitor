package com.claudeusagemonitor.claude_usage_monitor.wear

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.wear.remote.interactions.RemoteActivityHelper
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import org.json.JSONObject

class WearMainActivity : Activity() {
    private val remoteExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private lateinit var syncStatus: TextView
    private lateinit var accountsContainer: LinearLayout
    private lateinit var noData: TextView
    private lateinit var openPhone: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.wear_main)
        syncStatus = findViewById(R.id.watch_sync_status)
        accountsContainer = findViewById(R.id.watch_accounts)
        noData = findViewById(R.id.watch_no_data)
        openPhone = findViewById(R.id.watch_open_phone)
        openPhone.setOnClickListener { openPhoneApp() }
        renderPayload()
    }

    override fun onDestroy() {
        remoteExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun renderPayload() {
        accountsContainer.removeAllViews()
        val payload = getSharedPreferences(WearDataListenerService.PREFS_NAME, MODE_PRIVATE)
            .getString(WearDataListenerService.KEY_PAYLOAD, null)
        val root = payload?.let { parsePayload(it) }
        val accounts = root?.optJSONArray("accounts")
        if (root == null || accounts == null || accounts.length() == 0) {
            noData.visibility = View.VISIBLE
            accountsContainer.visibility = View.GONE
            syncStatus.text = getString(R.string.no_phone_data)
            return
        }
        noData.visibility = View.GONE
        accountsContainer.visibility = View.VISIBLE

        val updatedAt = root.optString("updatedAt")
        syncStatus.text = if (updatedAt.isEmpty()) {
            getString(R.string.watch_phone_source)
        } else {
            getString(R.string.watch_last_sync, formatTime(updatedAt))
        }
        for (index in 0 until accounts.length()) {
            accountsContainer.addView(accountCard(accounts.getJSONObject(index)))
        }
    }

    private fun parsePayload(value: String): JSONObject? = try {
        JSONObject(value)
    } catch (_: Exception) {
        null
    }

    private fun accountCard(account: JSONObject): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(11), dp(12), dp(12))
            background = surfaceBackground(SURFACE, BORDER)
        }
        val cardParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { bottomMargin = dp(10) }
        card.layoutParams = cardParams

        val header = LinearLayout(this).apply {
            gravity = android.view.Gravity.CENTER_VERTICAL
            orientation = LinearLayout.HORIZONTAL
        }
        val mark = ImageView(this).apply {
            setImageResource(R.drawable.ic_usage_monitor_mark)
            contentDescription = getString(R.string.app_name)
        }
        header.addView(mark, LinearLayout.LayoutParams(dp(18), dp(18)))
        val label = TextView(this).apply {
            text = account.optString("label", getString(R.string.app_name))
            setTextColor(TEXT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        header.addView(label, LinearLayout.LayoutParams(0, dp(20)).apply {
            weight = 1f
            marginStart = dp(7)
        })
        val provider = TextView(this).apply {
            text = account.optString("provider").uppercase(Locale.ROOT)
            setTextColor(ACCENT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 8f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        header.addView(provider, LinearLayout.LayoutParams(dp(48), dp(20)))
        card.addView(header)

        val status = accountStatus(account)
        if (status != null) {
            card.addView(TextView(this).apply {
                text = status
                setTextColor(if (account.optBoolean("sessionExpired")) ERROR else WARNING)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 8f)
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                letterSpacing = 0.08f
                setPadding(0, dp(3), 0, 0)
            })
        }

        val metrics = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(10), 0, 0)
        }
        metrics.addView(
            metric(getString(R.string.watch_5h), account.optDouble("fiveHourPercent", -1.0), ACCENT),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                weight = 1f
                marginEnd = dp(8)
            },
        )
        metrics.addView(
            metric(getString(R.string.watch_7d), account.optDouble("weeklyPercent", -1.0), WEEKLY),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT).apply { weight = 1f },
        )
        card.addView(metrics)
        return card
    }

    private fun metric(label: String, value: Double, color: Int): View {
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val row = LinearLayout(this).apply {
            gravity = android.view.Gravity.CENTER_VERTICAL
            orientation = LinearLayout.HORIZONTAL
        }
        row.addView(TextView(this).apply {
            text = label
            setTextColor(MUTED)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }, LinearLayout.LayoutParams(0, dp(18)).apply { weight = 1f })
        row.addView(TextView(this).apply {
            text = percent(value)
            setTextColor(TEXT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        column.addView(row)
        column.addView(UsageBarView(this, value, color), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(8),
        ).apply { topMargin = dp(4) })
        return column
    }

    private fun accountStatus(account: JSONObject): String? = when {
        account.optBoolean("sessionExpired") -> getString(R.string.watch_session_expired)
        account.optBoolean("hasError") -> getString(R.string.watch_provider_error)
        account.optBoolean("stale") -> getString(R.string.watch_stale)
        else -> null
    }

    private fun openPhoneApp() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("claudeusagemonitor://sync"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        try {
            RemoteActivityHelper(this, remoteExecutor).startRemoteActivity(intent)
                .addListener(Runnable {
                    runOnUiThread { syncStatus.text = getString(R.string.watch_sync_sent) }
                }, remoteExecutor)
        } catch (_: Exception) {
            syncStatus.text = getString(R.string.watch_sync_unavailable)
        }
    }

    private fun formatTime(value: String): String = try {
        DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.systemDefault())
            .format(Instant.parse(value))
    } catch (_: Exception) {
        "--:--"
    }

    private fun percent(value: Double): String =
        if (value < 0) "--" else "${value.toInt()}%"

    private fun surfaceBackground(fill: Int, stroke: Int) =
        android.graphics.drawable.GradientDrawable().apply {
            setColor(fill)
            setStroke(dp(1), stroke)
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()

    companion object {
        private val SURFACE = Color.rgb(17, 20, 17)
        private val BORDER = Color.rgb(46, 50, 46)
        private val TEXT = Color.rgb(230, 230, 225)
        private val MUTED = Color.rgb(140, 147, 140)
        private val ACCENT = Color.rgb(217, 119, 87)
        private val WEEKLY = Color.rgb(245, 184, 107)
        private val WARNING = Color.rgb(204, 153, 0)
        private val ERROR = Color.rgb(255, 85, 85)
    }
}
