package com.aicompanion.localfirst.pet

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.aicompanion.localfirst.OverlayBubbleService
import kotlin.math.abs
import kotlin.math.hypot

/**
 * System-overlay host for the source-parity pet player.
 *
 * It deliberately owns only the visual entry window. Chat, unread state,
 * foreground lifetime and the background brain remain owned by
 * [OverlayBubbleService], so pet and legacy bubble are two modes of the same
 * companion service rather than two competing services.
 */
class PetOverlayWindow(
    private val context: Context,
    private val windowManager: WindowManager,
    private val overlayWindowType: Int,
    private val onOpenChat: () -> Unit,
    private val onSwitchToBubble: () -> Unit,
    private val onTouchActivity: (String) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val prefs = context.getSharedPreferences(
        OverlayBubbleService.PREFS,
        Context.MODE_PRIVATE,
    )
    private val physics = PetThrowPhysics()
    private val samples = ArrayDeque<DragSample>()
    private val recentPokes = ArrayDeque<Long>()

    var root: FrameLayout? = null
        private set
    var params: WindowManager.LayoutParams? = null
        private set
    var badge: TextView? = null
        private set

    private var frameView: PetFrameView? = null
    private var player: PetAnimationPlayer? = null
    private var cache: PetFrameCache? = null
    private var optionsRoot: LinearLayout? = null
    private var optionsParams: WindowManager.LayoutParams? = null

    private var pressRawX = 0f
    private var pressRawY = 0f
    private var startWindowX = 0
    private var startWindowY = 0
    private var dragging = false
    private var pressedRegion = "body"
    private var longPressHandled = false
    private var doubleTapCandidate = false
    private var lastTapAtMs = 0L
    private var lastTapRawX = 0f
    private var lastTapRawY = 0f
    private var pendingSingleTap: Runnable? = null
    private var physicsLastAtMs = 0L

    private val longPress = Runnable {
        if (dragging || pressedRegion !in setOf("head", "face")) return@Runnable
        longPressHandled = true
        player?.play("HEAD_PAT", reason = "pet_overlay_head_hold", force = true)
    }

    private val physicsTick = object : Runnable {
        override fun run() {
            val layout = params ?: return
            val view = root ?: return
            if (!physics.active || !view.isAttachedToWindow) return
            val now = SystemClock.uptimeMillis()
            val delta = if (physicsLastAtMs == 0L) 0f else
                ((now - physicsLastAtMs).coerceIn(0L, 100L) / 1000f)
            physicsLastAtMs = now
            val safe = safeArea()
            val step = physics.step(
                deltaSeconds = delta,
                spriteWidth = layout.width.toFloat(),
                spriteHeight = layout.height.toFloat(),
                bounds = PetPhysicsBounds(
                    safe.left.toFloat(),
                    safe.top.toFloat(),
                    safe.right.toFloat(),
                    safe.bottom.toFloat(),
                ),
            )
            layout.x = step.x.toInt()
            layout.y = step.y.toInt()
            runCatching { windowManager.updateViewLayout(view, layout) }
            if (step.settled) {
                player?.play("LANDING", reason = "pet_overlay_landing", force = true, immediate = true)
                if (step.hardLanding) player?.queueAfterCurrent("DIZZY")
                persistPosition()
                return
            }
            handler.postDelayed(this, 16L)
        }
    }

    fun attach(): Boolean {
        if (root?.isAttachedToWindow == true) return true
        val manifest = PetSkinManifest.load(context.assets)
        val frameCache = PetFrameCache(context.assets)
        val petView = PetFrameView(context)
        val container = FrameLayout(context).apply {
            clipChildren = false
            clipToPadding = false
            setBackgroundColor(Color.TRANSPARENT)
        }
        container.addView(
            petView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        val unread = TextView(context).apply {
            textSize = 10f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = rounded(Color.rgb(229, 69, 96), 999f)
            elevation = dp(8).toFloat()
            visibility = View.GONE
        }
        container.addView(
            unread,
            FrameLayout.LayoutParams(dp(22), dp(22)).apply {
                gravity = Gravity.TOP or Gravity.END
                setMargins(0, dp(3), dp(3), 0)
            },
        )

        val size = normalizedSize(prefs.getString(KEY_PET_SIZE, PET_SIZE_MEDIUM))
        val windowPx = dp(windowDp(size))
        val safe = safeArea()
        val defaultX = (safe.right - windowPx).coerceAtLeast(safe.left)
        val defaultY = (safe.top + safe.height / 3).coerceAtMost(
            (safe.bottom - windowPx).coerceAtLeast(safe.top),
        )
        val layout = WindowManager.LayoutParams(
            windowPx,
            windowPx,
            overlayWindowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(KEY_PET_X, defaultX)
            y = prefs.getInt(KEY_PET_Y, defaultY)
        }
        clamp(layout)

        val animation = PetAnimationPlayer(
            manifest = manifest,
            cache = frameCache,
            onSnapshot = petView::showSnapshot,
        )
        animation.setTargetHeight(assetHeight(size))
        attachTouch(container, animation)

        return runCatching {
            windowManager.addView(container, layout)
            root = container
            params = layout
            badge = unread
            frameView = petView
            cache = frameCache
            player = animation
            animation.start()
            persistPosition()
            true
        }.getOrElse {
            animation.stop()
            frameCache.clear()
            root = null
            params = null
            badge = null
            frameView = null
            cache = null
            player = null
            false
        }
    }

    fun setVisible(visible: Boolean) {
        root?.visibility = if (visible) View.VISIBLE else View.GONE
        player?.setPaused(!visible)
        if (!visible) closeOptions()
    }

    fun setUnread(count: Int) {
        val safe = count.coerceAtLeast(0)
        badge?.apply {
            visibility = if (safe == 0) View.GONE else View.VISIBLE
            text = if (safe > 99) "99+" else safe.toString()
        }
    }

    fun resize(size: String) {
        val normalized = normalizedSize(size)
        prefs.edit().putString(KEY_PET_SIZE, normalized).apply()
        val layout = params ?: return
        val view = root ?: return
        val oldCenterX = layout.x + layout.width / 2
        val oldBottom = layout.y + layout.height
        val next = dp(windowDp(normalized))
        layout.width = next
        layout.height = next
        layout.x = oldCenterX - next / 2
        layout.y = oldBottom - next
        clamp(layout)
        player?.setTargetHeight(assetHeight(normalized))
        runCatching { windowManager.updateViewLayout(view, layout) }
        persistPosition()
        if (optionsRoot != null) repositionOptions()
    }

    fun onConfigurationChanged() {
        val layout = params ?: return
        val view = root ?: return
        clamp(layout)
        runCatching { windowManager.updateViewLayout(view, layout) }
        persistPosition()
        if (optionsRoot != null) repositionOptions()
    }

    fun release(removeRoot: Boolean) {
        handler.removeCallbacks(longPress)
        handler.removeCallbacks(physicsTick)
        pendingSingleTap?.let(handler::removeCallbacks)
        pendingSingleTap = null
        physics.cancel()
        closeOptions()
        player?.stop()
        cache?.clear()
        if (removeRoot) root?.let { runCatching { windowManager.removeViewImmediate(it) } }
        root = null
        params = null
        badge = null
        frameView = null
        player = null
        cache = null
    }

    private fun attachTouch(view: View, animation: PetAnimationPlayer) {
        view.setOnTouchListener { _, event ->
            val layout = params ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    onTouchActivity("pet_down")
                    physics.cancel()
                    handler.removeCallbacks(physicsTick)
                    closeOptions()
                    pressRawX = event.rawX
                    pressRawY = event.rawY
                    val now = SystemClock.uptimeMillis()
                    doubleTapCandidate = lastTapAtMs > 0L &&
                        now - lastTapAtMs <= ViewConfiguration.getDoubleTapTimeout() &&
                        hypot(event.rawX - lastTapRawX, event.rawY - lastTapRawY) <= dp(28)
                    if (doubleTapCandidate) {
                        pendingSingleTap?.let(handler::removeCallbacks)
                        pendingSingleTap = null
                    }
                    startWindowX = layout.x
                    startWindowY = layout.y
                    dragging = false
                    longPressHandled = false
                    pressedRegion = PetTouchRegions.classify(event.x, event.y, view.width, view.height)
                    samples.clear()
                    addSample(event.rawX, event.rawY)
                    if (pressedRegion in setOf("head", "face")) {
                        handler.postDelayed(longPress, LONG_PRESS_MS)
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    onTouchActivity("pet_move")
                    val dx = event.rawX - pressRawX
                    val dy = event.rawY - pressRawY
                    addSample(event.rawX, event.rawY)
                    if (!dragging && abs(dx) + abs(dy) > dp(6)) {
                        dragging = true
                        if (doubleTapCandidate) lastTapAtMs = 0L
                        doubleTapCandidate = false
                        handler.removeCallbacks(longPress)
                        pendingSingleTap?.let(handler::removeCallbacks)
                        pendingSingleTap = null
                        animation.play(
                            "DRAGGING",
                            reason = "pet_overlay_drag_start",
                            force = true,
                            immediate = true,
                        )
                    }
                    if (dragging) {
                        layout.x = startWindowX + dx.toInt()
                        layout.y = startWindowY + dy.toInt()
                        clamp(layout)
                        if (abs(dx) > dp(10)) animation.setDirection(if (dx < 0f) "left" else "right")
                        runCatching { windowManager.updateViewLayout(view, layout) }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    onTouchActivity("pet_up")
                    handler.removeCallbacks(longPress)
                    addSample(event.rawX, event.rawY)
                    if (dragging) {
                        val velocity = releaseVelocity()
                        dragging = false
                        animation.play(
                            "FALLING",
                            reason = "pet_overlay_release",
                            force = true,
                            immediate = true,
                        )
                        physics.launch(
                            layout.x.toFloat(),
                            layout.y.toFloat(),
                            velocity.first,
                            velocity.second,
                        )
                        physicsLastAtMs = 0L
                        handler.post(physicsTick)
                    } else if (doubleTapCandidate && !longPressHandled) {
                        lastTapAtMs = 0L
                        doubleTapCandidate = false
                        showOptions()
                    } else if (!longPressHandled) {
                        scheduleTap(event.rawX, event.rawY, pressedRegion)
                    }
                    samples.clear()
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    onTouchActivity("pet_cancel")
                    handler.removeCallbacks(longPress)
                    dragging = false
                    doubleTapCandidate = false
                    samples.clear()
                    clamp(layout)
                    runCatching { windowManager.updateViewLayout(view, layout) }
                    persistPosition()
                    animation.resetToIdle("pet_overlay_cancel")
                    true
                }
                else -> false
            }
        }
    }

    private fun scheduleTap(rawX: Float, rawY: Float, region: String) {
        val now = SystemClock.uptimeMillis()
        val closeToPrevious = hypot(rawX - lastTapRawX, rawY - lastTapRawY) <= dp(28)
        if (lastTapAtMs > 0L &&
            now - lastTapAtMs <= ViewConfiguration.getDoubleTapTimeout() &&
            closeToPrevious
        ) {
            pendingSingleTap?.let(handler::removeCallbacks)
            pendingSingleTap = null
            lastTapAtMs = 0L
            showOptions()
            return
        }
        lastTapAtMs = now
        lastTapRawX = rawX
        lastTapRawY = rawY
        val task = Runnable {
            if (lastTapAtMs != now) return@Runnable
            lastTapAtMs = 0L
            reactToSingleTap(region)
        }
        pendingSingleTap = task
        handler.postDelayed(task, ViewConfiguration.getDoubleTapTimeout().toLong())
    }

    private fun reactToSingleTap(region: String) {
        val animation = player ?: return
        if (region == "head") {
            animation.play("HEAD_PAT", reason = "pet_overlay_head_pat", force = true)
            return
        }
        val now = SystemClock.uptimeMillis()
        while (recentPokes.isNotEmpty() && now - recentPokes.first() > REPEATED_POKE_WINDOW_MS) {
            recentPokes.removeFirst()
        }
        recentPokes.addLast(now)
        if (recentPokes.size >= 3) {
            animation.play("ANGRY", reason = "pet_overlay_repeated_poke", force = true)
            recentPokes.clear()
        } else if (region == "tail") {
            animation.play("TAIL_REACT", reason = "pet_overlay_tail_touch", force = true)
        } else {
            animation.play("POKE_REACT", reason = "pet_overlay_poke_$region", force = true)
        }
    }

    private fun showOptions() {
        if (optionsRoot != null) {
            closeOptions()
            return
        }
        val panel = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = rounded(Color.rgb(38, 35, 44), 16f)
            elevation = dp(10).toFloat()
            addView(TextView(context).apply {
                text = "桌宠选项"
                textSize = 13f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(30)))
            addView(optionButton("打开聊天") {
                closeOptions()
                onOpenChat()
            })
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                listOf(
                    PET_SIZE_SMALL to "小",
                    PET_SIZE_MEDIUM to "中",
                    PET_SIZE_LARGE to "大",
                ).forEach { (value, label) ->
                    addView(optionButton(label) { resize(value) }, LinearLayout.LayoutParams(0, dp(42), 1f))
                }
            })
            addView(optionButton("切换为悬浮球") {
                closeOptions()
                onSwitchToBubble()
            })
            addView(optionButton("关闭菜单") { closeOptions() })
        }
        val layout = WindowManager.LayoutParams(
            dp(190),
            dp(190),
            overlayWindowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        optionsRoot = panel
        optionsParams = layout
        repositionOptions()
        runCatching { windowManager.addView(panel, layout) }.onFailure {
            optionsRoot = null
            optionsParams = null
        }
    }

    private fun repositionOptions() {
        val panel = optionsRoot ?: return
        val menu = optionsParams ?: return
        val pet = params ?: return
        val safe = safeArea()
        menu.x = if (pet.x + pet.width + menu.width <= safe.right) {
            pet.x + pet.width
        } else {
            (pet.x - menu.width).coerceAtLeast(safe.left)
        }
        menu.y = pet.y.coerceIn(safe.top, (safe.bottom - menu.height).coerceAtLeast(safe.top))
        if (panel.isAttachedToWindow) runCatching { windowManager.updateViewLayout(panel, menu) }
    }

    private fun closeOptions() {
        optionsRoot?.let { runCatching { windowManager.removeViewImmediate(it) } }
        optionsRoot = null
        optionsParams = null
    }

    private fun optionButton(label: String, action: () -> Unit): Button = Button(context).apply {
        text = label
        textSize = 11f
        isAllCaps = false
        setOnClickListener { action() }
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(42))
    }

    private fun addSample(x: Float, y: Float) {
        samples.addLast(DragSample(SystemClock.uptimeMillis(), x, y))
        while (samples.size > 18) samples.removeFirst()
    }

    private fun releaseVelocity(): Pair<Float, Float> {
        val end = samples.lastOrNull() ?: return 0f to 0f
        val recent = samples.filter { it.atMs >= end.atMs - 160L }
        if (recent.size < 2) return 0f to 0f
        val start = recent.first()
        val seconds = (end.atMs - start.atMs) / 1000f
        if (seconds < 0.018f) return 0f to 0f
        return (end.x - start.x) / seconds to (end.y - start.y) / seconds
    }

    fun persistCurrentPosition() {
        val layout = params ?: return
        prefs.edit()
            .putInt(KEY_PET_X, layout.x)
            .putInt(KEY_PET_Y, layout.y)
            .apply()
    }

    private fun persistPosition() = persistCurrentPosition()

    private fun clamp(layout: WindowManager.LayoutParams) {
        val safe = safeArea()
        layout.x = layout.x.coerceIn(safe.left, (safe.right - layout.width).coerceAtLeast(safe.left))
        layout.y = layout.y.coerceIn(safe.top, (safe.bottom - layout.height).coerceAtLeast(safe.top))
    }

    private fun safeArea(): SafeArea {
        val margin = dp(4)
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            return SafeArea(
                bounds.left + insets.left + margin,
                bounds.top + insets.top + margin,
                (bounds.right - insets.right - margin).coerceAtLeast(bounds.left + margin),
                (bounds.bottom - insets.bottom - margin).coerceAtLeast(bounds.top + margin),
            )
        }
        @Suppress("DEPRECATION")
        val width = context.resources.displayMetrics.widthPixels
        @Suppress("DEPRECATION")
        val height = context.resources.displayMetrics.heightPixels
        return SafeArea(margin, margin, width - margin, height - margin)
    }

    private fun rounded(color: Int, radiusDp: Float): GradientDrawable = GradientDrawable().apply {
        setColor(color)
        cornerRadius = radiusDp * context.resources.displayMetrics.density
    }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    private data class DragSample(val atMs: Long, val x: Float, val y: Float)
    private data class SafeArea(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val height: Int get() = (bottom - top).coerceAtLeast(0)
    }

    companion object {
        const val PET_SIZE_SMALL = PetOverlaySizing.SMALL
        const val PET_SIZE_MEDIUM = PetOverlaySizing.MEDIUM
        const val PET_SIZE_LARGE = PetOverlaySizing.LARGE
        const val KEY_PET_SIZE = "pet_size"
        private const val KEY_PET_X = "pet_x"
        private const val KEY_PET_Y = "pet_y"
        private const val LONG_PRESS_MS = 620L
        private const val REPEATED_POKE_WINDOW_MS = 5_000L

        fun normalizedSize(value: String?): String = PetOverlaySizing.normalized(value)

        fun windowDp(size: String): Int = PetOverlaySizing.windowDp(size)

        fun assetHeight(size: String): Int = PetOverlaySizing.assetHeight(size)
    }
}
