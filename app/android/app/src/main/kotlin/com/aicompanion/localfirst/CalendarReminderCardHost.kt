package com.aicompanion.localfirst

import android.app.Activity
import android.graphics.Rect
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import org.json.JSONObject

/** Child of the current Activity; no overlay permission or new page is required. */
class CalendarReminderCardHost(
    private val activity: Activity,
    private val load: () -> List<JSONObject>,
    private val confirm: (String) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var root: FrameLayout? = null
    private var requested = ""
    private var previousVolumeStream = AudioManager.USE_DEFAULT_STREAM_TYPE
    val card: CalendarReminderCard = CalendarReminderCard(activity) {
        confirm(it); requested = ""; refresh()
    }
    private val tick = Runnable { refresh() }
    private val layoutListener = ViewTreeObserver.OnGlobalLayoutListener { fit() }
    private fun dp(value: Int) = (value * activity.resources.displayMetrics.density).toInt()

    fun start() {
        if (root != null) return
        active = this
        previousVolumeStream = activity.volumeControlStream
        root = FrameLayout(activity).also { host ->
            host.isClickable = false; host.isFocusable = false
            host.addView(card, FrameLayout.LayoutParams(dp(280), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.RIGHT).apply {
                setMargins(dp(12), dp(12), dp(12), dp(12))
            })
            activity.addContentView(host, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            host.viewTreeObserver.addOnGlobalLayoutListener(layoutListener)
        }
        refresh()
    }

    fun refresh() {
        val host = root ?: return
        handler.removeCallbacks(tick)
        val items = load()
        activity.volumeControlStream = if (items.any { it.optString("status") == "ringing" })
            AudioManager.STREAM_RING else previousVolumeStream
        card.visibility = if (items.isEmpty()) View.GONE else View.VISIBLE
        if (items.isNotEmpty()) {
            card.show(items.firstOrNull { it.optString("occurrence") == requested } ?: items.first(), items.size)
            handler.postDelayed(tick, 1000)
        }
        host.post { if (root === host) fit() }
    }

    private fun fit() {
        val host = root ?: return
        if (host.width == 0 || host.height == 0) return
        // Subtract only actual overlap, so adjustResize does not double-inset the IME.
        val visible = Rect(); host.getWindowVisibleDisplayFrame(visible)
        val location = IntArray(2); host.getLocationOnScreen(location)
        val left = (visible.left - location[0]).coerceAtLeast(0)
        val top = (visible.top - location[1]).coerceAtLeast(0)
        val right = (location[0] + host.width - visible.right).coerceAtLeast(0)
        val bottom = (location[1] + host.height - visible.bottom).coerceAtLeast(0)
        if (host.paddingLeft != left || host.paddingTop != top || host.paddingRight != right || host.paddingBottom != bottom) {
            host.setPadding(left, top, right, bottom)
        }
        val width = (host.width - left - right - dp(24)).coerceAtLeast(1).coerceAtMost(dp(280))
        if (card.layoutParams.width != width) card.layoutParams = (card.layoutParams as FrameLayout.LayoutParams).apply { this.width = width }
    }

    fun stop() {
        handler.removeCallbacks(tick)
        root?.let { host ->
            host.viewTreeObserver.removeOnGlobalLayoutListener(layoutListener)
            host.removeView(card)
            (host.parent as? ViewGroup)?.removeView(host)
        }
        root = null
        activity.volumeControlStream = previousVolumeStream
        if (active === this) active = null
    }

    companion object {
        private var active: CalendarReminderCardHost? = null
        val foregroundVisible: Boolean get() = active != null
        fun show(occurrence: String): Boolean {
            val host = active ?: return false
            host.requested = occurrence; host.refresh(); return true
        }
    }
}
