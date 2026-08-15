package com.aicompanion.localfirst.pet

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.widget.Button
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.hypot

class PetPreviewActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var player: PetAnimationPlayer? = null
    private var cache: PetFrameCache? = null
    private var frameView: PetFrameView? = null
    private var statusView: TextView? = null
    private var labels: Map<String, PetActionLabel> = emptyMap()
    private val physics = PetThrowPhysics()
    private var physicsLastAtMs = 0L
    private var paused = false

    private var pressX = 0f
    private var pressY = 0f
    private var startTranslationX = 0f
    private var startTranslationY = 0f
    private var translationX = 0f
    private var translationY = 0f
    private var dragging = false
    private val dragSamples = ArrayDeque<DragSample>()

    private val physicsTick = object : Runnable {
        override fun run() {
            val view = frameView ?: return
            if (!physics.active || paused) return
            val now = SystemClock.uptimeMillis()
            val delta = if (physicsLastAtMs == 0L) 0f else
                ((now - physicsLastAtMs).coerceIn(0L, 100L) / 1000f)
            physicsLastAtMs = now
            val step = physics.step(
                deltaSeconds = delta,
                spriteWidth = 0f,
                spriteHeight = 0f,
                bounds = PetPhysicsBounds(
                    left = -view.width * 0.45f,
                    top = -view.height * 0.70f,
                    right = view.width * 0.45f,
                    bottom = 0f,
                ),
            )
            translationX = step.x
            translationY = step.y
            view.setPetTranslation(translationX, translationY)
            if (step.settled) {
                player?.play("LANDING", reason = "preview_landing", force = true, immediate = true)
                if (step.hardLanding) player?.queueAfterCurrent("DIZZY")
                return
            }
            handler.postDelayed(this, 16L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "桌宠原项目动作预览"
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(true)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = 0
        }
        val page = ScrollView(this).apply {
            isFillViewport = false
            setBackgroundColor(Color.rgb(24, 21, 28))
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
            setBackgroundColor(Color.rgb(24, 21, 28))
        }
        val status = TextView(this).apply {
            text = "正在读取原项目动作清单…"
            textSize = 15f
            setTextColor(Color.WHITE)
        }
        statusView = status
        root.addView(
            status,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        val help = TextView(this).apply {
            text = "拖动角色可测试：抓取中 → 释放/落下 → 着陆 → 待机；动作按钮均显示原始 ID。"
            textSize = 12f
            setTextColor(Color.rgb(196, 188, 205))
            setPadding(0, dp(4), 0, dp(4))
        }
        root.addView(help)

        val petView = PetFrameView(this).apply {
            setPreviewWindowDp(PetOverlaySizing.windowDp(PetOverlaySizing.MEDIUM))
        }
        frameView = petView
        root.addView(
            petView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(320),
            ),
        )

        try {
            val manifest = PetSkinManifest.load(assets)
            labels = PetActionLabels.load(assets)
            val frameCache = PetFrameCache(assets)
            cache = frameCache
            val animationPlayer = PetAnimationPlayer(
                manifest = manifest,
                cache = frameCache,
                onSnapshot = { snapshot ->
                    petView.showSnapshot(snapshot)
                    val action = manifest.requireAction(snapshot.current.actionId)
                    val label = labels[action.id]?.name ?: action.id
                    status.text = buildString {
                        append(label)
                        append(" · ")
                        append(action.id)
                        append(" · ")
                        append(snapshot.phase.name.lowercase())
                        append(" · ")
                        append(snapshot.current.assetId)
                        append(" · ")
                        append(snapshot.selectedSize)
                        append("px · frame ")
                        append(snapshot.current.frameIndex + 1)
                    }
                },
            )
            player = animationPlayer
            petView.setOnTouchListener { _, event -> handlePetTouch(event) }
            root.addView(buildControls(manifest, animationPlayer))
            animationPlayer.start()
        } catch (error: Throwable) {
            status.text = "桌宠原始动作清单读取失败：${error.message ?: error.javaClass.simpleName}"
            status.setTextColor(Color.rgb(255, 150, 150))
        }
        page.addView(
            root,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
        setContentView(page)
    }

    private fun buildControls(
        manifest: PetSkinManifest,
        animationPlayer: PetAnimationPlayer,
    ): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        addView(LinearLayout(this@PetPreviewActivity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(compactButton("左") {
                animationPlayer.setDirection("left")
                animationPlayer.play(
                    "STROLLING",
                    reason = "preview_static_left",
                    force = true,
                    immediate = true,
                )
            })
            addView(compactButton("右") {
                animationPlayer.setDirection("right")
                animationPlayer.play(
                    "STROLLING",
                    reason = "preview_static_right",
                    force = true,
                    immediate = true,
                )
            })
            addView(compactButton("背面") {
                animationPlayer.setDirection("up")
                animationPlayer.resetToIdle("preview_back")
            })
            addView(compactButton("正面") {
                animationPlayer.setDirection("down")
                animationPlayer.resetToIdle("preview_front")
            })
            addView(compactButton("复位待机") {
                physics.cancel()
                handler.removeCallbacks(physicsTick)
                translationX = 0f
                translationY = 0f
                frameView?.resetPetTranslation()
                animationPlayer.setDirection("down")
                animationPlayer.resetToIdle()
            })
        })

        addView(LinearLayout(this@PetPreviewActivity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            listOf(
                Triple(187, PetOverlaySizing.SMALL, "小"),
                Triple(238, PetOverlaySizing.MEDIUM, "中"),
                Triple(306, PetOverlaySizing.LARGE, "大"),
            ).forEach { (assetHeight, sizeName, label) ->
                addView(compactButton("$label · ${PetOverlaySizing.windowDp(sizeName)}dp") {
                    animationPlayer.setTargetHeight(assetHeight)
                    frameView?.setPreviewWindowDp(PetOverlaySizing.windowDp(sizeName))
                })
            }
        })

        val grid = GridLayout(this@PetPreviewActivity).apply {
            columnCount = 3
            manifest.actions.keys.forEach { actionId ->
                val label = labels[actionId]
                addView(Button(this@PetPreviewActivity).apply {
                    text = "${label?.name ?: actionId}\n$actionId"
                    textSize = 10f
                    isAllCaps = false
                    setPadding(dp(3), dp(2), dp(3), dp(2))
                    setOnClickListener {
                        physics.cancel()
                        handler.removeCallbacks(physicsTick)
                        animationPlayer.play(
                            actionId,
                            reason = "panel_preview",
                            force = true,
                            immediate = true,
                        )
                        statusView?.contentDescription = label?.hint.orEmpty()
                    }
                    layoutParams = GridLayout.LayoutParams().apply {
                        width = 0
                        height = dp(54)
                        columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                        setMargins(dp(2), dp(2), dp(2), dp(2))
                    }
                })
            }
        }
        addView(
            grid,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )
    }

    private fun compactButton(text: String, onClick: () -> Unit): Button = Button(this).apply {
        this.text = text
        textSize = 10f
        isAllCaps = false
        setPadding(dp(5), 0, dp(5), 0)
        setOnClickListener { onClick() }
        layoutParams = LinearLayout.LayoutParams(0, dp(42), 1f)
    }

    private fun handlePetTouch(event: MotionEvent): Boolean {
        val now = SystemClock.uptimeMillis()
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                physics.cancel()
                handler.removeCallbacks(physicsTick)
                pressX = event.x
                pressY = event.y
                startTranslationX = translationX
                startTranslationY = translationY
                dragging = false
                dragSamples.clear()
                dragSamples.addLast(DragSample(now, event.x, event.y))
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.x - pressX
                val dy = event.y - pressY
                if (!dragging && abs(dx) + abs(dy) > dp(6).toFloat()) {
                    dragging = true
                    player?.play("DRAGGING", reason = "drag_start", force = true, immediate = true)
                }
                if (dragging) {
                    translationX = startTranslationX + dx
                    translationY = startTranslationY + dy
                    frameView?.setPetTranslation(translationX, translationY)
                    if (abs(dx) > dp(10)) player?.setDirection(if (dx < 0f) "left" else "right")
                    addDragSample(now, event.x, event.y)
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                addDragSample(now, event.x, event.y)
                if (dragging) {
                    val velocity = dragVelocity(now)
                    player?.play("FALLING", reason = "drag_release", force = true, immediate = true)
                    physics.launch(translationX, translationY, velocity.first, velocity.second)
                    physicsLastAtMs = 0L
                    if (!paused) handler.post(physicsTick)
                }
                dragging = false
                dragSamples.clear()
                return true
            }
        }
        return false
    }

    private fun addDragSample(timeMs: Long, x: Float, y: Float) {
        dragSamples.addLast(DragSample(timeMs, x, y))
        while (dragSamples.size > 18) dragSamples.removeFirst()
    }

    private fun dragVelocity(nowMs: Long): Pair<Float, Float> {
        val recent = dragSamples.filter { it.timeMs >= nowMs - 160L }
        if (recent.size < 2) return 0f to 0f
        val start = recent.first()
        val end = recent.last()
        val duration = (end.timeMs - start.timeMs) / 1000f
        if (duration < 0.018f) return 0f to 0f
        val x = (end.x - start.x) / duration
        val y = (end.y - start.y) / duration
        val speed = hypot(x, y)
        if (!speed.isFinite()) return 0f to 0f
        return x to y
    }

    override fun onPause() {
        paused = true
        player?.setPaused(true)
        handler.removeCallbacks(physicsTick)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        paused = false
        player?.setPaused(false)
        if (physics.active) {
            physicsLastAtMs = 0L
            handler.post(physicsTick)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        physics.cancel()
        player?.stop()
        cache?.clear()
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private data class DragSample(val timeMs: Long, val x: Float, val y: Float)

    companion object {
        fun launch(context: Context) {
            context.startActivity(Intent(context, PetPreviewActivity::class.java))
        }
    }
}
