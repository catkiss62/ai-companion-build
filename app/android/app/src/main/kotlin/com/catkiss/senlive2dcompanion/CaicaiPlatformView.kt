package com.catkiss.senlive2dcompanion

import android.content.Context
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.view.SurfaceHolder
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
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return try { CaicaiPlatformView(context, messenger, viewId) }
        catch (error: Throwable) {
            CaicaiDiagnostics.record(context, "view_create_failed", error.stackTraceToString())
            CaicaiFailedPlatformView(context, messenger, viewId, error)
        }
    }

    companion object { const val VIEW_TYPE = "ai_companion/caicai_live2d_view" }
}

/** Host adapter only: all model update, accessory projection and rendering stay in Caicai. */
internal class CaicaiPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, MethodChannel.MethodCallHandler, CaicaiCompanionView.Listener {
    private val main = Handler(Looper.getMainLooper())
    private val repository = CaicaiModelRepository(context)
    private val app = context.applicationContext
    private val root = FrameLayout(context).apply {
        setBackgroundColor(Color.TRANSPARENT)
        descendantFocusability = android.view.ViewGroup.FOCUS_BLOCK_DESCENDANTS
        isFocusable = false
    }
    private val companion = CaicaiCompanionView(context)
    private val channel = MethodChannel(messenger, "ai_companion/caicai_live2d/view/$viewId")
    private val executionId = "caicai-$viewId-${android.os.SystemClock.uptimeMillis()}"
    private var disposed = false
    @Volatile private var renderStatus = "created"
    @Volatile private var renderDetail = "等待画面连接"
    @Volatile private var awaitingModelStart = false
    @Volatile private var modelStarted = false
    private var stageVisible = true
    private var hostActive = true
    private var keyboardVisible = false
    private var sceneRatio = 0f
    private val viewPrefs = app.getSharedPreferences("caicai_stage", Context.MODE_PRIVATE)
    private val initialPreferences = CaicaiStagePreferences.read(viewPrefs)
    private var motionGain = initialPreferences.motionGain
    private var motionSpeed = initialPreferences.motionSpeed
    private var legPivot = initialPreferences.legPivot
    private var stageAdjustment = false
    private var smallForm = false
    private var stageScale = initialPreferences.scale
    private var stageX = initialPreferences.x
    private var stageY = initialPreferences.y
    private var headBox = initialPreferences.headBox()
    private var editSnapshot: FloatArray? = null
    private var strokeDistance = 0f
    private var patCandidate = false
    private var patTriggered = false
    private var patStartedAt = 0L
    private var lastX = 0f
    private var lastY = 0f
    private val scaleDetector = ScaleGestureDetector(context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                if (!stageAdjustment) return false
                val previous = stageScale
                stageScale = (previous * detector.scaleFactor).coerceIn(.35f, 6f)
                val focusX = detector.focusX * 2f / companion.width.coerceAtLeast(1) - 1f
                val focusY = 1f - detector.focusY * 2f / scenePixelHeight()
                stageX = focusX - (focusX - stageX) * stageScale / previous
                stageY = focusY - (focusY - stageY) * stageScale / previous
                applyStage()
                return true
            }
        })

    init {
        channel.setMethodCallHandler(this)
        companion.isFocusable = false
        companion.isFocusableInTouchMode = false
        companion.renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY
        companion.setListener(this)
        companion.tuneCaicaiMotion(motionGain,motionSpeed,legPivot)
        companion.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) { CaicaiDiagnostics.record(app, "surface_created") }
            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                CaicaiDiagnostics.record(app, "surface_changed", "buffer=${width}x$height view=${companion.width}x${companion.height} ime=$keyboardVisible")
                if (renderStatus == "loading") companion.requestRender()
            }
            override fun surfaceDestroyed(holder: SurfaceHolder) { CaicaiDiagnostics.record(app, "surface_destroyed") }
        })
        // The standalone app's accepted front-hair connection and secondary motion.
        companion.setGeometryConstraintEnabled(true)
        companion.setFrontHairPoint(FRONT_HAIR_POINT)
        companion.setFrontHairExperimentEnabled(true)
        companion.setOnTouchListener { view, event -> handleStageTouch(view, event) }
        root.addView(companion, FrameLayout.LayoutParams(-1, -1))
        CaicaiDiagnostics.record(app, "lifecycle_owner", org.json.JSONObject(state()).toString())
        CaicaiRuntime.attach(this)
        companion.onHostResume()
    }

    override fun getView(): View = root

    override fun dispose() {
        if (disposed) return
        disposed = true
        CaicaiDiagnostics.record(app, "lifecycle_terminal", org.json.JSONObject(state()).toString())
        // Hide the SurfaceView immediately, before the hybrid PlatformView
        // teardown and GL thread release. Otherwise its last buffer can remain
        // visible over a newly selected Flutter tab on some compositors.
        companion.visibility = View.GONE
        root.visibility = View.GONE
        CaicaiRuntime.detach(this)
        channel.setMethodCallHandler(null)
        companion.setListener(null)
        // Queue global Cubism release before GLSurfaceView pauses/detaches.
        companion.release()
        companion.onPause()
        root.removeAllViews()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) return result.error("caicai_view_disposed", "Live2D view released", null)
        when (call.method) {
            "start" -> { loadCurrentModel(); result.success(state()) }
            "getState" -> result.success(state())
            "setBackground" -> {
                val asset = call.arguments as? String
                if (asset !in setOf("assets/lingchat/background/day.webp", "assets/lingchat/background/night.webp")) {
                    result.error("invalid_background", "Unsupported stage background", null)
                } else {
                    companion.setStageBackground(asset!!)
                    result.success(null)
                }
            }
            "reloadModel" -> { loadCurrentModel(); result.success(null) }
            "setVisible" -> {
                val visible = call.arguments == true
                if (stageVisible != visible) {
                    CaicaiDiagnostics.record(app, "stage_visibility", "visible=$visible")
                    stageVisible = visible
                    // Direct Hybrid Composition owns a real Android surface:
                    // hide its last buffer while another Flutter tab is shown.
                    root.alpha = if (visible) 1f else 0f
                    if (hostActive) {
                        if (visible) companion.onHostResume() else companion.onHostPause()
                    }
                }
                result.success(null)
            }
            "setKeyboardVisible" -> {
                setKeyboardVisible(call.arguments == true)
                result.success(null)
            }
            "resetStage" -> {
                stageScale = 1f; stageX = 0f; stageY = 0f
                applyStage(); result.success(null)
            }
            "setForm" -> { smallForm = call.arguments == true; companion.setSmallForm(smallForm); result.success(true) }
            "setSceneSize" -> {
                val a=call.arguments as? Map<*, *>
                val width=(a?.get("width") as? Number)?.toFloat() ?: 0f
                val height=(a?.get("height") as? Number)?.toFloat() ?: 0f
                if(width.isFinite() && height.isFinite() && width>0 && height>0) sceneRatio=height/width
                companion.setCaicaiScene(width,height)
                result.success(true)
            }
            "exportLive2DDiagnostics" -> result.success(org.json.JSONObject()
                .put("schema","caicai-runtime-v287").put("state",org.json.JSONObject(state()))
                .put("events",org.json.JSONArray(CaicaiDiagnostics.events(app)))
                .put("frames",org.json.JSONObject(companion.frameDiagnostics())).toString())
            "setEmotion" -> {
                val a=call.arguments as? Map<*, *>
                companion.presentCaicaiEmotion(a?.get("event")?.toString() ?: "manual-${System.nanoTime()}",
                    a?.get("emotion")?.toString() ?: call.arguments?.toString() ?: "normal")
                result.success(true)
            }
            "previewEmotion" -> { companion.setStaticMode(false); companion.setEmotion(call.arguments?.toString() ?: "normal"); result.success(true) }
            "parameters" -> companion.motionParameters { json -> main.post { result.success(json) } }
            "expression" -> {
                val name = call.arguments?.toString() ?: ""
                companion.setStaticMode(false)
                if (name in setOf("1白袜", "丝袜带子", "双马尾", "发带")) companion.applyExpression(name)
                else companion.playTimedPreset(name)
                result.success(true)
            }
            "static" -> { companion.clearParameterPlan(); companion.setCompositeTestMotion("live"); companion.setStaticMode(call.arguments == true); result.success(true) }
            "earTwitch" -> { companion.triggerEarTwitch(); result.success(true) }
            "getMotionTuning" -> result.success(mapOf("gain" to motionGain,"speed" to motionSpeed,"pivot" to legPivot))
            "setMotionTuning" -> {
                val a=call.arguments as? Map<*, *>
                fun bounded(key:String,old:Float,min:Float,max:Float):Float {
                    val v=(a?.get(key) as? Number)?.toFloat() ?: return old
                    return if(v.isFinite()) v.coerceIn(min,max) else old
                }
                motionGain=bounded("gain",motionGain,.5f,1.5f)
                motionSpeed=bounded("speed",motionSpeed,.65f,1.6f)
                legPivot=bounded("pivot",legPivot,.65f,.98f)
                viewPrefs.edit().putFloat("motionGain",motionGain).putFloat("motionSpeed",motionSpeed).putFloat("legPivot",legPivot).apply()
                companion.tuneCaicaiMotion(motionGain,motionSpeed,legPivot)
                result.success(true)
            }
            "stageTouch" -> {
                val a=call.arguments as? Map<*, *>
                val x=(a?.get("x") as? Number)?.toFloat()
                val y=(a?.get("y") as? Number)?.toFloat()
                val action=(a?.get("action") as? Number)?.toInt()
                if(x!=null && y!=null && action!=null && x.isFinite() && y.isFinite() && editSnapshot==null) {
                    trackHeadStroke(action,x*companion.width,y*companion.height)
                }
                result.success(null)
            }
            "headPat" -> { pat(false,false); result.success(true) }
            "headPatRare" -> { pat(false,true); result.success(true) }
            "headSweep" -> {
                companion.setStaticMode(false)
                companion.setCompositeTestMotion(call.arguments?.toString() ?: "live")
                result.success(true)
            }
            "beginEdit" -> {
                companion.clearParameterPlan()
                editSnapshot = floatArrayOf(stageScale, stageX, stageY, *headBox)
                companion.setStaticMode(true)
                result.success(editState())
            }
            "previewStage" -> {
                val a = call.arguments as? Map<*, *>
                stageScale = (a?.get("scale") as? Number)?.toFloat()?.coerceIn(.35f, 6f) ?: stageScale
                stageX = (a?.get("x") as? Number)?.toFloat() ?: stageX
                stageY = (a?.get("y") as? Number)?.toFloat() ?: stageY
                applyStage(false); result.success(editState())
            }
            "previewHeadBox" -> {
                val a = call.arguments as? List<*>
                if (a?.size == 4) {
                    val top = FloatArray(2); val bottom = FloatArray(2)
                    if (companion.screenToModelNormalized((a[0] as Number).toFloat(), (a[1] as Number).toFloat(), top)
                        && companion.screenToModelNormalized((a[2] as Number).toFloat(), (a[3] as Number).toFloat(), bottom)) {
                        headBox = floatArrayOf(top[0],top[1],bottom[0],bottom[1])
                    }
                }
                result.success(editState())
            }
            "finishEdit" -> {
                if (call.arguments != true) editSnapshot?.let {
                    stageScale=it[0]; stageX=it[1]; stageY=it[2]; headBox=it.copyOfRange(3,7)
                }
                editSnapshot=null; applyStage(call.arguments == true)
                if (call.arguments == true) viewPrefs.edit().putFloat("headLeft",headBox[0]).putFloat("headTop",headBox[1])
                    .putFloat("headRight",headBox[2]).putFloat("headBottom",headBox[3]).apply()
                companion.setStaticMode(false); result.success(true)
            }
            "adjustStage" -> { stageAdjustment = call.arguments == true; result.success(true) }
            "resetPresets" -> { companion.clearParameterPlan(); companion.setSmallForm(smallForm); result.success(true) }
            "stopMotion" -> { companion.stopConversationPlan(); result.success(true) }
            "motionPlan" -> {
                val args = call.arguments as? Map<*, *>
                val plan = org.json.JSONArray(args?.get("frames") as? List<*> ?: emptyList<Any>()).toString()
                companion.startParameterPlan(plan, args?.get("face")?.toString() ?: "", args?.get("action")?.toString() ?: "")
                CaicaiDiagnostics.record(app, "motion_plan_submitted", org.json.JSONObject(args ?: emptyMap<Any, Any>()).toString())
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun stopForDeletion() { dispose() }

    fun reloadModel() { if (!disposed) main.post(::loadCurrentModel) }
    fun hostResume() {
        if (hostActive) return
        CaicaiDiagnostics.record(app, "host_resume")
        hostActive = true
        if (!disposed && stageVisible) {
            companion.onHostResume()
            companion.requestRender()
        }
    }
    fun hostPause() {
        if (!hostActive) return
        CaicaiDiagnostics.record(app, "host_pause")
        hostActive = false
        if (!disposed) {
            companion.clearParameterPlan()
            if (stageVisible) companion.onHostPause()
        }
    }
    fun setKeyboardVisible(visible: Boolean) {
        if (!disposed && keyboardVisible != visible) {
            keyboardVisible = visible
            // Input never freezes the model. GLSurfaceView retains the tested native composition.
            companion.requestRender()
            CaicaiDiagnostics.record(app, if (visible) "keyboard_open" else "keyboard_closed")
        }
    }

    fun state(): Map<String, String> = mapOf(
        "status" to renderStatus, "detail" to renderDetail, "surface" to companion.surfaceDiagnostics(),
        "background" to companion.backgroundDiagnostics(),
        "feature" to "caicai_live2d", "execution_id" to executionId,
        "view_attached" to companion.isAttachedToWindow.toString(), "view_shown" to companion.isShown.toString(),
        "view_alpha" to companion.alpha.toString(), "keyboard_visible" to keyboardVisible.toString(),
        "scene_ratio" to sceneRatio.toString(),
        "trigger_source" to "chat_stage", "continuation_owner" to "CaicaiGL",
        "phase" to if (disposed) "disposed" else if (!hostActive || !stageVisible) "paused" else renderStatus,
        "planning_rounds" to "0", "tool_calls" to "0", "committed_mutations" to "0",
        "continuation_requested" to "false", "terminal" to disposed.toString(),
        "preempt" to (!hostActive || !stageVisible).toString(), "late_write" to "false",
        "usage_lane" to "local_render_no_network",
    )

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
        // A single requestRender may arrive before the hybrid view has a
        // nonzero SurfaceView size. Keep drawing until the model completes.
        companion.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
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
        applyStage()
        companion.requestRender()
    }

    private fun handleStageTouch(view: View, event: MotionEvent): Boolean {
        if (!stageAdjustment) {
            // Flutter forwards the exposed stage's pointer stream. Native delivery can be
            // delayed by the platform-view gesture arena; do not process it a second time.
            return true
        }
        scaleDetector.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> { lastX = event.x; lastY = event.y }
            MotionEvent.ACTION_MOVE -> {
                if (!scaleDetector.isInProgress && event.pointerCount == 1) {
                    stageX = (stageX + 2f * (event.x - lastX) / view.width.coerceAtLeast(1))
                        .coerceIn(-2f, 2f)
                    stageY = (stageY - 2f * (event.y - lastY) / scenePixelHeight())
                        .coerceIn(-2f, 2f)
                    applyStage()
                }
                lastX = event.x; lastY = event.y
            }
            MotionEvent.ACTION_POINTER_UP -> {
                val remaining = if (event.actionIndex == 0) 1 else 0
                if (remaining < event.pointerCount) { lastX = event.getX(remaining); lastY = event.getY(remaining) }
            }
            MotionEvent.ACTION_UP -> { lastX = event.x; lastY = event.y }
        }
        return true
    }

    private fun editState(): Map<String, Any> {
        val a=FloatArray(2); val b=FloatArray(2)
        val valid=companion.screenToModelNormalized(0f,0f,a) && companion.screenToModelNormalized(1f,1f,b)
        val rect=if(valid && b[0]!=a[0] && b[1]!=a[1]) listOf(
            (headBox[0]-a[0])/(b[0]-a[0]), (headBox[1]-a[1])/(b[1]-a[1]),
            (headBox[2]-a[0])/(b[0]-a[0]), (headBox[3]-a[1])/(b[1]-a[1])) else listOf(.3f,.1f,.7f,.4f)
        return mapOf("scale" to stageScale,"x" to stageX,"y" to stageY,"headRect" to rect)
    }
    private fun trackHeadStroke(action:Int,x:Float,y:Float) {
        val point=FloatArray(2)
        val inside=companion.screenToModelNormalized(x/companion.width.coerceAtLeast(1),y/companion.height.coerceAtLeast(1),point)
            && point[0] in headBox[0]..headBox[2] && point[1] in headBox[1]..headBox[3]
        when(action) {
            0 -> { lastX=x; lastY=y; strokeDistance=0f; patCandidate=inside;
                patTriggered=false; patStartedAt=android.os.SystemClock.uptimeMillis() }
            2 -> {
                // Once a stroke is accepted, the held gesture owns its face until
                // UP/CANCEL. Idle head movement may move the hit box away from
                // the finger; that is not a release.
                if(!inside && !patTriggered) patCandidate=false
                strokeDistance+=kotlin.math.hypot(x-lastX,y-lastY)
                lastX=x; lastY=y
                if(patCandidate && !patTriggered && android.os.SystemClock.uptimeMillis()-patStartedAt>=120
                    && strokeDistance>maxOf(34*root.resources.displayMetrics.density,companion.width*.075f)) {
                    patTriggered=true; pat(true,Math.random()<.10)
                }
            }
            1,3 -> { strokeDistance=0f; patCandidate=false; patTriggered=false; companion.releaseHeadPat() }
        }
    }
    private fun pat(held:Boolean,rare:Boolean) {
        companion.setStaticMode(false)
        companion.triggerEarTwitch()
        companion.beginCaicaiPat(held,rare)
        CaicaiDiagnostics.record(app,"head_pat_started","held=$held rare=$rare")
    }
    fun observeTouch(x: Float, y: Float) { if (!disposed && editSnapshot == null) companion.setLookTarget(true,x,y) }
    private fun scenePixelHeight(): Float = if(sceneRatio>0) companion.width.coerceAtLeast(1)*sceneRatio else companion.height.coerceAtLeast(1).toFloat()
    private fun applyStage(persist: Boolean = true) {
        val limit = .9f + .5f * stageScale
        stageX = stageX.coerceIn(-limit, limit); stageY = stageY.coerceIn(-limit, limit)
        companion.setStageTransform(stageScale, stageX, stageY)
        if (persist) viewPrefs.edit().putFloat("scale", stageScale).putFloat("x", stageX).putFloat("y", stageY).apply()
        companion.requestRender()
    }

    fun refreshPreferences() {
        if (disposed) return
        val restored = CaicaiStagePreferences.read(viewPrefs)
        val previous = CaicaiStagePreferences(motionGain, motionSpeed, legPivot,
            stageScale, stageX, stageY, headBox[0], headBox[1], headBox[2], headBox[3])
        val changed = restored != previous
        motionGain = restored.motionGain; motionSpeed = restored.motionSpeed; legPivot = restored.legPivot
        stageScale = restored.scale; stageX = restored.x; stageY = restored.y; headBox = restored.headBox()
        // An editor opened before restore must not later put its old snapshot back.
        editSnapshot?.let { editSnapshot = floatArrayOf(stageScale, stageX, stageY, *headBox) }
        if (changed) restored.applyTo(companion, previous)
        CaicaiDiagnostics.record(app, "stage_preferences_restored", "execution_id=$executionId changed=$changed")
    }

    fun speechAmplitude(value: Float) { if (!disposed) companion.setSpeechAmplitude(value) }

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
        CaicaiDiagnostics.record(app, "first_model_frame", companion.surfaceDiagnostics())
        if (newlyLoaded) main.post { if (!disposed) repository.confirmPendingImport() }
        main.post {
            if (!disposed) companion.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        send("onReady", mapOf("detail" to detail))
    }
    override fun onError(error: Throwable) {
        awaitingModelStart = false
        renderStatus = "error"
        renderDetail = error.message ?: error.javaClass.simpleName
        CaicaiDiagnostics.record(app, "render_error", error.stackTraceToString())
        send("onError", mapOf("detail" to renderDetail))
        // A GL/host failure is not proof that the imported ZIP is invalid.
        // Retain the package and the actual error for retry and diagnostics.
        main.post { if (!disposed) companion.renderMode = GLSurfaceView.RENDERMODE_WHEN_DIRTY }
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
/** Keep creation failures observable through the same Dart channel, including start. */
private class CaicaiFailedPlatformView(context: Context, messenger: BinaryMessenger,
    viewId: Int, error: Throwable) : PlatformView {
    private val root = FrameLayout(context)
    private val channel = MethodChannel(messenger, "ai_companion/caicai_live2d/view/$viewId")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "start" || call.method == "getState")
                result.success(mapOf("status" to "error", "detail" to
                    "原生画面创建失败：${error.javaClass.simpleName}"))
            else result.success(null)
        }
    }
    override fun getView(): View = root
    override fun dispose() { channel.setMethodCallHandler(null) }
}

