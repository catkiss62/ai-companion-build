package com.catkiss.senlive2dcompanion.smoke

import android.graphics.BitmapFactory
import android.util.Base64
import android.webkit.WebResourceResponse
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.aicompanion.localfirst.WorkQuizBrowser
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class WorkQuizBrowserTest {
    @Test fun publicWebsiteUsesFiveRealChoicesAndAResult() {
        val assets=InstrumentationRegistry.getInstrumentation().context.assets
        assumeTrue("Public website unavailable during checkout", assets.list("work-quiz")?.contains("portal.js")==true)
        exercise(assets.open("work-quiz/page.html").bufferedReader().use { it.readText() },
            assets.open("work-quiz/portal.js").bufferedReader().use { it.readText() })
    }

    @Test fun choicesAdvanceTheDomAndCaptureItsActualResult() {
        val html = """<meta name="viewport" content="width=device-width,initial-scale=1">
            <body style="margin:0"><h2 class="zdc-quiz-q"></h2><div class="zdc-quiz-answers"></div>
            <script>let n=1,s=0;function render(){document.querySelector('h2').textContent='Q'+n;
            document.querySelector('div').innerHTML='<button>A</button><button>B</button>';
            document.querySelectorAll('button').forEach((b,i)=>b.onclick=()=>{s+=i;if(++n<=5)render();
            else document.body.innerHTML='<div class="zdc-quiz-result" style="background:#8433ac;height:900px">'+
            '<h2 class="zdc-quiz-result-name">Score '+s+'</h2><p class="zdc-quiz-result-summary">Done</p></div>'})}
            render()</script>"""
        exercise(html,null)
    }

    private fun exercise(html:String, portal:String?) {
        ActivityScenario.launch(ReminderCardSmokeActivity::class.java).use { scenario ->
            lateinit var browser: WorkQuizBrowser
            scenario.onActivity { browser=WorkQuizBrowser(it) { path ->
                when {
                    path.startsWith("/quizzes/") -> WebResourceResponse("text/html","utf-8",html.byteInputStream())
                    path.endsWith("/portal-tools.js") && portal!=null -> WebResourceResponse("application/javascript","utf-8",portal.byteInputStream())
                    else -> WebResourceResponse("text/plain","utf-8","".byteInputStream())
                }
            } }
            fun call(method:String, params:Map<String,Any> = emptyMap()):String {
                val future=CompletableFuture<String>()
                scenario.onActivity {
                    browser.handle(method,params + ("id" to "test"),object: WorkQuizBrowser.Reply {
                        override fun success(value:String?) { future.complete(value ?: "") }
                        override fun error(code:String,message:String) { future.completeExceptionally(AssertionError(message)) }
                    })
                }
                return future.get(35,TimeUnit.SECONDS)
            }
            try {
                var state=JSONObject(call("workQuizOpen",mapOf("url" to "https://zodiacgalore.com/quizzes/which-element/")))
                val seen=mutableSetOf<String>()
                repeat(5) { i ->
                    if (portal==null) assertEquals("Q${i+1}",state.getString("question"))
                    assertTrue(seen.add(state.getString("question")))
                    val index=i%2
                    state=JSONObject(call("workQuizChoose",mapOf("question" to state.getString("question"),
                        "index" to index,"label" to state.getJSONArray("options").getString(index))))
                }
                val title=state.getString("title")
                assertTrue(title.isNotBlank())
                if(portal==null) assertEquals("Score 2",title)
                android.util.Log.i("WorkQuizSmoke","questions=${seen.size}, result=$title")
                val png=Base64.decode(call("workQuizCapture",mapOf("title" to title)),Base64.DEFAULT)
                val bitmap=BitmapFactory.decodeByteArray(png,0,png.size)
                assertNotNull(bitmap)
                if(portal==null) assertEquals(0xff8433ac.toInt(),bitmap.getPixel(bitmap.width/2,bitmap.height/2))
            } finally { call("workQuizClose") }
        }
    }
}
