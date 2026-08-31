package com.claudeusagemonitor.claude_usage_monitor.wear

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import kotlin.math.max
import kotlin.math.min

class UsageBarView(
    context: Context,
    private val usagePercent: Double,
    private val fillColor: Int,
) : View(context) {
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = TRACK_COLOR }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fillColor }
    private val track = RectF()
    private val fill = RectF()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val radius = height / 2f
        track.set(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(track, radius, radius, trackPaint)
        if (usagePercent < 0) return
        val widthRatio = min(100.0, max(0.0, usagePercent)) / 100.0
        fill.set(0f, 0f, (width * widthRatio).toFloat(), height.toFloat())
        canvas.drawRoundRect(fill, radius, radius, fillPaint)
    }

    companion object {
        private const val TRACK_COLOR = 0x55363836
    }
}