object CaicaiRuntime {
    @Volatile private var active = WeakReference<CaicaiPlatformView>(null)

    @Synchronized internal fun attach(view: CaicaiPlatformView) {
        active.get()?.takeIf { it !== view }?.dispose()
        active = WeakReference(view)
    }
    @Synchronized internal fun detach(view: CaicaiPlatformView) {
        if (active.get() === view) active.clear()
    }
    fun observeTouch(x: Float, y: Float) = active.get()?.observeTouch(x,y)
    fun hasActiveView(): Boolean = active.get() != null
    fun speechAmplitude(value: Float) = active.get()?.speechAmplitude(value)
    fun control(method: String, arguments: Any?, result: MethodChannel.Result) {
        val view = active.get()
        if (view == null) result.success(false) else view.onMethodCall(MethodCall(method, arguments), result)
    }
    fun releaseModel() = active.get()?.stopForDeletion()
    fun refreshPreferences() = active.get()?.refreshPreferences()
    fun reloadModel() = active.get()?.reloadModel()
    fun onHostResume() = active.get()?.hostResume()
    fun onHostPause() = active.get()?.hostPause()
    fun setKeyboardVisible(visible: Boolean) = active.get()?.setKeyboardVisible(visible)
    fun state(): Map<String, String> = active.get()?.state()
        ?: mapOf("status" to "not_open", "detail" to "请打开聊天画面验证模型")
}
