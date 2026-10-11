package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.aicompanion.localfirst.CreativePreview
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class CreativePreviewSmokeTest {
    private val context=ApplicationProvider.getApplicationContext<Context>()
    private val html="""<style>body{background:#13284a;color:#ffffff;font:24px sans-serif;padding:24px}button{background:#f8c981;padding:20px}</style>
      <h1>一扇小窗</h1><canvas id="sky" width="240" height="100"></canvas><button id="light">点亮</button><p id="state">未点亮</p>
      <script>const g=document.getElementById('sky').getContext('2d');g.fillStyle='#ea5d95';g.fillRect(0,0,240,100);
      document.getElementById('light').onclick=()=>{document.getElementById('state').textContent='亮了';g.fillStyle='#f8c981';g.fillRect(30,10,80,70)};</script>"""
    private fun check(source: String): Map<String,Any?> {
        val latch=CountDownLatch(1)
        var result:Map<String,Any?>?=null
        CreativePreview(context).run(source,listOf(mapOf("click" to "#light","selector" to "#state","text" to "亮了"))) { result=it;latch.countDown() }
        assertTrue("preview timeout",latch.await(25,TimeUnit.SECONDS))
        return requireNotNull(result)
    }
    @Test fun rendersAndClicksWithoutAnActivity() {
        val result=check(html)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals("private_virtual",result["display"])
        val screenshot=File(result["screenshot"] as String)
        assertTrue(screenshot.length()>1000)
        screenshot.copyTo(File(context.getExternalFilesDir(null),"creative-preview.png"),overwrite=true)
    }
    @Test fun previewBridgeUsesValidSimulatedChoices() {
        val source=html+"""<script>document.getElementById('light').onclick=async()=>{
          await companion.choose('round1',['rock','paper','scissors'],'preview');
          const r=await companion.reveal('round1','scissors');
          document.getElementById('state').textContent=r.preview && r.choice==='rock' && r.playerChoice==='scissors' ? '亮了' : 'wrong';
        };</script>"""
        val result=check(source)
        assertEquals(result.toString(),true,result["ok"])
    }
    @Test fun reportsActualScriptFailure() {
        val result=check(html+"<script>throw new Error('deliberate-preview-error')</script>")
        assertEquals(false,result["ok"])
        assertTrue(result["errors"].toString().contains("deliberate-preview-error"))
    }
    @Test fun remainsOffscreenWhileDeviceSleeps() {
        val ui=InstrumentationRegistry.getInstrumentation().uiAutomation
        ui.executeShellCommand("input keyevent KEYCODE_HOME").close()
        ui.executeShellCommand("input keyevent KEYCODE_SLEEP").close()
        try {
            val result=check(html)
            assertEquals(result.toString(),true,result["ok"])
        } finally { ui.executeShellCommand("input keyevent KEYCODE_WAKEUP").close() }
    }
}
