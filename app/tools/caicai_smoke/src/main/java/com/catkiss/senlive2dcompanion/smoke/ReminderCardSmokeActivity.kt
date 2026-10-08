package com.catkiss.senlive2dcompanion.smoke

import android.app.Activity
import android.os.Bundle
import android.media.AudioManager
import android.graphics.Color
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout
import com.aicompanion.localfirst.CalendarReminderCard
import com.aicompanion.localfirst.CalendarReminderCardHost
import com.aicompanion.localfirst.CalendarReminderRuntime

/** Test host only; journal, card and in-place host are production implementations. */
class ReminderCardSmokeActivity : Activity() {
    lateinit var host: CalendarReminderCardHost
    val card: CalendarReminderCard get() = host.card
    var outsideClicks = 0
    lateinit var outsideButton: Button
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_MUSIC
        outsideButton = Button(this).apply { text = "原页面仍可操作"; setOnClickListener { outsideClicks++ } }
        setContentView(FrameLayout(this).apply {
            setBackgroundColor(Color.rgb(18, 16, 27))
            addView(outsideButton, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.LEFT))
        })
        host = CalendarReminderCardHost(this, {
            CalendarReminderRuntime.records(this).filter { !it.optBoolean("retired") && it.optString("status") in setOf("ringing", "timed_out", "interrupted") }
                .sortedWith(compareBy<org.json.JSONObject> { if (it.optString("status") == "ringing") 0 else 1 }.thenBy { it.optLong("startedAt") })
        }, { CalendarReminderRuntime.confirm(this, it) })
    }
    override fun onResume() { super.onResume(); host.start() }
    override fun onPause() { host.stop(); super.onPause() }
}
