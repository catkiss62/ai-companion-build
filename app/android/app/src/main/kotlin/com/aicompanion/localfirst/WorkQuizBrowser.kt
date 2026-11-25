package com.aicompanion.localfirst

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
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
    private var browser: WebView? = null
    private var owner: String? = null
    private val main = Handler(Looper.getMainLooper())
    private val origin = "work-quiz.invalid"
    private val site = "zodiacgalore.com"
    private val quizPath = Regex("/quizzes/[a-z0-9-]{1,80}/")

    fun close() {
        browser?.let {
            (it.parent as? ViewGroup)?.removeView(it)
            it.stopLoading()
            it.destroy()
        }
        browser = null
        owner = null
    }

    interface Reply {
        fun success(value: String?)
        fun error(code: String, message: String)
    }

    fun handle(method: String, args: Map<*, *>, result: Reply) {
        val id = (args["id"] as? String) ?: ""
        if (id.isEmpty()) { result.error("quiz_session", "答题会话无效"); return }
        if (method == "workQuizOpen") {
            val url = Uri.parse((args["url"] as? String) ?: "")
            val path = url.encodedPath ?: ""
            if (url.scheme != "https" || url.encodedAuthority != site || !quizPath.matches(path)) {
                result.error("quiz_site", "当前支持 Zodiac Galore 的公开短测验"); return
            }
            if (owner != null && owner != id) { result.error("quiz_busy","另一场答题正在进行"); return }
            close()
            val view = WebView(activity)
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
            view.setLayerType(View.LAYER_TYPE_SOFTWARE, null)
            val root = activity.findViewById<ViewGroup>(android.R.id.content)
            val w = (400 * activity.resources.displayMetrics.density).toInt().coerceIn(480, 1200)
            val h = w * 3 / 2
            root.addView(view, 0, ViewGroup.LayoutParams(w, h))
            // Keep it physically outside the interactive window, including on transparent activities.
            view.translationX = -w.toFloat() - 1
            view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
            view.layout(0, 0, w, h)
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
                    } else main.postDelayed({
                        if (browser !== view) result.error("quiz_closed","答题页面已关闭")
                        else try { result.success(capture(view)) }
                        catch (e: Exception) { result.error("quiz_capture","截图保存失败") }
                    }, 250)
                }
            }
            else -> result.error("quiz_method","无法识别的网页操作")
        }
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

    private fun capture(view: WebView): String {
        var width = view.width.coerceAtMost(800)
        while (width >= 260) {
            val bitmap = Bitmap.createBitmap(width, width * view.height / view.width, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.drawColor(android.graphics.Color.WHITE)
            canvas.scale(width.toFloat()/view.width,width.toFloat()/view.width)
            view.draw(canvas)
            val colors = mutableSetOf<Int>()
            for (y in 0 until bitmap.height step 5) {
                for (x in 0 until bitmap.width step 5) colors.add(bitmap.getPixel(x,y))
                if (colors.size > 3) break
            }
            if (colors.size < 2) {
                bitmap.recycle()
                throw IllegalStateException("尚未绘制结果页面")
            }
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            if (out.size() <= 256*1024) return Base64.encodeToString(out.toByteArray(),Base64.NO_WRAP)
            width = width * 3 / 4
        }
        throw IllegalStateException("截图过大")
    }
}
