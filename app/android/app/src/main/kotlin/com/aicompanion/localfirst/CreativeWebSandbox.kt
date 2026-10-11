package com.aicompanion.localfirst

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.app.Presentation
import android.hardware.display.DisplayManager
import android.media.ImageReader
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.JavascriptInterface
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.File
import java.util.UUID

/** A local-only page. The bridge only transports bounded JSON to its owning work session. */
object CreativeWebSandbox {
    const val ORIGIN = "https://companion-work.invalid/"
    const val MAX_HTML = 800_000
    const val POLICY = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; media-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'"

    fun document(html: String, state: String, preview: Boolean): String {
        require(html.toByteArray().size <= MAX_HTML) { "作品文件过大" }
        val initial = JSONObject.quote(state).replace("<", "\\u003c")
        val prefix = """<meta http-equiv="Content-Security-Policy" content="$POLICY"><meta name="viewport" content="width=device-width,initial-scale=1"><script>
        (()=>{const pending=new Map();let sequence=0;
        const initial=JSON.parse($initial);
        const post=(kind,data)=>{const id=String(++sequence);return new Promise((resolve,reject)=>{
          pending.set(id,{resolve,reject});NativeWork.postMessage(JSON.stringify({id,kind,data}));
        });};
        window.__workReply=(id,value,error)=>{const p=pending.get(id);if(!p)return;pending.delete(id);error?p.reject(new Error(error)):p.resolve(value);};
        window.companion=Object.freeze({preview:$preview,initialState:initial,
          saveState:(value)=>post('save',value),
          choose:(turn,options,context)=>post('choose',{turn,options,context}),
          reveal:(turn,playerChoice)=>post('reveal',{turn,playerChoice}),
          report:(event)=>post('report',event)});
        window.__workErrors=[];window.addEventListener('error',e=>window.__workErrors.push(String(e.message).slice(0,300)));
        window.addEventListener('unhandledrejection',e=>window.__workErrors.push(String(e.reason).slice(0,300)));
        })();</script>"""
        // The restrictive CSP precedes every generated node; pages cannot relax it with another CSP.
        return "<!doctype html><html><head>$prefix</head><body>$html</body></html>"
    }

    @SuppressLint("SetJavaScriptEnabled", "AddJavascriptInterface")
    fun create(context: Context, onMessage: (String) -> Unit, onError: (String) -> Unit): WebView {
        check(Looper.myLooper() == Looper.getMainLooper())
        return WebView(context).apply {
            setBackgroundColor(Color.WHITE)
            settings.javaScriptEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.domStorageEnabled = false
            settings.blockNetworkLoads = true
            settings.mediaPlaybackRequiresUserGesture = true
            settings.setSupportMultipleWindows(false)
            isSaveEnabled = false
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = true
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                    return WebResourceResponse("text/plain", "UTF-8", ByteArrayInputStream(ByteArray(0)))
                }
                override fun onRenderProcessGone(view: WebView, detail: android.webkit.RenderProcessGoneDetail): Boolean {
                    onError("网页运行进程已结束")
                    (view.parent as? ViewGroup)?.removeView(view)
                    view.destroy()
                    return true
                }
            }
            webChromeClient = object : WebChromeClient() {
                override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                    if (message.messageLevel() == ConsoleMessage.MessageLevel.ERROR) onError(message.message().take(300))
                    return true
                }
                override fun onPermissionRequest(request: android.webkit.PermissionRequest) { request.deny() }
            }
            addJavascriptInterface(object {
                @JavascriptInterface fun postMessage(raw: String) {
                    if (raw.toByteArray().size <= 65_536) Handler(Looper.getMainLooper()).post { onMessage(raw) }
                }
            }, "NativeWork")
        }
    }

    fun reply(view: WebView, id: String, value: Any?, error: String? = null) {
        val encoded = if (value == null) "null" else JSONObject.wrap(value).toString()
        view.evaluateJavascript("window.__workReply(${JSONObject.quote(id)},$encoded,${error?.let(JSONObject::quote) ?: "null"})", null)
    }
}

/** Renders only app-owned content on a private virtual display. Never launches an Activity,
 * requests screen capture, mirrors the device display or creates a phone overlay. */
