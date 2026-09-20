package com.catkiss.senlive2dcompanion

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import com.aicompanion.localfirst.RuntimeDiagnosticStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.lang.ref.WeakReference
import java.util.UUID
import kotlin.math.hypot
import kotlin.math.max

class SenLive2DPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        SenLive2DPlatformView(context, messenger, viewId, args as? Map<*, *>)

    companion object {
        const val VIEW_TYPE = "ai_companion/sen_live2d_view"
    }
}

/** Single chat-stage owner for Sen's unchanged renderer and performance engine. */
internal class SenLive2DPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    creationArgs: Map<*, *>?,
) : PlatformView, MethodChannel.MethodCallHandler, SenCompanionView.Listener {
    private val main = Handler(Looper.getMainLooper())
    private val repository = SenModelRepository(context)
    private val root = FrameLayout(context).apply { setBackgroundColor(Color.TRANSPARENT) }
    private val companion = SenCompanionView(context)
    private val channel = MethodChannel(messenger, "$CHANNEL_PREFIX/$viewId")
    private var disposed = false
    private var outfit = creationArgs?.get("outfit")?.toString().orEmpty().ifBlank { SenOutfitCatalog.MAID }
    private var glasses = creationArgs?.get("glasses") == true
    private var emotion = creationArgs?.get("emotion")?.toString().orEmpty().ifBlank { "normal" }
    private var pointerId = -1
    private var headPatCandidate = false
    private var headPatTriggered = false
    private var headPatLastX = 0f
    private var headPatLastY = 0f
    private var headPatTravel = 0f
    private var headPatStartedAt = 0L
    private val modelPoint = FloatArray(2)
    private val executionId = UUID.randomUUID().toString()

    init {
        channel.setMethodCallHandler(this)
        companion.setListener(this)
        companion.setTouchFollowEnabled(true)
        companion.setOnTouchListener(::handleStageInteraction)
        root.addView(companion, FrameLayout.LayoutParams(-1, -1))
        SenLive2DRuntime.attach(this)
        diagnostic("created", trigger = "flutter_platform_view")
        loadCurrentModel()
        companion.onHostResume()
    }

    override fun getView(): View = root

    override fun dispose() {
        if (disposed) return
        disposed = true
        diagnostic("released", terminal = true)
        SenLive2DRuntime.detach(this)
        channel.setMethodCallHandler(null)
        companion.setListener(null)
        companion.onHostPause()
        companion.release()
        root.removeAllViews()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("sen_view_disposed", "Sen Live2D view has been disposed", null)
            return
        }
        when (call.method) {
            "setEmotion" -> {
                emotion = call.argument<String>("emotion").orEmpty().ifBlank { "normal" }
                companion.setEmotion(emotion)
                result.success(null)
            }
            "playAction" -> {
                companion.playAction(call.argument<String>("action").orEmpty())
                result.success(null)
            }
            "setOutfit" -> {
                outfit = call.argument<String>("outfit").orEmpty().ifBlank { SenOutfitCatalog.MAID }
                companion.setOutfit(outfit)
                result.success(null)
            }
            "setGlasses" -> {
                glasses = call.argument<Boolean>("enabled") == true
                companion.setGlassesEnabled(glasses)
                result.success(null)
            }
            "setAutoIdle" -> {
                companion.setAutoIdle(call.argument<Boolean>("enabled") != false)
                result.success(null)
            }
            "setSpeechAmplitude" -> {
                companion.setSpeechAmplitude((call.argument<Number>("amplitude")?.toFloat() ?: 0f))
                result.success(null)
            }
            "listen" -> {
                companion.playAction("small_nod")
                result.success(null)
            }
            "reloadModel" -> {
                loadCurrentModel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun setSpeechAmplitude(value: Float) {
        if (!disposed) companion.setSpeechAmplitude(value.coerceIn(0f, 1f))
    }

    fun reloadModel() {
        if (!disposed) main.post(::loadCurrentModel)
    }

    fun hostResume() {
        if (!disposed) companion.onHostResume()
    }

    fun hostPause() {
        if (!disposed) companion.onHostPause()
    }

    private fun loadCurrentModel() {
        val info = repository.currentModel()
        if (!info.available || info.modelFile == null) {
            emit("onModelMissing", mapOf("detail" to info.detail))
            return
        }
        companion.loadModel(info.modelFile, info.expressions, true, outfit)
        companion.setGlassesEnabled(glasses)
        companion.setEmotion(emotion)
    }

    private fun handleStageInteraction(view: View, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                pointerId = event.getPointerId(0)
                headPatLastX = event.x
                headPatLastY = event.y
                headPatTravel = 0f
                headPatStartedAt = SystemClock.elapsedRealtime()
                headPatTriggered = false
                headPatCandidate = screenToModelPoint(view, headPatLastX, headPatLastY) &&
                    isInHeadZone(modelPoint[0], modelPoint[1], 0f)
                queueTouchTarget(view, true, headPatLastX, headPatLastY)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (pointerId < 0) return false
                var index = event.findPointerIndex(pointerId)
                if (index < 0) index = 0
                val x = event.getX(index)
                val y = event.getY(index)
                queueTouchTarget(view, true, x, y)
                headPatTravel += hypot(x - headPatLastX, y - headPatLastY)
                headPatLastX = x
                headPatLastY = y
                if (!screenToModelPoint(view, x, y) || !isInHeadZone(modelPoint[0], modelPoint[1], .08f)) {
                    headPatCandidate = false
                }
                val duration = SystemClock.elapsedRealtime() - headPatStartedAt
                val threshold = max(dp(view, 34f), view.width * .075f)
                if (headPatCandidate && !headPatTriggered && duration >= 120L && headPatTravel >= threshold) {
                    headPatTriggered = true
                    companion.triggerHeadPat(Math.random() < .10)
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_POINTER_UP -> {
                if (pointerId >= 0) {
                    var index = event.findPointerIndex(pointerId)
                    if (index < 0) index = 0
                    queueTouchTarget(view, false, event.getX(index), event.getY(index))
                }
                companion.releaseHeadPat()
                pointerId = -1
                headPatCandidate = false
                headPatTriggered = false
                return true
            }
        }
        return true
    }

    private fun screenToModelPoint(view: View, x: Float, y: Float): Boolean =
        companion.screenToModelNormalized(
            x / max(1, view.width),
            y / max(1, view.height),
            modelPoint,
        )

    private fun isInHeadZone(x: Float, y: Float, margin: Float): Boolean =
        x >= HEAD_LEFT - margin && x <= HEAD_RIGHT + margin &&
            y >= HEAD_TOP - margin && y <= HEAD_BOTTOM + margin

    private fun queueTouchTarget(view: View, active: Boolean, x: Float, y: Float) {
        val normalizedX = x * 2f / max(1, view.width) - 1f
        val normalizedY = 1f - y * 2f / max(1, view.height)
        companion.setLookTarget(active, normalizedX, normalizedY)
    }

    private fun dp(view: View, value: Float): Float = value * view.resources.displayMetrics.density

    override fun onStatus(status: String) = emit("onStatus", mapOf("status" to status))

    override fun onReady(detail: String) {
        main.post {
            if (!disposed) {
                repository.confirmPendingImport()
                companion.setGlassesEnabled(glasses)
                companion.setEmotion(emotion)
            }
        }
        emit("onReady", mapOf("detail" to detail))
        diagnostic("ready", trigger = "model_load")
    }

    override fun onError(error: Throwable) {
        emit("onError", mapOf("message" to (error.message ?: error.javaClass.simpleName)))
        diagnostic("error", trigger = "renderer")
        main.post {
            if (!disposed && repository.rollbackPendingImport()) loadCurrentModel()
        }
    }

    override fun onHeadAnchor(normalizedX: Float, normalizedY: Float) = emit(
        "onHeadAnchor",
        mapOf("x" to normalizedX.toDouble(), "y" to normalizedY.toDouble()),
    )

    private fun emit(method: String, arguments: Any?) {
        if (!disposed) main.post { if (!disposed) channel.invokeMethod(method, arguments) }
    }

    private fun diagnostic(
        phase: String,
        trigger: String = "view_lifecycle",
        terminal: Boolean = false,
    ) {
        RuntimeDiagnosticStore.record(
            root.context,
            category = "sen_live2d",
            phase = phase,
            metadata = mapOf(
                "feature" to "sen_live2d_stage",
                "execution_id" to executionId,
                "trigger_source" to trigger,
                "continuation_owner" to "sen_view_lifecycle",
                "planning_rounds" to 0,
                "tool_calls" to 0,
                "committed_mutations" to 0,
                "continuation_requested" to false,
                "terminal" to terminal,
                "preempt" to false,
                "late_write" to false,
                "usage_lane" to "local_presentation",
            ),
        )
    }

    companion object {
        private const val CHANNEL_PREFIX = "ai_companion/sen_live2d/view"
        private const val HEAD_LEFT = .4927f
        private const val HEAD_TOP = .0482f
        private const val HEAD_RIGHT = .7095f
        private const val HEAD_BOTTOM = .1088f
    }
}

/** Process-local owner: the chat page can create at most one Cubism instance. */
object SenLive2DRuntime {
    private var active = WeakReference<SenLive2DPlatformView>(null)

    @Synchronized
    internal fun attach(view: SenLive2DPlatformView) {
        active.get()?.takeIf { it !== view }?.dispose()
        active = WeakReference(view)
    }

    @Synchronized
    internal fun detach(view: SenLive2DPlatformView) {
        if (active.get() === view) active.clear()
    }

    fun setSpeechAmplitude(value: Float) = active.get()?.setSpeechAmplitude(value)
    fun reloadModel() = active.get()?.reloadModel()
    fun onHostResume() = active.get()?.hostResume()
    fun onHostPause() = active.get()?.hostPause()
}
