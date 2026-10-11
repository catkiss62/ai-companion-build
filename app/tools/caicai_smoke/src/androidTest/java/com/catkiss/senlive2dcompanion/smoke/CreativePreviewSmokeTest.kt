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
    private fun check(source: String, checks: List<Map<String,String>> = listOf(mapOf("click" to "#light","selector" to "#state","text" to "亮了"))): Map<String,Any?> {
        val latch=CountDownLatch(1)
        var result:Map<String,Any?>?=null
        CreativePreview(context).run(source,checks) { result=it;latch.countDown() }
        assertTrue("preview timeout",latch.await(25,TimeUnit.SECONDS))
        return requireNotNull(result)
    }
    @Test fun rendersAndClicksWithoutAnActivity() {
        val result=check(html)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals("private_virtual",result["display"])
        val screenshot=File(result["screenshot"] as String)
        assertTrue(screenshot.length()>1000)
        val exported=File(context.getExternalFilesDir(null),"creative-preview.png")
        screenshot.copyTo(exported,overwrite=true)
        // UTP removes the app and its external files at the end of the suite.
        val automation=InstrumentationRegistry.getInstrumentation().uiAutomation
        android.os.ParcelFileDescriptor.AutoCloseInputStream(
            automation.executeShellCommand("cp ${exported.absolutePath} /data/local/tmp/creative-preview.png")
        ).use { it.readBytes() }
        val retained=android.os.ParcelFileDescriptor.AutoCloseInputStream(
            automation.executeShellCommand("cat /data/local/tmp/creative-preview.png")
        ).use { it.readBytes() }
        assertArrayEquals("Keep the actual frame before test cleanup",screenshot.readBytes(),retained)
    }
    @Test fun previewBridgeUsesValidSimulatedChoices() {
        val source=html+"""<script>document.getElementById('light').onclick=async()=>{
          await companion.choose('round1',['rock','paper','scissors'],'preview');
          const r=await companion.reveal('round1','scissors');
          document.getElementById('state').textContent=r.preview && r.choice==='rock' && r.playerChoice==='scissors' ? '亮了' : 'wrong';
        };</script>"""
        val result=check(source)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(1,result["choose_count"])
        assertEquals(1,result["reveal_count"])
    }
    @Test fun rockPaperScissorsRestoresScoreAndSealedRoundAfterReload() {
        val source="""<style>body{background:#173552;color:white;font:20px sans-serif;padding:20px}button{padding:18px}</style>
        <h1>一起猜拳</h1><p id="score"></p><p id="status"></p>
        <button id="begin">准备</button><button id="scissors" disabled>剪刀</button>
        <script>
        let s=companion.initialState;
        if(!s || typeof s.round!=='number')s={round:1,score:0,sealed:false,played:false};
        const status=document.getElementById('status'),score=document.getElementById('score'),play=document.getElementById('scissors');
        function render(){score.textContent='她的分数：'+s.score;status.textContent=s.played?'本轮结束':s.sealed?'她已出招':'等待开始';play.disabled=!s.sealed||s.played;}
        document.getElementById('begin').onclick=async()=>{await companion.choose('r'+s.round,['石头','剪刀','布'],'公平猜拳');s.sealed=true;await companion.saveState(s);render();};
        play.onclick=async()=>{const r=await companion.reveal('r'+s.round,'剪刀');
          if(!s.played&&r.choice==='石头'&&r.playerChoice==='剪刀')s.score++;
          s.played=true;await companion.saveState(s);await companion.report({text:'猜拳完成'});render();};
        render();
        </script>"""
        val result=check(source,listOf(
            mapOf("click" to "#begin","selector" to "#status","text" to "她已出招"),
            mapOf("reload" to "true","selector" to "#status","text" to "她已出招"),
            mapOf("click" to "#scissors","selector" to "#score","text" to "她的分数：1"),
            mapOf("reload" to "true","selector" to "#score","text" to "她的分数：1"),
            mapOf("selector" to "#status","text" to "本轮结束")
        ))
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(1,result["choose_count"])
        assertEquals(1,result["reveal_count"])
        assertEquals(2,result["save_count"])
        assertEquals(2,result["reload_count"])
        assertTrue(result["page_text"].toString().contains("本轮结束"))
        assertTrue(result["elements"].toString().contains("scissors"))
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
