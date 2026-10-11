package com.aicompanion.localfirst

import android.content.Context
import android.view.View
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject

/** Same renderer for preview and play; no Activity is needed for preview. */
class CreativeBridge(context: Context, engine: FlutterEngine) {
    private val preview = CreativePreview(context.applicationContext)
    private val messenger = engine.dartExecutor.binaryMessenger
    private val channel = MethodChannel(messenger, "ai_companion/creative_preview")
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "preview" -> {
                    val html = call.argument<String>("html") ?: ""
                    val checks = call.argument<List<Map<String, String>>>("checks") ?: emptyList()
                    preview.run(html, checks.take(6)) { result.success(it) }
                }
                "cancel" -> { preview.cancel(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        engine.platformViewsController.registry.registerViewFactory(
            "ai_companion/creative_player", object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    val data = args as? Map<*, *> ?: emptyMap<String, Any>()
                    val playerChannel = MethodChannel(messenger, "ai_companion/creative_player/$viewId")
                    var disposed = false
                    var observation: MethodChannel.Result? = null
                    var observationToken = ""
                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                    val timeout = Runnable { observation?.error("observation_timeout", "页面状态读取超时", null); observation = null }
                    lateinit var page: android.webkit.WebView
                    page = CreativeWebSandbox.create(context, onMessage@{ raw ->
                        if (!disposed) try {
                            val event = JSONObject(raw)
                            val id = event.getString("id")
                            if (event.optString("kind") == "observation") {
                                if (id == observationToken) {
                                    val result = observation; observation = null; handler.removeCallbacks(timeout)
                                    result?.success(event.optJSONObject("data")?.toString() ?: "{}")
                                }
                                return@onMessage
                            }
                            playerChannel.invokeMethod("event", raw, object : MethodChannel.Result {
                                override fun success(value: Any?) { if (!disposed) CreativeWebSandbox.reply(page,id,value) }
                                override fun error(code: String, message: String?, details: Any?) {
                                    if (!disposed) CreativeWebSandbox.reply(page,id,null,message ?: code)
                                }
                                override fun notImplemented() { error("unavailable","互动暂不可用",null) }
                            })
                        } catch (_: Exception) { }
                    }, { error -> if (!disposed) playerChannel.invokeMethod("error", error) })
                    playerChannel.setMethodCallHandler { call, result ->
                        if (call.method == "load" && !disposed) {
                            try {
                                page.loadDataWithBaseURL(CreativeWebSandbox.ORIGIN,
                                    CreativeWebSandbox.document(data["html"] as? String ?: "", data["state"] as? String ?: "{}", false),
                                    "text/html", "UTF-8", null)
                                result.success(null)
                            } catch (_: Exception) { result.error("invalid_work", "作品无法打开", null) }
                        } else if (call.method == "observe" && !disposed) {
                            if (observation != null) result.error("busy", "正在读取页面", null)
                            else {
                                observation = result; observationToken = java.util.UUID.randomUUID().toString()
                                handler.postDelayed(timeout, 3000)
                                page.evaluateJavascript("window.__workObserve(" + JSONObject.quote(observationToken) + ")", null)
                            }
                        } else result.notImplemented()
                    }
                    return object : PlatformView {
                        override fun getView(): View = page
                        override fun dispose() {
                            disposed = true; playerChannel.setMethodCallHandler(null)
                            handler.removeCallbacks(timeout); observation?.error("closed", "作品已关闭", null); observation = null
                            page.stopLoading(); page.removeJavascriptInterface("NativeWork"); page.destroy()
                        }
                    }
                }
            })
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() { preview.cancel() }
            override fun onEngineWillDestroy() { preview.cancel(); channel.setMethodCallHandler(null) }
        })
    }
}
