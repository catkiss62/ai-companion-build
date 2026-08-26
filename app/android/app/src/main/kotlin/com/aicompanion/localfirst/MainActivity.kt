package com.aicompanion.localfirst

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridge: SystemBridge? = null
    private var ttsBridge: NativeTtsBridge? = null
    private var emotionSoundBridge: EmotionSoundBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = SystemBridge(this, flutterEngine)
        ttsBridge = NativeTtsBridge(this, flutterEngine)
        emotionSoundBridge = EmotionSoundBridge(this, flutterEngine)
    }

    override fun onStart() {
        super.onStart()
        CompanionRuntimeState.activityStarted()
    }

    override fun onResume() {
        super.onResume()
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
        CompanionRuntimeState.activityStopped()
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.dispose()
        bridge = null
        ttsBridge?.dispose()
        ttsBridge = null
        emotionSoundBridge?.dispose()
        emotionSoundBridge = null
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
        bridge?.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        const val EXTRA_OPEN_CHAT = "ai_companion_open_chat"
    }
}
