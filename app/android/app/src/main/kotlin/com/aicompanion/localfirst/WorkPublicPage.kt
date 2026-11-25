package com.aicompanion.localfirst

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import okhttp3.Dns
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/** A fresh, uncredentialed origin for each work task. All network resolution
 * and reads use the guest client, including scripts and same-site navigation. */
internal class WorkPublicPage(private val view: WebView, val host: String,
    private val fixture: ((String) -> WebResourceResponse)? = null,
    private val frame: (WorkQuizBrowser.Reply) -> Unit) {
    private val guest = "work-${UUID.randomUUID()}.invalid"
    private val handler = Handler(Looper.getMainLooper())
    private val script = view.context.assets.open("work_page.js").bufferedReader().use { it.readText() }
    private var active = true
    @Volatile private var problem = ""
    private var pending: WorkQuizBrowser.Reply? = null
    private val client = OkHttpClient.Builder().dns(object : Dns {
        override fun lookup(hostname: String): List<InetAddress> {
            check(hostname == host)
            val public = InetAddress.getAllByName(hostname).filter {
                val a=it.address.map { b -> b.toInt() and 255 }
                if(it is Inet6Address) return@filter a[0] in 0x20..0x3f && !(a.take(4)==listOf(0x20,1,0xd,0xb8))
                it is Inet4Address && !(it.isLoopbackAddress || it.isLinkLocalAddress || it.isSiteLocalAddress || it.isMulticastAddress ||
                    a[0] == 0 || a[0] >= 224 || a[0]==100 && a[1] in 64..127 ||
                    a[0]==198 && a[1] in 18..19 || a[0]==192 && a[1]==0)
            }
            if(public.isEmpty()) throw UnknownHostException("没有可用的公网地址")
            return public
        }
    }).proxy(java.net.Proxy.NO_PROXY).followRedirects(false).followSslRedirects(false)
      .callTimeout(15, TimeUnit.SECONDS).build()

    companion object {
        fun allowed(uri: Uri) = uri.scheme=="https" && uri.host!=null && uri.encodedAuthority==uri.host &&
            Regex("(?=.{4,253}$)([a-z0-9-]+\\.)+[a-z]{2,63}").matches(uri.host!!) &&
            !uri.host!!.endsWith(".local") && !uri.host!!.endsWith(".localhost") && !uri.host!!.endsWith(".invalid")
    }

    private fun blocked() = WebResourceResponse("text/plain","utf-8",403,"Unavailable",emptyMap(),ByteArrayInputStream(byteArrayOf()))
    private fun guestUrl(uri: Uri) = uri.buildUpon().encodedAuthority(guest).build().toString()
    fun open(uri: Uri) {
        view.webViewClient=object:WebViewClient(){
            override fun shouldOverrideUrlLoading(v:WebView,r:WebResourceRequest):Boolean {
                if(r.url.scheme=="https" && r.url.encodedAuthority in setOf(guest,host)){
                    if(r.url.host==host){v.loadUrl(guestUrl(r.url));return true}
                    return false
                }
                if(r.isForMainFrame) problem=if(r.url.scheme!="https") "网页要求打开其他应用" else "页面需要跳往其他网站"
                return true
            }
            override fun shouldInterceptRequest(v:WebView,r:WebResourceRequest):WebResourceResponse {
                val uri=r.url
                if(r.method!="GET" || uri.scheme!="https" || uri.encodedAuthority !in setOf(guest,host))return blocked()
                try {
                    fixture?.let { return it(uri.encodedPath ?: "/") }
                    var real=uri.buildUpon().encodedAuthority(host).fragment(null).build().toString()
                    repeat(4) {
                        val request=Request.Builder().url(real).header("User-Agent",userAgent).build()
                        client.newCall(request).execute().use { res ->
                            if(res.isRedirect){
                                val next=res.request.url.resolve(res.header("Location") ?: return blocked()) ?: return blocked()
                                if(!next.isHttps || next.host!=host || next.port!=443 || next.username!="" || next.password!=""){
                                    if(r.isForMainFrame) problem="网页要求跳转到其他地址"
                                    return blocked()
                                }
                                real=next.toString()
                            }else{
                                if(!res.isSuccessful){if(r.isForMainFrame) problem="网页返回 HTTP ${res.code}";return blocked()}
                                val body=res.body ?: return blocked()
                                val src=body.source()
                                if(src.request(4L*1024*1024+1))return blocked()
                                val type=body.contentType()
                                val csp="default-src 'none'; script-src 'self' https://$host 'unsafe-inline'; style-src 'self' https://$host 'unsafe-inline'; img-src 'self' https://$host data: blob:; font-src 'self' https://$host data:; connect-src 'self' https://$host; worker-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'; object-src 'none'"
                                return WebResourceResponse(type?.let{"${it.type}/${it.subtype}"} ?: "application/octet-stream",
                                    type?.charset()?.name() ?: "utf-8",200,"OK",mapOf("Content-Security-Policy" to csp,
                                    "Access-Control-Allow-Origin" to "https://$guest","Cache-Control" to "no-store"),
                                    ByteArrayInputStream(src.readByteArray()))
                            }
                        }
                    }
                }catch(_:Exception){if(r.isForMainFrame) problem="未能加载网页，请检查网络或网址"}
                return blocked()
            }
        }
        view.loadUrl(guestUrl(uri))
    }
    private val userAgent=view.settings.userAgentString
    fun close(){
        active=false
        pending?.error("page_closed","网页任务已结束"); pending=null
        Thread({
            client.dispatcher.cancelAll()
            client.connectionPool.evictAll()
        }, "WorkPageClose").start()
    }
    private fun eval(command:String,arg:JSONObject, callback:(Any?)->Unit){
        if(!active)return
        arg.put("host",host)
        view.evaluateJavascript("$script(${JSONObject.quote(command)},$arg)") { raw ->
            if(active)callback(runCatching { JSONTokener(raw).nextValue() }.getOrNull())
        }
    }
    fun handle(method:String,args:Map<*,*>,reply:WorkQuizBrowser.Reply){
        if(pending!=null){reply.error("page_busy","网页正在更新");return}
        pending=reply
        val once=object:WorkQuizBrowser.Reply{
            override fun success(value:String?){if(pending===reply){pending=null;reply.success(value)}}
            override fun error(code:String,message:String){if(pending===reply){pending=null;reply.error(code,message)}}
        }
        val arg=JSONObject()
        args.forEach{(k,v)->if(k is String && v!=null)arg.put(k,JSONObject.wrap(v))}
        when(method){
            "workPageOpen","workPageRead" -> {
                fun poll(left:Int) {
                    if(problem.isNotEmpty()){once.error("page_unavailable",problem);return}
                    eval("read",arg){raw->
                        val state=raw as? JSONObject
                        val loaded=state!=null && state.optString("excerpt").isNotBlank() && state.optString("page")!="blank"
                        val changed=arg.optString("previous").let{it.isEmpty() || it!=state?.optString("key")}
                        if(loaded && (changed || left==0))once.success(state.toString())
                        else if(left==0)once.error("page_load","网页没有出现可读内容")
                        else handler.postDelayed({poll(left-1)},200)
                    }
                }
                poll(if(method=="workPageOpen")95 else 12)
            }
            "workPageAct" -> eval("act",arg){v->
                val url=Uri.parse(v as? String ?: "")
                if(allowed(url) && url.host==host)view.loadUrl(guestUrl(url))
                once.success(v as? String ?: "miss")
            }
            "workPageFrame" -> eval("focus",arg){frame(once)}
            "workPageResult" -> capture(arg,once)
            else->once.error("page_method","未知网页操作")
        }
    }
    private fun capture(arg:JSONObject,reply:WorkQuizBrowser.Reply){
        val parts=JSONArray()
        val tiles=mutableListOf<Bitmap>()
        fun flush(){
            if(tiles.isEmpty())return
            val bitmap=Bitmap.createBitmap(tiles.maxOf{it.width},tiles.sumOf{it.height},Bitmap.Config.ARGB_8888)
            try{
                val canvas=Canvas(bitmap)
                var top=0
                for(tile in tiles){canvas.drawBitmap(tile,0f,top.toFloat(),null);top+=tile.height}
                val output=ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG,100,output)
                if(output.size()<=256*1024)parts.put(Base64.encodeToString(output.toByteArray(),Base64.NO_WRAP))
                else for(tile in tiles){
                    output.reset();tile.compress(Bitmap.CompressFormat.PNG,100,output)
                    check(output.size()<=256*1024){"截图分段过大"}
                    parts.put(Base64.encodeToString(output.toByteArray(),Base64.NO_WRAP))
                }
            }finally{bitmap.recycle();tiles.forEach{it.recycle()};tiles.clear()}
        }
        fun tile(offset:Int,count:Int){
            eval("tile",arg.put("offset",offset)){raw->
                val pos=raw as? JSONObject
                if(pos==null || count>=24){tiles.forEach{it.recycle()};reply.error("page_capture","结果区域无法完整截取");return@eval}
                frame(object:WorkQuizBrowser.Reply{
                    override fun error(code:String,message:String){tiles.forEach{it.recycle()};reply.error(code,message)}
                    override fun success(value:String?){
                        try{
                            val data=Base64.decode(value,Base64.DEFAULT)
                            val full=BitmapFactory.decodeByteArray(data,0,data.size)
                            val x=(pos.getDouble("x")*full.width).roundToInt().coerceIn(0,full.width-1)
                            val y=(pos.getDouble("y")*full.height).roundToInt().coerceIn(0,full.height-1)
                            val w=(pos.getDouble("w")*full.width).roundToInt().coerceIn(1,full.width-x)
                            val h=(pos.getDouble("h")*full.height).roundToInt().coerceIn(1,full.height-y)
                            val crop=Bitmap.createBitmap(full,x,y,w,h)
                            if(crop!==full) full.recycle()
                            tiles.add(crop)
                            if(tiles.sumOf{it.height}>3600 || pos.getBoolean("done"))flush()
                            if(pos.getBoolean("done"))reply.success(parts.toString()) else tile(pos.getInt("offset"),count+1)
                        }catch(e:Exception){tiles.forEach{it.recycle()};reply.error("page_capture",e.message ?: "结果截图失败")}
                    }
                })
            }
        }
        fun card(left:Int) {
            eval("card",arg){raw->
                if(raw is String && raw.length in 44..349520)reply.success(JSONArray().put(raw).toString())
                else if(left>0)handler.postDelayed({card(left-1)},200)
                else tile(0,0)
            }
        }
        card(4)
    }
}
