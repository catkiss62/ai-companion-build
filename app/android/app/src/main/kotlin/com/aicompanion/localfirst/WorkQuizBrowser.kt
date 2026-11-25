package com.aicompanion.localfirst

import android.app.Activity
import android.graphics.Bitmap
import android.app.Presentation
import android.content.Context
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject
import org.json.JSONTokener
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** Guest browser for the four public, client-side Zodiac Galore quizzes.
 * The private origin serves only the requested document and its theme assets.
 * It never shares page credentials or navigates an Android app or browser. */
internal class WorkQuizBrowser(private val activity: Activity, private val readResource: ((String) -> WebResourceResponse)? = null) {
    private var publicPage: WorkPublicPage? = null
    private var browser: WebView? = null
    private var owner: String? = null
    private var screen: VirtualDisplay? = null
    private var window: Presentation? = null
    private var reader: ImageReader? = null
    private var captureRequest: Reply? = null
    private val frameWidth = 720
    private val frameHeight = 1080
    private val main = Handler(Looper.getMainLooper())
    private val origin = "work-quiz.invalid"
    private val site = "zodiacgalore.com"
    private val quizPath = Regex("/quizzes/[a-z0-9-]{1,80}/")

    fun close() {
        val page = publicPage
        val view = browser
        val request = captureRequest
        val presentation = window
        val display = screen
        val frames = reader
        owner = null
        publicPage = null
        browser = null
        captureRequest = null
        window = null
        screen = null
        reader = null
        fun release(block: () -> Unit) {
            try { block() } catch (e: Exception) { android.util.Log.w("WorkQuiz", "网页资源释放失败", e) }
        }
        release { page?.close() }
        release { request?.error("quiz_closed","答题页面已关闭") }
        release { (view?.parent as? ViewGroup)?.removeView(view) }
        release { view?.stopLoading() }
        release { view?.destroy() }
        release { presentation?.dismiss() }
        release { display?.release() }
        release { frames?.close() }
    }

    interface Reply {
        fun success(value: String?)
        fun error(code: String, message: String)
    }

