package com.aicompanion.localfirst

import android.content.Intent
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bridge: SystemBridge? = null
    private var ttsBridge: NativeTtsBridge? = null
    private var emotionSoundBridge: EmotionSoundBridge? = null
    private var live2DModelStorageBridge: Live2DModelStorageBridge? = null
    private var roomDepthMotion: RoomDepthMotionBridge? = null
    private var caicaiLive2DBridge: CaicaiLive2DBridge? = null
    private var nativeFateWheelChannel: MethodChannel? = null
    private var pendingFateWheelResult: MethodChannel.Result? = null
    private var nativeMemoryGalaxyChannel: MethodChannel? = null
    private var pendingMemoryGalaxyResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Volume buttons should adjust the stream used by both voice and cues,
        // including the interval before a new AudioTrack starts playing.
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    private var lastCaicaiTouch = 0L
    override fun dispatchTouchEvent(event: android.view.MotionEvent): Boolean {
        // Observe without consuming: Flutter text selection, buttons and scrolling retain ownership.
        val now = android.os.SystemClock.uptimeMillis()
        if (event.actionMasked == android.view.MotionEvent.ACTION_DOWN ||
            event.actionMasked == android.view.MotionEvent.ACTION_MOVE && now-lastCaicaiTouch >= 33) {
            lastCaicaiTouch = now
            val root = window.decorView
            com.catkiss.senlive2dcompanion.CaicaiRuntime.observeTouch(
                (event.x * 2f / root.width.coerceAtLeast(1) - 1f).coerceIn(-1f,1f),
                (1f - event.y * 2f / root.height.coerceAtLeast(1)).coerceIn(-1f,1f))
        }
        return super.dispatchTouchEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = SystemBridge(this, flutterEngine)
        ttsBridge = NativeTtsBridge(this, flutterEngine)
        emotionSoundBridge = EmotionSoundBridge(this, flutterEngine)
        live2DModelStorageBridge = Live2DModelStorageBridge(this, flutterEngine)
        caicaiLive2DBridge = CaicaiLive2DBridge(this, flutterEngine)
        roomDepthMotion = RoomDepthMotionBridge(this, flutterEngine)
        nativeFateWheelChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ai_companion/fate_wheel_native",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                } else if (pendingFateWheelResult != null) {
                    result.error("already_open", "Native wheel is already open", null)
                } else {
                    pendingFateWheelResult = result
                    try {
                        startActivityForResult(
                            Intent(this, NativeFateWheelActivity::class.java),
                            REQUEST_NATIVE_FATE_WHEEL,
                        )
                    } catch (error: Exception) {
                        pendingFateWheelResult = null
                        result.error("open_failed", error.javaClass.simpleName, null)
                    }
                }
            }
        }
        nativeMemoryGalaxyChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ai_companion/memory_galaxy_native",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                } else if (pendingMemoryGalaxyResult != null) {
                    result.error("already_open", "Memory galaxy is already open", null)
                } else {
                    try {
                        val dataFile = MemoryGalaxyFiles.snapshot(cacheDir, call.argument<String>("dataPath"))
                        pendingMemoryGalaxyResult = result
                        startActivityForResult(
                            Intent(this, NativeMemoryGalaxyActivity::class.java)
                                .putExtra(NativeMemoryGalaxyActivity.EXTRA_DATA_PATH, dataFile.path),
                            REQUEST_NATIVE_MEMORY_GALAXY,
                        )
                    } catch (error: Exception) {
                        pendingMemoryGalaxyResult = null
                        result.error("open_failed", error.javaClass.simpleName, null)
                    }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        CompanionRuntimeState.activityStarted()
        traceCaicaiLifecycle("activity_start")
        // Recents can pause an Activity while its chat SurfaceView remains visible.
        // Resume the GL thread only after it was stopped with the Activity.
        caicaiLive2DBridge?.onResume()
    }

    override fun onResume() {
        super.onResume()
        roomDepthMotion?.onResume()
        traceCaicaiLifecycle("activity_resume")
        // Returning from overlay/accessibility/notification settings is a
        // user-visible moment, so it is safe to reconcile an explicitly
        // enabled foreground companion service here. If the true floating
        // chat was expanded, collapse it so the full app never competes with
        // the overlay for input focus.
        // Collapse first so a full Activity never competes with an expanded
        // overlay for input. Reconcile afterwards is now lightweight unless a
        // prior system-cover transition explicitly marked input as suspect.
        OverlayBubbleService.collapseChatFromVisibleActivity(this)
        OverlayBubbleService.reconcileFromVisibleActivity(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Flutter keeps a single Activity for overlay launches. Retain the
        // newest intent so Dart can consume the requested destination after
        // onResume, whether the app was cold, backgrounded or already visible.
        setIntent(intent)
        bridge?.notifyOpenChatLaunch(intent)
    }

    override fun onStop() {
        traceCaicaiLifecycle("activity_stop")
        caicaiLive2DBridge?.onPause()
        CompanionRuntimeState.activityStopped()
        super.onStop()
    }

    override fun onPause() {
        roomDepthMotion?.onPause()
        traceCaicaiLifecycle("activity_pause")
        super.onPause()
    }

    private fun traceCaicaiLifecycle(stage: String) {
        val runtime = com.catkiss.senlive2dcompanion.CaicaiRuntime
        if (!runtime.hasActiveView()) return
        val state = runtime.state()
        com.catkiss.senlive2dcompanion.CaicaiDiagnostics.record(
            this, stage, "owner=${state["execution_id"]} ${state["surface"].orEmpty()}",
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CompanionRuntimeState.setImmersiveChatPageVisible(false)
        roomDepthMotion?.dispose()
        roomDepthMotion = null
        bridge?.dispose()
        bridge = null
        ttsBridge?.dispose()
        ttsBridge = null
        emotionSoundBridge?.dispose()
        emotionSoundBridge = null
        live2DModelStorageBridge?.dispose()
        live2DModelStorageBridge = null
        caicaiLive2DBridge?.dispose()
        caicaiLive2DBridge = null
        nativeFateWheelChannel?.setMethodCallHandler(null)
        nativeFateWheelChannel = null
        pendingFateWheelResult?.success(null)
        pendingFateWheelResult = null
        nativeMemoryGalaxyChannel?.setMethodCallHandler(null)
        nativeMemoryGalaxyChannel = null
        pendingMemoryGalaxyResult?.success(null)
        pendingMemoryGalaxyResult = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bridge?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_NATIVE_FATE_WHEEL) {
            pendingFateWheelResult?.success(
                if (resultCode == RESULT_OK) data?.getStringExtra(NativeFateWheelActivity.EXTRA_RESULT)
                else null,
            )
            pendingFateWheelResult = null
            return
        }
        if (requestCode == REQUEST_NATIVE_MEMORY_GALAXY) {
            val error = data?.getStringExtra(NativeMemoryGalaxyActivity.EXTRA_ERROR)
            if (error != null) {
                pendingMemoryGalaxyResult?.error("galaxy_failed", error, null)
            } else {
                pendingMemoryGalaxyResult?.success(resultCode == RESULT_OK)
            }
            pendingMemoryGalaxyResult = null
            return
        }
        if (caicaiLive2DBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        bridge?.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        const val EXTRA_OPEN_CHAT = "ai_companion_open_chat"
        private const val REQUEST_NATIVE_FATE_WHEEL = 0xF217
        private const val REQUEST_NATIVE_MEMORY_GALAXY = 0xF218
    }
}
