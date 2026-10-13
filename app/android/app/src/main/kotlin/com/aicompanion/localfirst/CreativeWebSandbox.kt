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
import java.security.MessageDigest

/** A local-only page. The bridge only transports bounded JSON to its owning work session. */
object CreativeWebSandbox {
    const val ORIGIN = "https://companion-work.invalid/"
    const val MAX_HTML = 800_000
    const val POLICY = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; media-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'"

    fun turnId(value: Any?): String? = when (value) {
        is String -> value.takeIf { it.isNotBlank() && it.length <= 80 }
        is Number -> value.toDouble().let {
            if (it.isFinite() && it >= 0 && it <= 9007199254740991.0 && it == Math.floor(it)) it.toLong().toString() else null
        }
        else -> null
    }

    fun options(value: JSONArray?): List<String>? {
        if (value == null || value.length() !in 2..8) return null
        val result = (0 until value.length()).map { value.opt(it) }
        if (result.any { it !is String || it.isEmpty() || it.length > 80 } || result.toSet().size != result.size) return null
        return result.map { it as String }
    }

    fun document(html: String, state: String, preview: Boolean): String {
        require(html.toByteArray().size <= MAX_HTML) { "作品文件过大" }
        val initial = JSONObject.quote(state).replace("<", "\\u003c")
        val prefix = """<meta http-equiv="Content-Security-Policy" content="$POLICY"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"><script>
        (()=>{const pending=new Map();let sequence=0;
        const initial=JSON.parse($initial);
        const turnId=value=>{if(typeof value==='string'&&value.trim()&&value.length<=80)return value;
          if(typeof value==='number'&&Number.isSafeInteger(value)&&value>=0)return String(value);
          throw new Error('回合编号需要非空字符串或安全整数');};
        const post=(kind,data)=>{const id=String(++sequence);return new Promise((resolve,reject)=>{
          try {
            const raw=JSON.stringify({id,kind,data});
            if(new Blob([raw]).size>65536)throw new Error('互动数据过大');
            pending.set(id,{resolve,reject,kind});NativeWork.postMessage(raw);
          } catch(error) {pending.delete(id);reject(error);}
        });};
        window.__workReply=(id,value,error)=>{const p=pending.get(id);if(!p)return;pending.delete(id);error?p.reject(new Error(error)):p.resolve(value);};
        window.companion=Object.freeze({preview:$preview,initialState:initial,
          saveState:(value)=>post('save',value),
          choose:async(turn,options,context)=>post('choose',{turn:turnId(turn),options,context}),
          reveal:async(turn,playerChoice)=>post('reveal',{turn:turnId(turn),playerChoice}),
          report:(event)=>post('report',event),describe:(value)=>post('describe',value)});
        window.__workObserve=async(token)=>{
          const writing=()=>Array.from(pending.values()).some(p=>p.kind!=='choose');
          const end=Date.now()+1500;
          while(writing()&&Date.now()<end)await new Promise(r=>setTimeout(r,16));
          const visible=e=>{const s=getComputedStyle(e);return s.display!=='none'&&s.visibility!=='hidden'&&e.getClientRects().length>0};
          const nodes=Array.from(document.querySelectorAll('body *')).slice(0,600).filter(visible);
          const animated=nodes.filter(e=>getComputedStyle(e).animationName!=='none').slice(0,12).map(e=>{
            const s=getComputedStyle(e);return {element:(e.id||e.tagName).slice(0,100),name:s.animationName.slice(0,160),duration:s.animationDuration.slice(0,100),state:s.animationPlayState};});
          const data={text:(document.body.innerText||'').slice(0,4000),title:document.title.slice(0,200),
            appearance:{background:getComputedStyle(document.body).backgroundColor,color:getComputedStyle(document.body).color},
            animations:animated,canvas_count:nodes.filter(e=>e.tagName==='CANVAS').length,
            images:nodes.filter(e=>e.tagName==='IMG').slice(0,12).map(e=>({alt:(e.alt||'').slice(0,200),loaded:e.complete&&e.naturalWidth>0})),
            pending_writes:writing(),observed_at:Date.now()};
          NativeWork.postMessage(JSON.stringify({id:token,kind:'observation',data}));
        };
        // Read-only, bounded host inspection. The host owns comparison and proof;
        // page code never receives or supplies a restore-verification result.
        Object.defineProperty(window,'__workInspect',{value:(assertions)=>JSON.stringify({
          ready:document.readyState==='complete',
          pending_writes:Array.from(pending.values()).some(p=>p.kind!=='choose'),
          values:assertions.map(a=>{try{const n=document.querySelector(a.selector);
            if(!n)return {error:'missing_element'};
            const v=a.property==='text'?n.textContent:a.property==='value'?n.value:n.checked;
            if(typeof v!=='string'&&typeof v!=='boolean')return {error:'invalid_property'};
            if(typeof v==='string'&&v.length>1024)return {error:'value_too_large'};
            return {value:v};}catch(e){return {error:'invalid_selector'}}}),
          text:(document.body.innerText||'').slice(0,1800),nodes:document.body.children.length,
          errors:(window.__workErrors||[]).slice(0,12),
          elements:Array.from(document.querySelectorAll('button,input,[id]')).slice(0,24)
            .map(n=>({tag:n.tagName,id:n.id,text:(n.textContent||'').slice(0,100)}))})});
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
        val encoded = org.json.JSONArray().put(JSONObject.wrap(value)).toString().let { it.substring(1,it.length-1) }
        view.evaluateJavascript("window.__workReply(${JSONObject.quote(id)},$encoded,${error?.let(JSONObject::quote) ?: "null"})", null)
    }
}

/** Only scalar public state paths are accepted; never evaluate a model-supplied expression. */
private data class RestoreAssertion(val selector: String, val property: String, val path: String, val keys: List<String>) {
    fun stateValue(state: String): Any? {
        var value: Any? = runCatching { JSONArray("[$state]").get(0) }.getOrNull()
        for (key in keys) value = when (val parent = value) {
            is JSONObject -> if (parent.has(key)) parent.opt(key) else null
            is JSONArray -> key.toIntOrNull()?.let { if (it < parent.length()) parent.opt(it) else null }
            else -> null
        }
        return normalize(value)
    }
    fun normalize(value: Any?): Any? {
        if (property == "checked") return value as? Boolean
        val scalar = when (value) {
            is String -> value
            is Boolean -> value.toString()
            is Number -> JSONObject.numberToString(value)
            else -> return null
        }
        return scalar.takeIf { it.length <= 1024 }?.trim()?.replace(Regex("\\s+"), " ")
    }
    fun json() = JSONObject().put("selector", selector).put("property", property)
    fun diagnostic(index: Int, reason: String) = "恢复断言${index + 1} $reason ($selector / $path)"
    companion object {
        fun parse(raw: Map<String, String>): RestoreAssertion {
            val selector = raw["selector"].orEmpty()
            val property = raw["property"].orEmpty()
            val path = raw["state_path"].orEmpty()
            require(selector.isNotBlank() && selector.length <= 240) { "恢复断言 selector 无效" }
            require(property in listOf("text", "value", "checked")) { "恢复断言 property 无效" }
            val body = path.removePrefix("$.")
            require(path.length <= 160 && Regex("[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*|\\[(?:0|[1-9][0-9]{0,3})\\])*").matches(body)) { "恢复断言 state_path 无效" }
            val keys = Regex("[A-Za-z_][A-Za-z0-9_]*|[0-9]+").findAll(body).map { it.value }.toList()
            require(keys.size <= 8 && keys.none { it in listOf("__proto__", "prototype", "constructor") }) { "恢复断言路径过深或无效" }
            return RestoreAssertion(selector, property, path, keys)
        }
    }
}

/** Renders only app-owned content on a private virtual display. Never launches an Activity,
 * requests screen capture, mirrors the device display or creates a phone overlay. */
class CreativePreview(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var stop: (() -> Unit)? = null

    fun cancel() { handler.post { stop?.invoke() } }

    fun run(html: String, checks: List<Map<String, String>>,
            restoreAssertions: List<Map<String, String>> = emptyList(), requireRestore: Boolean = false,
            done: (Map<String, Any?>) -> Unit) {
        handler.post {
            if (stop != null) { done(mapOf("ok" to false,"errors" to listOf("预览正在使用"))); return@post }
            val errors = mutableListOf<String>()
            val checked = mutableListOf<String>()
            val sourceHash = MessageDigest.getInstance("SHA-256").digest(html.toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it.toInt() and 0xff) }
            var assertions = emptyList<RestoreAssertion>()
            var pageText = ""
            var elements = emptyList<Map<String,String>>()
            var chooseCount = 0
            var revealCount = 0
            var saveCount = 0
            var reloadCount = 0
            var previewState = "{}"
            var generation = 0
            var checkpointSeq = 0
            var reloadGeneration = 0
            var changedCount = 0
            var restoredCount = 0
            var baselineVerified = false
            var checkpointVerified = false
            var restoreVerified = false
            var phase = "baseline"
            var finished = false
            var page: WebView? = null
            var presentation: Presentation? = null
            var display: android.hardware.display.VirtualDisplay? = null
            var reader: ImageReader? = null
            var frame: Bitmap? = null
            var loaded = false
            var baselineValues = emptyList<Any?>()
            var baselineState = "{}"
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
                    if (colors.size < 2) errors.add("截图没有可确认的画面内容")
                    else runCatching {
                        val root = File(context.cacheDir,"creative_previews").apply { mkdirs() }
                        root.listFiles()?.filter { System.currentTimeMillis()-it.lastModified()>86_400_000 }?.forEach { it.delete() }
                        val target = File(root,"${UUID.randomUUID()}.png")
                        target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
                        screenshot = target.path
                    }.onFailure { errors.add("预览截图保存失败") }
                } else errors.add("没有收到实际渲染帧")
                page?.let { (it.parent as? ViewGroup)?.removeView(it); it.stopLoading(); it.destroy() }
                presentation?.dismiss(); display?.release(); reader?.close(); frame?.recycle()
                stop = null
                done(mapOf("ok" to (loaded && errors.isEmpty()),"errors" to errors.distinct(),"checks" to checked,"screenshot" to screenshot,"display" to "private_virtual",
                    "page_text" to pageText, "elements" to elements, "choose_count" to chooseCount, "reveal_count" to revealCount,
                    "save_count" to saveCount, "reload_count" to reloadCount,
                    "proof_version" to 2, "source_hash" to sourceHash, "restore_required" to (requireRestore || saveCount > 0),
                    "baseline_verified" to baselineVerified, "checkpoint_verified" to checkpointVerified,
                    "restore_verified" to restoreVerified, "save_seq" to checkpointSeq, "reload_generation" to reloadGeneration,
                    "assertion_count" to assertions.size, "changed_count" to changedCount, "restored_count" to restoredCount,
                    "proof_phase" to phase))
            }
            stop = { finish("预览已取消或超时 ($phase)") }
            handler.postDelayed(timeout,25_000)
            try {
                require(checks.size in 1..6) { "试玩需要1至6个检查" }
                require(restoreAssertions.size <= 4) { "恢复断言最多4个" }
                assertions = restoreAssertions.map { RestoreAssertion.parse(it) }
                if (requireRestore) require(assertions.isNotEmpty()) { "互动作品需要恢复断言" }
                val width=720; val height=1120
                reader=ImageReader.newInstance(width,height,PixelFormat.RGBA_8888,2)
                reader!!.setOnImageAvailableListener({ source ->
                    if (finished) return@setOnImageAvailableListener
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
                val previewChoices = mutableMapOf<String,String>()
                val previewOptions = mutableMapOf<String,List<String>>()
                val previewPlayers = mutableMapOf<String,String>()
                // A fresh WebView is a cold JavaScript world. Both the bridge closure and
                // evaluateJavascript callbacks retain its identity, so an old page cannot
                // save into, reply to, or verify a newer page even when its callback is queued.
                fun load(state: String) {
                    generation++
                    val owner = generation
                    page?.let { (it.parent as? ViewGroup)?.removeView(it); it.stopLoading(); it.destroy() }
                    lateinit var view: WebView
                    view=CreativeWebSandbox.create(presentation!!.context, onMessage@{ raw ->
                        if (finished || owner != generation || page !== view) return@onMessage
                        val message=runCatching { JSONObject(raw) }.getOrNull() ?: return@onMessage
                        val id=message.optString("id")
                        when(message.optString("kind")) {
                            "save" -> {
                                val value=message.opt("data")
                                if (!message.has("data") || value.toString().toByteArray(Charsets.UTF_8).size>40_000)
                                    CreativeWebSandbox.reply(view,id,null,"游玩进度无效或过大")
                                else {
                                    previewState=JSONArray().put(value).toString().let { it.substring(1,it.length-1) }
                                    saveCount++
                                    CreativeWebSandbox.reply(view,id,true)
                                }
                            }
                            "report", "describe" -> CreativeWebSandbox.reply(view,id,true)
                            "choose" -> {
                                val data=message.optJSONObject("data") ?: JSONObject()
                                val turn=CreativeWebSandbox.turnId(data.opt("turn"))
                                val options=CreativeWebSandbox.options(data.optJSONArray("options"))
                                if (turn == null || options == null) CreativeWebSandbox.reply(view,id,null,"无效回合或选项")
                                else if (previewOptions.containsKey(turn) && previewOptions[turn] != options) CreativeWebSandbox.reply(view,id,null,"不能更改已出招的回合")
                                else {
                                    if (!previewChoices.containsKey(turn)) chooseCount++
                                    previewChoices.putIfAbsent(turn,options.first()); previewOptions.putIfAbsent(turn,options)
                                    CreativeWebSandbox.reply(view,id,mapOf("committed" to true,"preview" to true))
                                }
                            }
                            "reveal" -> {
                                val data=message.optJSONObject("data") ?: JSONObject()
                                val turn=CreativeWebSandbox.turnId(data.opt("turn"))
                                val choice=previewChoices[turn]
                                val player=data.opt("playerChoice")
                                if (choice==null) CreativeWebSandbox.reply(view,id,null,"还没有出招")
                                else if (player !is String || previewOptions[turn]?.contains(player) != true) CreativeWebSandbox.reply(view,id,null,"无效的玩家选择")
                                else {
                                    if (!previewPlayers.containsKey(turn!!)) revealCount++
                                    previewPlayers.putIfAbsent(turn,player)
                                    CreativeWebSandbox.reply(view,id,mapOf("choice" to choice,"playerChoice" to previewPlayers[turn],"preview" to true))
                                }
                            }
                            else -> CreativeWebSandbox.reply(view,id,null,"未知作品接口")
                        }
                    }, { if (!finished && owner == generation) errors.add(it) })
                    page=view
                    presentation!!.setContentView(view)
                    if (!presentation!!.isShowing) presentation!!.show()
                    view.loadDataWithBaseURL(CreativeWebSandbox.ORIGIN,CreativeWebSandbox.document(html,state,true),"text/html","UTF-8",null)
                }
                fun remember(data: JSONObject) {
                    loaded=data.optInt("nodes")>1 && (data.optString("text").isNotBlank() || html.contains("canvas"))
                    pageText=data.optString("text")
                    val nodes=data.optJSONArray("elements") ?: JSONArray()
                    elements=(0 until nodes.length()).map { i ->
                        val node=nodes.optJSONObject(i) ?: JSONObject()
                        mapOf("tag" to node.optString("tag"), "id" to node.optString("id"), "text" to node.optString("text"))
                    }
                    val js=data.optJSONArray("errors") ?: JSONArray()
                    for(i in 0 until js.length()) errors.add(js.getString(i))
                }
                fun values(data: JSONObject): List<Any?> {
                    val items=data.optJSONArray("values") ?: JSONArray()
                    return assertions.mapIndexed { i, a -> a.normalize(items.optJSONObject(i)?.opt("value")) }
                }
                // Poll actual DOM + bridge public-write state until two readings agree.
                // No fixed delay may turn a still-pending save into a checkpoint.
                fun settle(callback: (JSONObject) -> Unit) {
                    val owner=generation
                    val view=page!!
                    var previous: String? = null
                    fun poll(remaining: Int) {
                        if (finished || owner != generation || page !== view) return
                        val args=JSONArray(assertions.map { it.json() }).toString()
                        view.evaluateJavascript("window.__workInspect && window.__workInspect($args)") { encoded ->
                            if (finished || owner != generation || page !== view) return@evaluateJavascript
                            val data=runCatching { JSONObject(JSONArray("[$encoded]").getString(0)) }.getOrNull()
                            val stableKey=data?.optJSONArray("values").toString()+":"+saveCount
                            if (data != null && frame != null && data.optBoolean("ready") && !data.optBoolean("pending_writes") && previous == stableKey) {
                                remember(data); callback(data)
                            } else if (remaining == 0) finish("页面或公开保存尚未稳定 ($phase)")
                            else {
                                previous=if (data != null && data.optBoolean("ready") && !data.optBoolean("pending_writes")) stableKey else null
                                handler.postDelayed({ poll(remaining-1) },200)
                            }
                        }
                    }
                    poll(20)
                }
                fun checkpoint() {
                    phase="checkpoint"
                    settle { data ->
                        if (!requireRestore && saveCount == 0) { phase="stateless"; finish(); return@settle }
                        if (assertions.isEmpty()) { finish("保存了进度的作品需要 restore_assertions"); return@settle }
                        if (saveCount == 0) { finish("没有成功保存的恢复点"); return@settle }
                        val saved=previewState
                        checkpointSeq=saveCount
                        val before=values(data)
                        assertions.forEachIndexed { i, a ->
                            val value=before[i]
                            val state=a.stateValue(saved)
                            if (value == null || state == null || value != state) errors.add(a.diagnostic(i,"与已保存的公开标量不一致或字段不存在"))
                            else if (value != baselineValues.getOrNull(i) && state != a.stateValue(baselineState) && value != "") changedCount++
                        }
                        if (changedCount == 0) errors.add("恢复断言没有验证实际状态变化，常量标题或空值不能证明恢复")
                        if (errors.isNotEmpty()) { finish(); return@settle }
                        checkpointVerified=true
                        phase="restore"
                        reloadCount++
                        load(saved)
                        reloadGeneration=generation
                        settle { after ->
                            val restored=values(after)
                            assertions.forEachIndexed { i, a ->
                                if (restored[i] == before[i] && restored[i] == a.stateValue(saved) &&
                                    a.stateValue(previewState) == a.stateValue(saved)) restoredCount++
                                else errors.add(a.diagnostic(i,"冷重载后未恢复，恢复阶段不会再次点击"))
                            }
                            restoreVerified=restoredCount == assertions.size && errors.isEmpty()
                            if (restoreVerified) phase="restored"
                            // Finish on the same main-thread decision as the proof.
                            // No later write can change its snapshot while awaiting a screenshot.
                            finish()
                        }
                    }
                }
                fun inspect(index: Int) {
                    if (finished) return
                    if (index >= checks.size) { checkpoint(); return }
                    val step=checks[index]
                    if (step["reload"]=="true") { reloadCount++; load(previewState) }
                    fun interact() {
                        if(finished)return
                        val owner=generation
                        val view=page!!
                        val click=JSONObject.quote(step["click"].orEmpty())
                        val selector=JSONObject.quote(step["selector"].orEmpty())
                        val text=JSONObject.quote(step["text"].orEmpty())
                        view.evaluateJavascript("(()=>{try{const s=$click;if(s){const n=document.querySelector(s);if(!n)return 'missing_click';n.click();}return 'clicked';}catch(e){return 'invalid_click'}})()") { value ->
                            if(finished || owner != generation || page !== view)return@evaluateJavascript
                            if(value!="\"clicked\"") errors.add("交互检查${index+1}: $value")
                            fun verify(remaining: Int) {
                                if(finished || owner != generation)return
                                view.evaluateJavascript("(()=>{try{const s=$selector;if(!s)return false;const n=document.querySelector(s);return !!n&&n.textContent.includes($text);}catch(e){return false}})()") { answer ->
                                    if(finished || owner != generation || page !== view)return@evaluateJavascript
                                    if(answer!="true" && remaining>0) handler.postDelayed({ verify(remaining-1) },250)
                                    else {
                                        if(answer=="true") checked.add("step:${index+1}") else errors.add("交互检查${index+1}未通过：${step["selector"]}")
                                        settle { inspect(index+1) }
                                    }
                                }
                            }
                            handler.postDelayed({ verify(7) },250)
                        }
                    }
                    if (step["reload"]=="true") settle { interact() } else interact()
                }
                load("{}")
                settle { data ->
                    baselineValues=values(data)
                    baselineState=previewState
                    assertions.forEachIndexed { i, a ->
                        if (baselineValues[i] == null) errors.add(a.diagnostic(i,"初始页面缺少可读取的标量"))
                    }
                    baselineVerified=errors.isEmpty()
                    if (!baselineVerified) finish() else { phase="exercise"; inspect(0) }
                }
            } catch(error: Exception) { finish("独立预览不可用：${error.message?.take(240) ?: error.javaClass.simpleName}") }
        }
    }
}