    fun handle(method: String, args: Map<*, *>, result: Reply) {
        val id = (args["id"] as? String) ?: ""
        if (id.isEmpty()) { result.error("quiz_session", "答题会话无效"); return }
        if (method == "workQuizOpen" || method == "workPageOpen") {
            val url = Uri.parse((args["url"] as? String) ?: "")
            val path = url.encodedPath ?: ""
            if (if (method == "workPageOpen") !WorkPublicPage.allowed(url) else url.scheme != "https" || url.encodedAuthority != site || !quizPath.matches(path)) {
                result.error("quiz_site", "请使用公开 HTTPS 网页"); return
            }
            if (owner != null && owner != id) { result.error("quiz_busy","另一场答题正在进行"); return }
            close()
            val view = try {
                createScreen()
            } catch (e: Exception) {
                close()
                result.error("quiz_display","无法建立独立答题画面")
                return
            }
            browser = view
            owner = id
            view.settings.apply {
                javaScriptEnabled = true
                allowFileAccess = false
                allowContentAccess = false
                domStorageEnabled = false
                offscreenPreRaster = true
                javaScriptCanOpenWindowsAutomatically = false
                setGeolocationEnabled(false)
                cacheMode = android.webkit.WebSettings.LOAD_NO_CACHE
            }
            view.isFocusable = false
            view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            if (method == "workPageOpen") {
                val page = WorkPublicPage(view, requireNotNull(url.host),readResource) { captureFrame(view,it) }
                publicPage = page
                page.open(url)
                page.handle(method,args,result)
                return
            }
            view.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(v: WebView, r: WebResourceRequest) = true
                override fun shouldInterceptRequest(v: WebView, r: WebResourceRequest): WebResourceResponse {
                    val uri = r.url
                    val p = uri.encodedPath ?: ""
                    if (r.method != "GET" || uri.scheme != "https" ||
                        uri.encodedAuthority !in setOf(origin, site) || p.contains('%') || p.contains("..") ||
                        !(r.isForMainFrame && p == path || !r.isForMainFrame &&
                          (p.startsWith("/wp-content/themes/zodiac/") || p.startsWith("/wp-includes/css/")) &&
                          Regex("[a-zA-Z0-9/_-]+[.a-zA-Z0-9_-]*[.](js|css|woff2?|png|svg|webp|jpe?g)").matches(p))) return blocked()
                    return readResource?.invoke(p) ?: resource(p)
                }
            }
            view.loadUrl("https://$origin$path")
            poll(view, result, null, 160)
            return
        }
        val view = browser
        if (owner != id || view == null) {
            if (method == "workQuizClose") result.success(null)
            else result.error("quiz_closed","答题页面已关闭")
            return
        }
        if(method.startsWith("workPage") && publicPage != null){ publicPage!!.handle(method,args,result); return }
        when (method) {
            "workQuizClose" -> { close(); result.success(null) }
            "workQuizChoose" -> {
                val question = JSONObject.quote((args["question"] as? String) ?: "")
                val label = JSONObject.quote((args["label"] as? String) ?: "")
                val index = (args["index"] as? Int) ?: -1
                view.evaluateJavascript("""(function(){
                  var q=document.querySelector('.zdc-quiz-q'), a=document.querySelectorAll('.zdc-quiz-answers button')[$index];
                  if(!q || q.innerText.trim()!==$question || !a || a.innerText.trim()!==$label) return false;
                  a.click(); return true;
                })()""") { ok ->
                    if (ok != "true") result.error("quiz_changed","题目或选项发生变化")
                    else poll(view, result, (args["question"] as? String), 60)
                }
            }
            "workQuizCapture" -> {
                view.evaluateJavascript("""(function(){
                  var e=document.querySelector('.zdc-quiz-result-name');
                  if(!e || !e.innerText.trim()) return '';
                  var panel=e.closest('.zdc-quiz-result')||e.parentElement;
                  panel.scrollIntoView({block:'start',behavior:'instant'});
                  return e.innerText.trim();
                })()""") { raw ->
                    val title = runCatching { JSONTokener(raw).nextValue() as? String }.getOrNull()
                    if (title.isNullOrEmpty() || title != (args["title"] as? String)) {
                        result.error("quiz_result","网页尚未显示该结果")
                    } else {
                        // Wait for the scrolled result to reach the compositor. A software
                        // draw of a long WebView can be empty outside its initial tiles.
                        captureFrame(view,result)
                    }
                }
            }
            else -> result.error("quiz_method","无法识别的网页操作")
        }
    }

    private fun captureFrame(view:WebView,result:Reply) {
        captureRequest = result
        val surface = window?.window
        if(surface == null){
            captureRequest=null
            result.error("quiz_display","独立网页窗口已关闭")
            return
        }
        // PixelCopy reads the most recently submitted window buffer. A WebView
        // visual-state callback promises its *next* draw includes the DOM update.
        // Wait for that draw and the following presentation before requesting it.
        fun copy(attempt:Int){
            if(browser !== view || captureRequest !== result)return
            val bitmap=Bitmap.createBitmap(frameWidth,frameHeight,Bitmap.Config.ARGB_8888)
            try {
                android.view.PixelCopy.request(surface,bitmap,{ status ->
                    try {
                        if(browser !== view || captureRequest !== result)return@request
                        val encoded=if(status==android.view.PixelCopy.SUCCESS) encodeFrame(bitmap) else null
                        if(encoded!=null){
                            captureRequest=null
                            result.success(encoded)
                        } else if(attempt<8){
                            view.invalidate()
                            main.postDelayed({ copy(attempt+1) },100)
                        } else {
                            captureRequest=null
                            result.error("quiz_capture","独立网页没有返回可读取的结果画面")
                        }
                    } catch(e:Exception){
                        captureRequest=null
                        result.error("quiz_capture",e.message ?: "网页截图失败")
                    } finally { bitmap.recycle() }
                },main)
            }catch(e:Exception){
                bitmap.recycle()
                captureRequest=null
                result.error("quiz_capture","无法读取独立网页窗口")
            }
        }
        view.postVisualStateCallback(1L,object:WebView.VisualStateCallback(){
            override fun onComplete(requestId:Long){
                if(browser !== view || captureRequest !== result)return
                view.invalidate()
                view.postOnAnimation { view.postOnAnimation { main.postDelayed({copy(0)},120) } }
            }
        })
        main.postDelayed({
            if(captureRequest===result){
                captureRequest=null
                result.error("quiz_capture","网页结果仍未绘制完成")
            }
        },6000)
    }

    private fun blocked() = WebResourceResponse("text/plain","utf-8",403,"Blocked",emptyMap(),ByteArrayInputStream(byteArrayOf()))
    private fun resource(path: String): WebResourceResponse {
        val c = URL("https://$site$path").openConnection() as HttpsURLConnection
        try {
            c.instanceFollowRedirects = false
            c.connectTimeout = 7000
            c.readTimeout = 9000
            c.useCaches = false
            if (c.responseCode != 200) return blocked()
            val out = ByteArrayOutputStream()
            c.inputStream.use { input ->
                val buf = ByteArray(8192)
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    if (out.size() + n > 1500000) return blocked()
                    out.write(buf, 0, n)
                }
            }
            val csp = "default-src 'none'; script-src 'self' https://$site 'unsafe-inline'; style-src 'self' https://$site 'unsafe-inline'; img-src 'self' https://$site data:; font-src 'self' https://$site; form-action 'none'; base-uri 'none'; frame-src 'none'; connect-src 'none'"
            return WebResourceResponse(c.contentType?.substringBefore(';') ?: "text/plain", "utf-8", 200,"OK",
                mapOf("Content-Security-Policy" to csp,"Access-Control-Allow-Origin" to "*","Cache-Control" to "no-store"),
                ByteArrayInputStream(out.toByteArray()))
        } catch (_: Exception) { return blocked() }
        finally { c.disconnect() }
    }

    private fun poll(v: WebView, reply: Reply, previous: String?, left: Int) {
        if (browser !== v) { reply.error("quiz_closed","答题页面已关闭"); return }
        v.evaluateJavascript("""(function(){
          var t=document.querySelector('.zdc-quiz-result-name'), s=document.querySelector('.zdc-quiz-result-summary');
          if(t && t.innerText.trim()) return JSON.stringify({title:t.innerText.trim(),summary:s?s.innerText.trim():''});
          var q=document.querySelector('.zdc-quiz-q'), a=Array.from(document.querySelectorAll('.zdc-quiz-answers button'));
          if(q && a.length>=2 && a.length<=12) return JSON.stringify({question:q.innerText.trim(),options:a.map(x=>x.innerText.trim())});
          return '';
        })()""") { raw ->
            val state = runCatching { JSONObject(JSONTokener(raw).nextValue() as String) }.getOrNull()
            if (state != null && (previous == null || state.optString("question") != previous)) reply.success(state.toString())
            else if (left == 0) reply.error("quiz_timeout","未能读到下一题或结果，请检查网络和网页")
            else main.postDelayed({ poll(v,reply,previous,left-1) },150)
        }
    }

    private fun createScreen(): WebView {
        val frames = ImageReader.newInstance(frameWidth,frameHeight,PixelFormat.RGBA_8888,3)
        reader = frames
        frames.setOnImageAvailableListener({ source ->
            if (reader !== source) return@setOnImageAvailableListener
            source.acquireLatestImage()?.close()
        },main)
        val manager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = requireNotNull(manager.createVirtualDisplay("WorkQuiz",frameWidth,frameHeight,320,frames.surface,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY or DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION))
        screen = display
        val presentation = Presentation(activity,display.display)
        window = presentation
        val view = WebView(presentation.context)
        presentation.setContentView(view)
        presentation.show()
        return view
    }

    private fun encodeFrame(source: Bitmap): String? {
        val first = source.getPixel(0,0)
        val drawn = (0 until frameHeight step 5).any { y ->
            (0 until frameWidth step 5).any { x -> source.getPixel(x,y) != first }
        }
        if (!drawn) return null
        val cropped = Bitmap.createBitmap(source,0,0,frameWidth,frameHeight)
        try {
            var w = frameWidth
            while(w >= 260) {
                val image = Bitmap.createScaledBitmap(cropped,w,w*frameHeight/frameWidth,true)
                val out = ByteArrayOutputStream()
                try { image.compress(Bitmap.CompressFormat.PNG,100,out) }
                finally { if(image !== cropped) image.recycle() }
                if(out.size() <= 256*1024) return Base64.encodeToString(out.toByteArray(),Base64.NO_WRAP)
                w = w*3/4
            }
            throw IllegalStateException("结果截图超过文件大小限制")
        } finally { if(cropped !== source) cropped.recycle() }
    }
}
