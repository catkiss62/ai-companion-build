package com.aicompanion.localfirst

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream

/** Trusted bundled game only. No file/content/network access or chat write API. */
internal class WordSliceHost(private val activity: FlutterActivity, engine: FlutterEngine,
    private val motion: RoomDepthMotionBridge?) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "ai_companion/word_slice")
    private val main = Handler(Looper.getMainLooper())
    private var web: WebView? = null
    private var layer: FrameLayout? = null
    private var layout = JSONObject()
    private var enabled = false
    private var resumed = true
    private var ready = false
    private var playing = false
    private var disposed = false
    private var epoch = 0
    private var pendantX = Double.NaN
    private var pendantY = Double.NaN
    private var lastMotion = 0L
    private var lastHeartbeat = 0L
    private val density get() = activity.resources.displayMetrics.density
    private val timeout = Runnable { if (playing) reset() }
    private val watchdog = object : Runnable {
        override fun run() {
            if (!playing || disposed) return
            if (android.os.SystemClock.uptimeMillis() - lastHeartbeat > 3000) {
                destroyPage(); return
            }
            main.postDelayed(this, 1000)
        }
    }
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    enabled = args["enabled"] == true
                    layout = JSONObject(args)
                    pendantX = Double.NaN; pendantY = Double.NaN
                    if (enabled && resumed) {
                        try { ensurePage(); show() } catch (_: Exception) { destroyPage() }
                    } else hide()
                    result.success(null)
                }
                "hide" -> { enabled = false; hide(); result.success(null) }
                "dispose" -> { enabled = false; destroyPage(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun evaluate(code: String) { web?.evaluateJavascript(code, null) }
    private fun notifyPlaying(value: Boolean) {
        playing = value
        channel.invokeMethod("playing", value)
        main.removeCallbacks(watchdog)
        if (value) {
            lastHeartbeat = android.os.SystemClock.uptimeMillis()
            main.postDelayed(watchdog, 1000)
            layer?.bringToFront()
        }
    }
    private fun reset() {
        epoch++; main.removeCallbacks(timeout)
        evaluate("window.sliceHost&&sliceHost.reset()")
        notifyPlaying(false)
    }
    fun onPause() { resumed = false; hide() }
    fun onResume() { resumed = true; if (enabled) show() }
    fun onBack(): Boolean {
        if (!playing) return false
        reset(); return true
    }
    private fun hide() {
        motion?.setPendantListener(null)
        reset()
        evaluate("window.sliceHost&&sliceHost.suspend()")
        layer?.visibility = View.GONE
        web?.onPause()
    }
    private fun show() {
        if (!ready || !enabled || !resumed || disposed) return
        web?.onResume()
        evaluate("sliceHost.configure($layout);sliceHost.resume()")
        layer?.visibility = View.VISIBLE
        motion?.setPendantListener { x, y, reset ->
            val now = android.os.SystemClock.uptimeMillis()
            if (reset || now-lastMotion >= 33) {
                lastMotion = now
                evaluate("sliceHost.motion($x,$y,$reset)")
            }
        }
    }
    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun ensurePage() {
        if (web != null || disposed) return
        val host = object : FrameLayout(activity) {
            private var ownsGesture = false
            override fun dispatchTouchEvent(event: MotionEvent): Boolean {
                if (event.actionMasked == MotionEvent.ACTION_DOWN) {
                    val x = event.x / density; val y = event.y / density
                    val ax = if (pendantX.isFinite()) pendantX.toFloat() else layout.optDouble("anchorX").toFloat()
                    val ay = if (pendantY.isFinite()) pendantY.toFloat() else layout.optDouble("panelTop").toFloat() + 66f
                    ownsGesture = playing || (x >= ax-38 && x <= ax+38 && y >= ay-38 && y <= ay+38)
                }
                if (!ownsGesture) return false
                super.dispatchTouchEvent(event)
                if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) ownsGesture = false
                return true
            }
        }.apply { setBackgroundColor(Color.TRANSPARENT); visibility = View.GONE }
        val view = WebView(activity).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isFocusable = false; isFocusableInTouchMode = false
            isVerticalScrollBarEnabled = false; isHorizontalScrollBarEnabled = false
            settings.javaScriptEnabled = true
            settings.allowFileAccess = false; settings.allowContentAccess = false
            settings.domStorageEnabled = false
            settings.mediaPlaybackRequiresUserGesture = false
            settings.blockNetworkLoads = true
            addJavascriptInterface(object {
                @JavascriptInterface fun pendantPosition(x: Double, y: Double) { main.post {
                    if (web === this@apply && x.isFinite() && y.isFinite()) { pendantX = x; pendantY = y }
                } }
                @JavascriptInterface fun ready() { main.post { if (web === this@apply && !disposed) { ready = true; show() } } }
                @JavascriptInterface fun failed() { main.post { if (web === this@apply) destroyPage() } }
                @JavascriptInterface fun heartbeat() { main.post { if (web === this@apply) lastHeartbeat = android.os.SystemClock.uptimeMillis() } }
                @JavascriptInterface fun setPlaying(value: Boolean) { main.post { if (web === this@apply && (!value || enabled && resumed)) notifyPlaying(value) } }
                @JavascriptInterface fun requestStart() { main.post {
                    if (web !== this@apply || !enabled || !resumed || !ready) return@post
                    val request = ++epoch
                    main.removeCallbacks(timeout); main.postDelayed(timeout, 1800)
                    channel.invokeMethod("capture", null, object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            if (request != epoch || !enabled || !resumed || web !== this@apply) return
                            main.removeCallbacks(timeout)
                            val glyphs = (result as? List<*>) ?: emptyList<Any>()
                            evaluate("sliceHost.start(${JSONArray(glyphs)})")
                        }
                        override fun error(code: String, message: String?, details: Any?) { if (request == epoch) reset() }
                        override fun notImplemented() { if (request == epoch) reset() }
                    })
                } }
            }, "NativeSlice")
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = true
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                    if (request.url.scheme == "data") return null
                    return WebResourceResponse("text/plain", "UTF-8", ByteArrayInputStream(ByteArray(0)))
                }
                override fun onRenderProcessGone(view: WebView, detail: android.webkit.RenderProcessGoneDetail): Boolean {
                    if (web === view) destroyPage(); return true
                }
            }
        }
        web = view; layer = host
        host.addView(view, FrameLayout.LayoutParams(-1, -1))
        activity.addContentView(host, ViewGroup.LayoutParams(-1, -1))
        val html = activity.assets.open("word_slice/index.html").bufferedReader().use { it.readText() }
        view.loadDataWithBaseURL("https://word-slice.invalid/", html, "text/html", "UTF-8", null)
    }
    private fun destroyPage() {
        motion?.setPendantListener(null)
        pendantX = Double.NaN; pendantY = Double.NaN
        epoch++; main.removeCallbacks(timeout); main.removeCallbacks(watchdog)
        ready = false; notifyPlaying(false)
        val old = web; web = null
        layer?.let { (it.parent as? ViewGroup)?.removeView(it) }; layer = null
        old?.removeJavascriptInterface("NativeSlice"); old?.stopLoading(); old?.destroy()
    }
    fun dispose() { disposed = true; enabled = false; destroyPage(); channel.setMethodCallHandler(null) }
}
