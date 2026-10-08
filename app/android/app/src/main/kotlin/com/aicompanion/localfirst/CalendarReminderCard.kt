package com.aicompanion.localfirst

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

/** One compact presentation for the existing screen, system overlay and lock screen. */
class CalendarReminderCard(context: Context, private val confirm: (String) -> Unit) : LinearLayout(context) {
    private val accent = Color.rgb(196, 169, 255)
    private val muted = Color.rgb(183, 175, 197)
    private val title = TextView(context)
    private val time = TextView(context)
    private val state = TextView(context)
    private val details = TextView(context)
    private val heading = TextView(context)
    private val progress = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal)
    private var occurrence = ""
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    val confirmButton = Button(context).apply {
        text = "确认"; textSize = 13f; isAllCaps = false
        minWidth = dp(48); minimumWidth = dp(48); minHeight = 0; minimumHeight = 0
        setTextColor(accent)
        background = android.graphics.drawable.InsetDrawable(GradientDrawable().apply {
            setColor(Color.rgb(54, 43, 76)); cornerRadius = dp(12).toFloat()
            setStroke(dp(1).coerceAtLeast(1), Color.rgb(86, 66, 120))
        }, 0, dp(6), 0, dp(6))
        // Assign after the background, which can replace View's padding.
        setPadding(dp(14), 0, dp(14), 0)
        setOnClickListener { if (occurrence.isNotEmpty()) confirm(occurrence) }
    }
    init {
        orientation = VERTICAL
        isClickable = true
        setPadding(dp(16), dp(14), dp(16), dp(8))
        background = GradientDrawable().apply {
            setColor(Color.rgb(29, 26, 40)); cornerRadius = dp(20).toFloat()
            setStroke(dp(1).coerceAtLeast(1), Color.rgb(70, 60, 91))
        }
        elevation = dp(10).toFloat()
        heading.setTextColor(accent); heading.textSize = 12f; addView(heading)
        title.setTextColor(Color.WHITE); title.textSize = 17f; title.maxLines = 2
        title.ellipsize = android.text.TextUtils.TruncateAt.END
        title.setPadding(0, dp(10), 0, dp(8)); addView(title)
        val timerRow = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
        time.setTextColor(accent); time.textSize = 30f; time.typeface = Typeface.MONOSPACE
        timerRow.addView(time)
        state.setTextColor(muted); state.textSize = 11f
        timerRow.addView(state, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f).apply { leftMargin = dp(10) })
        addView(timerRow)
        progress.max = 1000; progress.progressTintList = ColorStateList.valueOf(accent)
        progress.progressBackgroundTintList = ColorStateList.valueOf(Color.rgb(58, 49, 77))
        addView(progress, LayoutParams(LayoutParams.MATCH_PARENT, dp(4)).apply { topMargin = dp(10); bottomMargin = dp(4) })
        val footer = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
        details.setTextColor(muted); details.textSize = 11f; details.maxLines = 2
        footer.addView(details, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        // A small visible pill with a 48dp touch target.
        footer.addView(confirmButton, LayoutParams(LayoutParams.WRAP_CONTENT, dp(48)))
        addView(footer)
    }
    fun show(item: JSONObject, count: Int = 1) {
        occurrence = item.optString("occurrence"); title.text = item.optString("title")
        heading.text = "●  待办提醒" + if (count > 1) " · 共 $count 条" else ""
        val ringing = item.optString("status") == "ringing"
        val remaining = CalendarReminderRuntime.remaining(item)
        val seconds = (remaining + 999) / 1000
        time.textSize = if (ringing) 30f else 19f
        time.text = if (ringing) String.format(Locale.ROOT, "%02d:%02d", seconds / 60, seconds % 60)
            else if (item.optString("status") == "timed_out") "超时未确认" else "提醒曾中断"
        state.text = if (ringing) "剩余响铃" else ""
        val start = SimpleDateFormat("HH:mm", Locale.getDefault()).format(java.util.Date(item.optLong("startedAt")))
        details.text = "$start 开始 · 确认收到"
        progress.progress = if (ringing) ((CalendarReminderRuntime.FIVE_MINUTES - remaining) * 1000 / CalendarReminderRuntime.FIVE_MINUTES).toInt() else 1000
        confirmButton.isEnabled = true
    }
}
