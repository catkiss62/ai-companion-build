package com.catkiss.senlive2dcompanion

import android.content.Context
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.lang.ref.WeakReference

class CaicaiPlatformViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        CaicaiPlatformView(context, messenger, viewId)

    companion object { const val VIEW_TYPE = "ai_companion/caicai_live2d_view" }
}

/** Host adapter only: all model update, accessory projection and rendering stay in Caicai. */
internal class CaicaiPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, MethodChannel.MethodCallHandler, SenCompanionView.Listener {
    private val main = Handler(Looper.getMainLooper())
    private val repository = CaicaiModelRepository(context)
    private val app = context.applicationContext
    private val root = FrameLayout(context).apply { setBackgroundColor(Color.TRANSPARENT) }
    private val companion = SenCompanionView(context)
    private val channel = MethodChannel(messenger, "ai_companion/caicai_live2d/view/$viewId")
    private var disposed = false
    @Volatile private var renderStatus = "created"
    @Volatile private var renderDetail = "等待画面连接"
    @Volatile private var awaitingModelStart = false
    @Volatile private var modelStarted = false
    private var keyboardVisible = false
    private var stageScale = 1f
    private var stageX = 0f
    private var stageY = 0f
    private var lastX = 0f
    private var lastY = 0f
    private val scaleDetector = ScaleGestureDetector(context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                stageScale = (stageScale * detector.scaleFactor).coerceIn(.35f, 6f)
                applyStage()
                return true
            }
        })

    init {
        channel.setMethodCallHandler(this)
        companion.setListener(this)
        // The standalone app's accepted front-hair connection and secondary motion.
        companion.setGeometryConstraintEnabled(true)
        companion.setFrontHairPoint(FRONT_HAIR_POINT)
        companion.setFrontHairExperimentEnabled(true)
        companion.setOnTouchListener { view, event -> handleStageTouch(view, event) }
        root.addView(companion, FrameLayout.LayoutParams(-1, -1))
        CaicaiRuntime.attach(this)
        companion.onHostResume()
    }

    override fun getView(): View = root

    override fun dispose() {
        if (disposed) return
        disposed = true
        CaicaiRuntime.detach(this)
        channel.setMethodCallHandler(null)
        companion.setListener(null)
        companion.onHostPause()
        companion.release()
        root.removeAllViews()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) return result.error("caicai_view_disposed", "Live2D view released", null)
        when (call.method) {
            "start" -> { loadCurrentModel(); result.success(state()) }
            "getState" -> result.success(state())
            "reloadModel" -> { loadCurrentModel(); result.success(null) }
            "setKeyboardVisible" -> {
                setKeyboardVisible(call.arguments == true)
                result.success(null)
            }
            "resetStage" -> {
                stageScale = 1f; stageX = 0f; stageY = 0f
                applyStage(); result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun reloadModel() { if (!disposed) main.post(::loadCurrentModel) }
    fun hostResume() { if (!disposed) companion.onHostResume() }
    fun hostPause() { if (!disposed) companion.onHostPause() }
    fun setKeyboardVisible(visible: Boolean) {
        if (!disposed && keyboardVisible != visible) {
            keyboardVisible = visible
            companion.renderMode = if (visible) GLSurfaceView.RENDERMODE_WHEN_DIRTY
                else GLSurfaceView.RENDERMODE_CONTINUOUSLY
            if (visible) companion.requestRender()
            CaicaiDiagnostics.record(app, if (visible) "keyboard_open" else "keyboard_closed")
        }
    }

    fun state(): Map<String, String> = mapOf("status" to renderStatus, "detail" to renderDetail)

    private fun loadCurrentModel() {
        if (disposed) return
        val models = repository.currentModels()
        if (!models.available) {
            renderStatus = "missing"
            renderDetail = models.detail
            CaicaiDiagnostics.record(app, "model_missing", models.detail)
            send("onModelMissing", mapOf("detail" to models.detail))
            return
        }
        renderStatus = "loading"
        renderDetail = "正在加载菜菜女仆与三配件"
        awaitingModelStart = true
        modelStarted = false
        CaicaiDiagnostics.record(app, "render_loading")
        // Match MainActivity.loadModels() of the v0.1.42 lab. Do not pass all
        // ZIP expressions as startup expressions or change its motion engine.
        companion.loadModels(
            models.maid!!, models.accessory!!, true,
            SenMotionMode.EV_FAITHFUL.id,
            SenRenderOptions.DEFAULT_EV_BODY_FOLLOW_STRENGTH,
            CompositeOutfit.MAID_WITH_SEN_ACCESSORIES.id,
        )
        // The editor may have paused continuous GL; one frame still needs to
        // consume the newly queued model request before it can report ready.
        companion.requestRender()
    }

    private fun handleStageTouch(view: View, event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> { lastX = event.x; lastY = event.y }
            MotionEvent.ACTION_MOVE -> {
                if (!scaleDetector.isInProgress && event.pointerCount == 1) {
                    stageX = (stageX + 2f * (event.x - lastX) / view.width.coerceAtLeast(1))
                        .coerceIn(-2f, 2f)
                    stageY = (stageY - 2f * (event.y - lastY) / view.height.coerceAtLeast(1))
                        .coerceIn(-2f, 2f)
                    applyStage()
                }
                lastX = event.x; lastY = event.y
            }
            MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_UP -> {
                lastX = event.getX(0); lastY = event.getY(0)
            }
        }
        return true
    }

    private fun applyStage() = companion.setStageTransform(stageScale, stageX, stageY)

    override fun onStatus(status: String) {
        if (awaitingModelStart && status.startsWith("原生渲染：准备加载菜菜女仆主模型")) {
            modelStarted = true
        }
        renderDetail = status
        CaicaiDiagnostics.record(app, "render_status", status)
        send("onStatus", mapOf("detail" to status))
    }
    override fun onReady(detail: String) {
        // A surface recreation can report the old model as ready before the
        // queued import load starts. That callback must not verify the ZIP.
        if (awaitingModelStart && !modelStarted) {
            CaicaiDiagnostics.record(app, "stale_surface_ready_ignored")
            return
        }
        val newlyLoaded = awaitingModelStart && modelStarted
        awaitingModelStart = false
        renderStatus = "ready"
        renderDetail = detail
        CaicaiDiagnostics.record(app, "render_ready", detail)
        if (newlyLoaded) main.post { if (!disposed) repository.confirmPendingImport() }
        send("onReady", mapOf("detail" to detail))
    }
    override fun onError(error: Throwable) {
        awaitingModelStart = false
        renderStatus = "error"
        renderDetail = error.message ?: error.javaClass.simpleName
        CaicaiDiagnostics.record(app, "render_error", renderDetail)
        send("onError", mapOf("detail" to renderDetail))
        main.post { if (!disposed && repository.rollbackPendingImport()) loadCurrentModel() }
    }
    override fun onMotionDiagnosticStep(label: String, index: Int, total: Int) = Unit
    override fun onMotionDiagnosticComplete(report: String) = Unit
    override fun onCompositeReport(report: String) = Unit
    override fun onMaidHairPointPicked(anchorJson: String, frontHairExperiment: Boolean) = Unit

    private fun send(name: String, payload: Any) {
        main.post { if (!disposed) channel.invokeMethod(name, payload) }
    }

    companion object {
        private const val FRONT_HAIR_POINT = "{\"drawableId\":\"ArtMesh386\"," +
            "\"triangleVertexIds\":[129,130,120]," +
            "\"barycentricWeights\":[0.010805397,0.35519314,0.6340015]}"
    }
}

/** A single native renderer owner for the chat stage. */
object CaicaiRuntime {
    private var active = WeakReference<CaicaiPlatformView>(null)

    @Synchronized internal fun attach(view: CaicaiPlatformView) {
        active.get()?.takeIf { it !== view }?.dispose()
        active = WeakReference(view)
    }
    @Synchronized internal fun detach(view: CaicaiPlatformView) {
        if (active.get() === view) active.clear()
    }
    fun reloadModel() = active.get()?.reloadModel()
    fun onHostResume() = active.get()?.hostResume()
    fun onHostPause() = active.get()?.hostPause()
    fun setKeyboardVisible(visible: Boolean) = active.get()?.setKeyboardVisible(visible)
    fun state(): Map<String, String> = active.get()?.state()
        ?: mapOf("status" to "not_open", "detail" to "请打开聊天画面验证模型")
}
