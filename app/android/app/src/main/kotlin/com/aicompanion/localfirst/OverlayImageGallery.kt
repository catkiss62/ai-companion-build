package com.aicompanion.localfirst

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/** One bounded viewport. Decode ownership remains with the Service's tagged loader. */
internal class OverlayImageGallery(
    context: Context,
    private val paths: List<String>,
    initialPage: Int,
    private val bind: (ImageView, String) -> Unit,
    private val changed: (Int) -> Unit,
) : LinearLayout(context) {
    var page: Int = initialPage.coerceIn(0, (paths.size - 1).coerceAtLeast(0))
        private set
    private val image = ImageView(context).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
    private val dots = TextView(context).apply {
        gravity = Gravity.CENTER
        textSize = 12f
        setTextColor(Color.rgb(207, 184, 245))
    }
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private var startX = 0f
    private var startY = 0f
    private var axis = 0
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    init {
        orientation = VERTICAL
        val frame = FrameLayout(context)
        frame.addView(TextView(context).apply {
            text = "图片加载中或暂不可用"
            gravity = Gravity.CENTER
            textSize = 11f
            setTextColor(Color.rgb(160, 153, 174))
        }, FrameLayout.LayoutParams(-1, -1))
        image.setBackgroundColor(Color.rgb(53, 51, 60))
        frame.addView(image, FrameLayout.LayoutParams(-1, -1))
        addView(frame, LayoutParams(-1, dp(180)))
        if (paths.size > 1) addView(dots, LayoutParams(-1, -2))
        showPage()
    }

    private fun showPage() {
        if (paths.isEmpty()) return
        image.setImageDrawable(null)
        image.contentDescription = "聊天图片 ${page + 1}/${paths.size}"
        dots.text = paths.indices.joinToString(" ") { if (it == page) "●" else "○" }
        contentDescription = "第 ${page + 1} 张，共 ${paths.size} 张图片，左右滑动切换"
        bind(image, paths[page])
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (paths.size < 2) return super.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                startX = event.x; startY = event.y; axis = 0
                parent?.requestDisallowInterceptTouchEvent(true)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.x - startX; val dy = event.y - startY
                if (axis == 0 && maxOf(abs(dx), abs(dy)) > slop) {
                    axis = if (abs(dx) > abs(dy)) 1 else 2
                    parent?.requestDisallowInterceptTouchEvent(axis == 1)
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                val dx = event.x - startX
                if (axis == 1 && abs(dx) > maxOf(slop * 2, dp(28))) {
                    val next = (page + if (dx < 0) 1 else -1).coerceIn(0, paths.lastIndex)
                    if (next != page) { page = next; showPage(); changed(page) }
                }
                parent?.requestDisallowInterceptTouchEvent(false)
                if (axis == 0) performClick()
                axis = 0
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                parent?.requestDisallowInterceptTouchEvent(false)
                axis = 0
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean { super.performClick(); return true }
}