class CreativePreview(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var stop: (() -> Unit)? = null

    fun cancel() { handler.post { stop?.invoke() } }

    fun run(html: String, checks: List<Map<String, String>>, done: (Map<String, Any?>) -> Unit) {
        handler.post {
            if (stop != null) { done(mapOf("ok" to false,"errors" to listOf("预览正在使用"))); return@post }
            val errors = mutableListOf<String>()
            val checked = mutableListOf<String>()
            var finished = false
            var page: WebView? = null
            var presentation: Presentation? = null
            var display: android.hardware.display.VirtualDisplay? = null
            var reader: ImageReader? = null
            var frame: Bitmap? = null
            var loaded = false
            val timeout = Runnable { stop?.invoke() }
            fun finish(reason: String? = null) {
                if (finished) return
                finished = true
                if (reason != null) errors.add(reason)
                handler.removeCallbacks(timeout)
                var screenshot: String? = null
                val bitmap = frame
                if (bitmap != null) {
                    val colors = mutableSetOf<Int>()
                    for (y in 0 until bitmap.height step 12) for (x in 0 until bitmap.width step 12) colors.add(bitmap.getPixel(x,y))
                    if (colors.size < 3) errors.add("截图没有可确认的画面内容")
                    else {
                        val root = File(context.cacheDir,"creative_previews").apply { mkdirs() }
                        root.listFiles()?.filter { System.currentTimeMillis()-it.lastModified()>86_400_000 }?.forEach { it.delete() }
                        val target = File(root,"${UUID.randomUUID()}.png")
                        target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
                        screenshot = target.path
                    }
                } else errors.add("没有收到实际渲染帧")
                page?.let { (it.parent as? ViewGroup)?.removeView(it); it.stopLoading(); it.destroy() }
                presentation?.dismiss(); display?.release(); reader?.close(); frame?.recycle()
                stop = null
                done(mapOf("ok" to (loaded && errors.isEmpty()),"errors" to errors.distinct(),"checks" to checked,"screenshot" to screenshot,"display" to "private_virtual"))
            }
            stop = { finish("预览已取消或超时") }
            handler.postDelayed(timeout,20_000)
            try {
                val width=720; val height=1120
                reader=ImageReader.newInstance(width,height,PixelFormat.RGBA_8888,2)
                reader!!.setOnImageAvailableListener({ source ->
                    val image=source.acquireLatestImage() ?: return@setOnImageAvailableListener
                    try {
                        val plane=image.planes[0]; val padded=plane.rowStride/plane.pixelStride
                        val raw=Bitmap.createBitmap(padded,height,Bitmap.Config.ARGB_8888)
                        raw.copyPixelsFromBuffer(plane.buffer)
                        val clipped=Bitmap.createBitmap(raw,0,0,width,height)
                        if (clipped !== raw) raw.recycle()
                        frame?.recycle(); frame=clipped
                    } finally { image.close() }
                },handler)
                display=(context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).createVirtualDisplay(
                    "CompanionWorkPreview",width,height,320,reader!!.surface,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY or DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION)
                requireNotNull(display) { "此设备无法建立独立预览" }
                presentation=Presentation(context,display!!.display)
                page=CreativeWebSandbox.create(presentation!!.context,{ raw ->
                    val message=runCatching { JSONObject(raw) }.getOrNull() ?: return@create
                    val id=message.optString("id")
                    when(message.optString("kind")) {
                        "save", "report" -> CreativeWebSandbox.reply(page!!,id,true)
                        "choose" -> CreativeWebSandbox.reply(page!!,id,mapOf("committed" to true,"preview" to true))
                        "reveal" -> CreativeWebSandbox.reply(page!!,id,mapOf("choice" to "preview","preview" to true))
                        else -> CreativeWebSandbox.reply(page!!,id,null,"未知作品接口")
                    }
                }, { errors.add(it) })
                presentation!!.setContentView(page!!)
                presentation!!.show()
                page!!.loadDataWithBaseURL(CreativeWebSandbox.ORIGIN,CreativeWebSandbox.document(html,"{}",true),"text/html","UTF-8",null)
                fun inspect(index: Int) {
                    if (finished) return
                    if (index >= checks.size) {
                        page!!.evaluateJavascript("JSON.stringify({text:document.body.innerText.slice(0,300),nodes:document.body.children.length,errors:window.__workErrors||[]})") { value ->
                            if (finished) return@evaluateJavascript
                            runCatching {
                                val decoded=JSONArray("[$value]").getString(0)
                                val data=JSONObject(decoded)
                                loaded=data.optInt("nodes")>1 && (data.optString("text").isNotBlank() || html.contains("canvas"))
                                val js=data.optJSONArray("errors") ?: JSONArray()
                                for(i in 0 until js.length()) errors.add(js.getString(i))
                            }.onFailure { errors.add("未收到网页检查结果") }
                            handler.postDelayed({ finish() },500)
                        }
                        return
                    }
                    val step=checks[index]
                    val click=JSONObject.quote(step["click"].orEmpty())
                    val selector=JSONObject.quote(step["selector"].orEmpty())
                    val text=JSONObject.quote(step["text"].orEmpty())
                    page!!.evaluateJavascript("(()=>{try{const s=$click;if(s){const n=document.querySelector(s);if(!n)return 'missing_click';n.click();}return 'clicked';}catch(e){return String(e)}})()") { value ->
                        if(finished)return@evaluateJavascript
                        if(value!="\"clicked\"") errors.add("交互检查${index+1}: $value")
                        handler.postDelayed({ if(!finished) page!!.evaluateJavascript("(()=>{try{const s=$selector;if(!s)return true;const n=document.querySelector(s);return !!n&&n.textContent.includes($text);}catch(e){return false}})()") { answer ->
                            if(answer=="true") checked.add("step:${index+1}") else errors.add("交互检查${index+1}未通过")
                            inspect(index+1)
                        } },250)
                    }
                }
                handler.postDelayed({ inspect(0) },1500)
            } catch(error: Exception) { finish("独立预览不可用：${error.javaClass.simpleName}") }
        }
    }
}
