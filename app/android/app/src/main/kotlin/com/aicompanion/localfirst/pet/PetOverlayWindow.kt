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
import android.widget.ScrollView
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
    private var optionsRoot: View? = null
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
    private var pendingLightLanding: Runnable? = null
    private var physicsLastAtMs = 0L
    private var gravityResumePending = false
    private var lastMotionArea: SafeArea? = null
    private var conversationCue = PetConversationPolicy.IDLE

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
            val safe = activeArea(layout)
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
                if (motionMode() == PetMotionPolicy.EDGE) {
                    setDockedEdge(EDGE_BOTTOM)
                } else {
                    setDockedEdge("")
                }
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
        val size = normalizedSize(prefs.getString(KEY_PET_SIZE, PET_SIZE_MEDIUM))
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
                setMargins(
                    0,
                    dp(windowDp(size) * 8 / 100),
                    dp(windowDp(size) * 21 / 100),
                    0,
                )
            },
        )

        val windowPx = dp(windowDp(size))
        val safe = menuSafeArea()
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
            onActionChanged = { action, phase ->
                if (action.id == "IDLE" && phase == PetAnimationPhase.BODY) {
                    handler.post { reconcileConversationAction("idle_resumed") }
                }
            },
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
            lastMotionArea = activeArea(layout)
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
        if (!visible) {
            closeOptions(resumeMotion = false)
        } else {
            reconcileConversationAction("pet_visible")
            resumeFallIfPending()
        }
    }

    /** Re-adds the pet after the chat window so same-type overlays keep the pet on top. */
    fun bringToFront(): Boolean {
        val view = root ?: return false
        val layout = params ?: return false
        if (!view.isAttachedToWindow) return false
        return runCatching {
            windowManager.removeViewImmediate(view)
            windowManager.addView(view, layout)
            true
        }.getOrElse { false }
    }

    fun setConversationCue(value: String) {
        val normalized = when (value) {
            PetConversationPolicy.THINKING -> PetConversationPolicy.THINKING
            PetConversationPolicy.TALKING -> PetConversationPolicy.TALKING
            else -> PetConversationPolicy.IDLE
        }
        if (conversationCue == normalized) return
        conversationCue = normalized
        reconcileConversationAction("conversation_$normalized")
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
        badge?.let { unread ->
            (unread.layoutParams as? FrameLayout.LayoutParams)?.let { badgeLayout ->
                badgeLayout.setMargins(
                    0,
                    dp(windowDp(normalized) * 8 / 100),
                    dp(windowDp(normalized) * 21 / 100),
                    0,
                )
                unread.layoutParams = badgeLayout
            }
        }
        runCatching { windowManager.updateViewLayout(view, layout) }
        persistPosition()
        if (optionsRoot != null) repositionOptions()
    }

    fun onConfigurationChanged() {
        val layout = params ?: return
        val view = root ?: return
        val old = lastMotionArea
        val oldLimits = old?.limits(layout)
        val oldFractionX = oldLimits?.fractionX(layout.x) ?: 0.5f
        val oldFractionY = oldLimits?.fractionY(layout.y) ?: 0.5f
        val edge = dockedEdge()
        val next = activeArea(layout)
        val nextLimits = next.limits(layout)
        layout.x = nextLimits.xAt(oldFractionX)
        layout.y = nextLimits.yAt(oldFractionY)
        if (motionMode() == PetMotionPolicy.EDGE) {
            when (edge) {
                EDGE_LEFT -> layout.x = nextLimits.minX
                EDGE_RIGHT -> layout.x = nextLimits.maxX
                EDGE_TOP -> layout.y = nextLimits.minY
                EDGE_BOTTOM -> layout.y = nextLimits.maxY
            }
        }
        clamp(layout)
        lastMotionArea = next
        runCatching { windowManager.updateViewLayout(view, layout) }
        persistPosition()
        if (optionsRoot != null) repositionOptions()
    }

    fun release(removeRoot: Boolean) {
        handler.removeCallbacks(longPress)
        handler.removeCallbacks(physicsTick)
        pendingSingleTap?.let(handler::removeCallbacks)
        pendingSingleTap = null
        pendingLightLanding?.let(handler::removeCallbacks)
        pendingLightLanding = null
        physics.cancel()
        closeOptions(resumeMotion = false)
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
                    pendingLightLanding?.let(handler::removeCallbacks)
                    pendingLightLanding = null
                    gravityResumePending = gravityResumePending || physics.active
                    physics.cancel()
                    handler.removeCallbacks(physicsTick)
                    closeOptions(resumeMotion = false)
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
                        gravityResumePending = false
                        setDockedEdge("")
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
                        val release = releaseGesture()
                        dragging = false
                        gravityResumePending = false
                        handleDragRelease(layout, animation, release)
                    } else if (doubleTapCandidate && !longPressHandled) {
                        lastTapAtMs = 0L
                        doubleTapCandidate = false
                        showOptions()
                    } else if (!longPressHandled) {
                        scheduleTap(event.rawX, event.rawY, pressedRegion)
                    } else {
                        resumeFallIfPending(delayMs = 420L)
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
                    resumeFallIfPending()
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
            resumeFallIfPending(delayMs = 420L)
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
        resumeFallIfPending(delayMs = 420L)
    }

    private fun showOptions() {
        if (optionsRoot != null) {
            closeOptions(resumeMotion = true)
            return
        }
        val currentMode = motionMode()
        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            addView(menuHeader("桌宠选项") { closeOptions(resumeMotion = true) })
            addView(optionButton("打开聊天") {
                closeOptions(resumeMotion = false)
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
                closeOptions(resumeMotion = false)
                onSwitchToBubble()
            })
            addView(sectionLabel("行动模式"))
            addView(optionButton(selectedLabel("自由模式", currentMode == PetMotionPolicy.FREE)) {
                setMotionMode(PetMotionPolicy.FREE)
                closeOptions(resumeMotion = false)
            })
            addView(optionButton(selectedLabel("贴边模式", currentMode == PetMotionPolicy.EDGE)) {
                setMotionMode(PetMotionPolicy.EDGE)
                closeOptions(resumeMotion = false)
            })
            addView(sectionLabel("半屏模式"))
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                listOf(
                    PetMotionPolicy.HALF_TOP to "上",
                    PetMotionPolicy.HALF_BOTTOM to "下",
                    PetMotionPolicy.HALF_LEFT to "左",
                    PetMotionPolicy.HALF_RIGHT to "右",
                ).forEach { (value, label) ->
                    addView(
                        optionButton(selectedLabel(label, currentMode == value)) {
                            setMotionMode(value)
                            closeOptions(resumeMotion = false)
                        },
                        LinearLayout.LayoutParams(0, dp(42), 1f),
                    )
                }
            })
        }
        val panel = ScrollView(context).apply {
            isFillViewport = false
            clipToOutline = true
            clipChildren = true
            background = rounded(Color.rgb(38, 35, 44), 16f)
            elevation = dp(10).toFloat()
            addView(
                content,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                ),
            )
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
            resumeFallIfPending()
        }
    }

    private fun repositionOptions() {
        val panel = optionsRoot ?: return
        val menu = optionsParams ?: return
        val pet = params ?: return
        val safe = menuSafeArea()
        menu.x = if (pet.x + pet.width + menu.width <= safe.right) {
            pet.x + pet.width
        } else {
            (pet.x - menu.width).coerceAtLeast(safe.left)
        }
        menu.y = pet.y.coerceIn(safe.top, (safe.bottom - menu.height).coerceAtLeast(safe.top))
        if (panel.isAttachedToWindow) runCatching { windowManager.updateViewLayout(panel, menu) }
    }

    private fun closeOptions(resumeMotion: Boolean = false) {
        optionsRoot?.let { runCatching { windowManager.removeViewImmediate(it) } }
        optionsRoot = null
        optionsParams = null
        if (resumeMotion) resumeFallIfPending()
    }

    private fun menuHeader(title: String, action: () -> Unit): LinearLayout =
        LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(TextView(context).apply {
                text = title
                textSize = 13f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
            }, LinearLayout.LayoutParams(0, dp(34), 1f))
            addView(TextView(context).apply {
                text = "×"
                textSize = 19f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
                background = rounded(Color.rgb(82, 77, 91), 999f)
                setOnClickListener { action() }
            }, LinearLayout.LayoutParams(dp(30), dp(30)))
        }

    private fun sectionLabel(label: String): TextView = TextView(context).apply {
        text = label
        textSize = 10f
        gravity = Gravity.CENTER_VERTICAL
        setTextColor(Color.rgb(207, 198, 220))
        setPadding(dp(4), 0, 0, 0)
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(25))
    }

    private fun selectedLabel(label: String, selected: Boolean): String =
        if (selected) "✓ $label" else label

    private fun resumeFallIfPending(delayMs: Long = 0L) {
        if (!gravityResumePending) return
        val task = Runnable {
            if (!gravityResumePending || root?.visibility != View.VISIBLE) return@Runnable
            val layout = params ?: return@Runnable
            gravityResumePending = false
            player?.play(
                "FALLING",
                reason = "pet_overlay_resume_fall",
                force = true,
                immediate = true,
            )
            physics.launch(layout.x.toFloat(), layout.y.toFloat(), 0f, 0f)
            physicsLastAtMs = 0L
            handler.post(physicsTick)
        }
        if (delayMs > 0L) handler.postDelayed(task, delayMs) else handler.post(task)
    }

    private fun dockToNearestEdge() {
        val layout = params ?: return
        val view = root ?: return
        val limits = activeArea(layout).limits(layout)
        val distances = listOf(
            EDGE_LEFT to abs(layout.x - limits.minX),
            EDGE_RIGHT to abs(limits.maxX - layout.x),
            EDGE_TOP to abs(layout.y - limits.minY),
            EDGE_BOTTOM to abs(limits.maxY - layout.y),
        )
        val edge = distances.minByOrNull { it.second }?.first ?: EDGE_BOTTOM
        when (edge) {
            EDGE_LEFT -> layout.x = limits.minX
            EDGE_RIGHT -> layout.x = limits.maxX
            EDGE_TOP -> layout.y = limits.minY
            else -> layout.y = limits.maxY
        }
        setDockedEdge(edge)
        clamp(layout)
        runCatching { windowManager.updateViewLayout(view, layout) }
        persistPosition()
        playLightLanding("pet_overlay_edge_dock")
    }

    private fun setMotionMode(value: String) {
        val normalized = PetMotionPolicy.normalized(value)
        prefs.edit().putString(KEY_PET_MOTION_MODE, normalized).apply()
        pendingLightLanding?.let(handler::removeCallbacks)
        pendingLightLanding = null
        gravityResumePending = false
        physics.cancel()
        handler.removeCallbacks(physicsTick)
        if (normalized == PetMotionPolicy.EDGE) {
            dockToNearestEdge()
            return
        }
        setDockedEdge("")
        val layout = params ?: return
        val view = root ?: return
        val oldX = layout.x
        val oldY = layout.y
        clamp(layout)
        runCatching { windowManager.updateViewLayout(view, layout) }
        persistPosition()
        if (layout.x != oldX || layout.y != oldY) {
            playLightLanding("pet_overlay_mode_clamp")
        }
    }

    private fun motionMode(): String = PetMotionPolicy.normalized(
        prefs.getString(KEY_PET_MOTION_MODE, PetMotionPolicy.FREE),
    )

    private fun setDockedEdge(value: String) {
        prefs.edit().putString(KEY_PET_DOCK_EDGE, value).apply()
    }

    private fun dockedEdge(): String = prefs.getString(KEY_PET_DOCK_EDGE, "").orEmpty()

    private fun handleDragRelease(
        layout: WindowManager.LayoutParams,
        animation: PetAnimationPlayer,
        release: ReleaseGesture,
    ) {
        val mode = motionMode()
        if (!release.isThrow && mode == PetMotionPolicy.EDGE && isNearAnyEdge(layout)) {
            dockToNearestEdge()
            return
        }
        if (!release.isThrow && mode != PetMotionPolicy.EDGE) {
            setDockedEdge("")
            persistPosition()
            playLightLanding("pet_overlay_light_place")
            return
        }
        setDockedEdge("")
        animation.play(
            "FALLING",
            reason = if (release.isThrow) "pet_overlay_throw" else "pet_overlay_edge_drop",
            force = true,
            immediate = true,
        )
        physics.launch(
            layout.x.toFloat(),
            layout.y.toFloat(),
            if (release.isThrow) release.velocityX else 0f,
            if (release.isThrow) release.velocityY else 0f,
        )
        physicsLastAtMs = 0L
        handler.post(physicsTick)
    }

    private fun isNearAnyEdge(layout: WindowManager.LayoutParams): Boolean {
        val limits = activeArea(layout).limits(layout)
        val threshold = maxOf(
            dp(EDGE_CAPTURE_DP),
            (minOf(layout.width, layout.height) * 0.10f).toInt(),
        )
        return minOf(
            abs(layout.x - limits.minX),
            abs(limits.maxX - layout.x),
            abs(layout.y - limits.minY),
            abs(limits.maxY - layout.y),
        ) <= threshold
    }

    private fun playLightLanding(reason: String) {
        pendingLightLanding?.let(handler::removeCallbacks)
        player?.play("FALLING", reason = reason, force = true, immediate = true)
        val task = Runnable {
            pendingLightLanding = null
            player?.play("LANDING", reason = "${reason}_landing", force = true, immediate = true)
        }
        pendingLightLanding = task
        handler.postDelayed(task, LIGHT_LANDING_DELAY_MS)
    }

    private fun reconcileConversationAction(reason: String) {
        if (root?.visibility != View.VISIBLE || dragging || physics.active) return
        val animation = player ?: return
        val current = animation.currentActionId
        val desired = PetConversationPolicy.actionFor(conversationCue)
        if (desired == null) {
            if (current in CONVERSATION_ACTIONS) {
                animation.resetToIdle("${reason}_idle")
            }
            return
        }
        if (current == desired) return
        if (current == "IDLE" || current in CONVERSATION_ACTIONS) {
            animation.play(
                desired,
                reason = reason,
                force = true,
                immediate = false,
            )
        }
    }

    private fun optionButton(label: String, action: () -> Unit): Button = Button(context).apply {
        text = label
        textSize = 11f
        isAllCaps = false
        minWidth = 0
        minHeight = 0
        setPadding(dp(4), 0, dp(4), 0)
        setOnClickListener { action() }
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(42))
    }

    private fun addSample(x: Float, y: Float) {
        samples.addLast(DragSample(SystemClock.uptimeMillis(), x, y))
        while (samples.size > 18) samples.removeFirst()
    }

    private fun releaseGesture(): ReleaseGesture {
        val end = samples.lastOrNull() ?: return ReleaseGesture(0f, 0f, false)
        val recent = samples.filter { it.atMs >= end.atMs - 160L }
        if (recent.size < 2) return ReleaseGesture(0f, 0f, false)
        val start = recent.first()
        val seconds = (end.atMs - start.atMs) / 1000f
        if (seconds < 0.018f) return ReleaseGesture(0f, 0f, false)
        val density = context.resources.displayMetrics.density.coerceAtLeast(0.1f)
        val velocityX = (end.x - start.x) / seconds
        val velocityY = (end.y - start.y) / seconds
        val speedDpPerSecond = hypot(velocityX, velocityY) / density
        var recentTravelPx = 0f
        for (index in 1 until recent.size) {
            recentTravelPx += hypot(
                recent[index].x - recent[index - 1].x,
                recent[index].y - recent[index - 1].y,
            )
        }
        val tail = samples.filter { it.atMs >= end.atMs - RELEASE_STABLE_TAIL_MS }
        val stableRadius = dp(RELEASE_STABLE_RADIUS_DP).toFloat()
        val tailStable = tail.all { hypot(it.x - end.x, it.y - end.y) <= stableRadius }
        val totalDisplacementDp = hypot(end.x - pressRawX, end.y - pressRawY) / density
        return ReleaseGesture(
            velocityX = velocityX,
            velocityY = velocityY,
            isThrow = PetMotionPolicy.shouldThrow(
                speedDpPerSecond = speedDpPerSecond,
                recentTravelDp = recentTravelPx / density,
                totalDisplacementDp = totalDisplacementDp,
                tailStable = tailStable,
            ),
        )
    }

    fun persistCurrentPosition() {
        val layout = params ?: return
        prefs.edit()
            .putInt(KEY_PET_X, layout.x)
            .putInt(KEY_PET_Y, layout.y)
            .apply()
        lastMotionArea = activeArea(layout)
    }

    private fun persistPosition() = persistCurrentPosition()

    private fun clamp(layout: WindowManager.LayoutParams) {
        val safe = activeArea(layout)
        layout.x = layout.x.coerceIn(safe.left, (safe.right - layout.width).coerceAtLeast(safe.left))
        layout.y = layout.y.coerceIn(safe.top, (safe.bottom - layout.height).coerceAtLeast(safe.top))
    }

    private fun activeArea(layout: WindowManager.LayoutParams): SafeArea {
        val full = motionArea(layout)
        val center = screenCenter()
        return when (motionMode()) {
            PetMotionPolicy.HALF_TOP -> full.copy(bottom = center.second.coerceAtLeast(full.top))
            PetMotionPolicy.HALF_BOTTOM -> full.copy(top = center.second.coerceAtMost(full.bottom))
            PetMotionPolicy.HALF_LEFT -> full.copy(right = center.first.coerceAtLeast(full.left))
            PetMotionPolicy.HALF_RIGHT -> full.copy(left = center.first.coerceAtMost(full.right))
            else -> full
        }
    }

    private fun motionArea(layout: WindowManager.LayoutParams): SafeArea {
        val overscan = (minOf(layout.width, layout.height) * EDGE_OVERSCAN_RATIO).toInt()
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            val landscape = bounds.width() > bounds.height()
            val horizontalShift = if (landscape) insets.left else 0
            val bottom = if (landscape) {
                bounds.bottom
            } else {
                (bounds.bottom - insets.bottom - dp(PORTRAIT_BOTTOM_MARGIN_DP))
                    .coerceAtLeast(bounds.top)
            }
            return SafeArea(
                bounds.left - overscan - horizontalShift,
                bounds.top - overscan,
                bounds.right + overscan - horizontalShift,
                bottom,
            )
        }
        @Suppress("DEPRECATION")
        val width = context.resources.displayMetrics.widthPixels
        @Suppress("DEPRECATION")
        val height = context.resources.displayMetrics.heightPixels
        val landscape = width > height
        val bottom = if (landscape) height else height - dp(PORTRAIT_BOTTOM_MARGIN_DP)
        return SafeArea(-overscan, -overscan, width + overscan, bottom)
    }

    private fun screenCenter(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = windowManager.currentWindowMetrics
            val bounds = metrics.bounds
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            val horizontalShift = if (bounds.width() > bounds.height()) insets.left else 0
            return (bounds.centerX() - horizontalShift) to bounds.centerY()
        }
        @Suppress("DEPRECATION")
        val width = context.resources.displayMetrics.widthPixels
        @Suppress("DEPRECATION")
        val height = context.resources.displayMetrics.heightPixels
        return width / 2 to height / 2
    }

    private fun menuSafeArea(): SafeArea {
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
    private data class ReleaseGesture(
        val velocityX: Float,
        val velocityY: Float,
        val isThrow: Boolean,
    )

    private data class SafeAreaLimits(
        val minX: Int,
        val maxX: Int,
        val minY: Int,
        val maxY: Int,
    ) {
        fun fractionX(x: Int): Float = fraction(x, minX, maxX)
        fun fractionY(y: Int): Float = fraction(y, minY, maxY)
        fun xAt(fraction: Float): Int = position(fraction, minX, maxX)
        fun yAt(fraction: Float): Int = position(fraction, minY, maxY)

        private fun fraction(value: Int, minimum: Int, maximum: Int): Float {
            val span = maximum - minimum
            if (span <= 0) return 0f
            return ((value - minimum).toFloat() / span).coerceIn(0f, 1f)
        }

        private fun position(fraction: Float, minimum: Int, maximum: Int): Int =
            (minimum + (maximum - minimum) * fraction.coerceIn(0f, 1f)).toInt()
    }

    private data class SafeArea(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width: Int get() = (right - left).coerceAtLeast(0)
        val height: Int get() = (bottom - top).coerceAtLeast(0)

        fun limits(layout: WindowManager.LayoutParams): SafeAreaLimits = SafeAreaLimits(
            minX = left,
            maxX = (right - layout.width).coerceAtLeast(left),
            minY = top,
            maxY = (bottom - layout.height).coerceAtLeast(top),
        )
    }

    companion object {
        const val PET_SIZE_SMALL = PetOverlaySizing.SMALL
        const val PET_SIZE_MEDIUM = PetOverlaySizing.MEDIUM
        const val PET_SIZE_LARGE = PetOverlaySizing.LARGE
        const val KEY_PET_SIZE = "pet_size"
        private const val KEY_PET_X = "pet_x"
        private const val KEY_PET_Y = "pet_y"
        private const val KEY_PET_MOTION_MODE = "pet_motion_mode"
        private const val KEY_PET_DOCK_EDGE = "pet_dock_edge"
        private const val EDGE_LEFT = "left"
        private const val EDGE_RIGHT = "right"
        private const val EDGE_TOP = "top"
        private const val EDGE_BOTTOM = "bottom"
        private const val EDGE_CAPTURE_DP = 28
        private const val LIGHT_LANDING_DELAY_MS = 180L
        private const val RELEASE_STABLE_TAIL_MS = 90L
        private const val RELEASE_STABLE_RADIUS_DP = 8
        private const val PORTRAIT_BOTTOM_MARGIN_DP = 16
        private const val LONG_PRESS_MS = 620L
        private const val REPEATED_POKE_WINDOW_MS = 5_000L
        private const val EDGE_OVERSCAN_RATIO = 0.06f
        private val CONVERSATION_ACTIONS = setOf("THINKING", "TALKING")

        fun normalizedSize(value: String?): String = PetOverlaySizing.normalized(value)

        fun windowDp(size: String): Int = PetOverlaySizing.windowDp(size)

        fun assetHeight(size: String): Int = PetOverlaySizing.assetHeight(size)
    }
}
