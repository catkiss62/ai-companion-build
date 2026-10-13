package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.aicompanion.localfirst.CreativePreview
import com.aicompanion.localfirst.CreativeWebSandbox
import org.json.JSONObject
import org.json.JSONArray
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
    private fun check(source: String, checks: List<Map<String,String>> = listOf(mapOf("click" to "#light","selector" to "#state","text" to "亮了")),
                      assertions: List<Map<String,String>> = emptyList(), requireRestore: Boolean = false): Map<String,Any?> {
        val latch=CountDownLatch(1)
        var result:Map<String,Any?>?=null
        CreativePreview(context).run(source,checks,assertions,requireRestore) { result=it;latch.countDown() }
        assertTrue("preview timeout",latch.await(30,TimeUnit.SECONDS))
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
        <h1>一起猜拳</h1><p>她的分数：<span id="score"></span></p><p id="status"></p>
        <button id="begin">准备</button><button id="scissors" disabled>剪刀</button>
        <script>
        let s=companion.initialState;
        if(!s || typeof s.round!=='number')s={round:1,score:0,sealed:false,played:false};
        const status=document.getElementById('status'),score=document.getElementById('score'),play=document.getElementById('scissors');
        function render(){score.textContent=String(s.score);status.textContent=s.played?'本轮结束':s.sealed?'她已出招':'等待开始';play.disabled=!s.sealed||s.played;}
        document.getElementById('begin').onclick=async()=>{await companion.choose('r'+s.round,['石头','剪刀','布'],'公平猜拳');s.sealed=true;await companion.saveState(s);render();};
        play.onclick=async()=>{const r=await companion.reveal('r'+s.round,'剪刀');
          if(!s.played&&r.choice==='石头'&&r.playerChoice==='剪刀')s.score++;
          s.played=true;await companion.saveState(s);await companion.report({text:'猜拳完成'});render();};
        render();
        </script>"""
        val result=check(source,listOf(
            mapOf("click" to "#begin","selector" to "#status","text" to "她已出招"),
            mapOf("reload" to "true","selector" to "#status","text" to "她已出招"),
            mapOf("click" to "#scissors","selector" to "#score","text" to "1"),
            mapOf("reload" to "true","selector" to "#score","text" to "1"),
            mapOf("selector" to "#status","text" to "本轮结束")
        ),listOf(mapOf("selector" to "#score","property" to "text","state_path" to "score")),true)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(1,result["choose_count"])
        assertEquals(1,result["reveal_count"])
        assertEquals(2,result["save_count"])
        assertEquals(3,result["reload_count"])
        assertEquals(true,result["restore_verified"])
        assertEquals("restored",result["proof_phase"])
        assertEquals(2,result["save_seq"])
        assertTrue(result["page_text"].toString().contains("本轮结束"))
        assertTrue(result["elements"].toString().contains("scissors"))
    }
    @Test fun reportsActualScriptFailure() {
        val result=check(html+"<script>throw new Error('deliberate-preview-error')</script>")
        assertEquals(false,result["ok"])
        assertTrue(result["errors"].toString().contains("deliberate-preview-error"))
    }
    @Test fun numericRoundUsesTheSameSealedChoiceAsStringRound() {
        val source=html+"""<script>document.getElementById('light').onclick=async()=>{
          await companion.choose(1,['rock','paper'],'numeric round');
          await companion.choose('1',['rock','paper'],'same round');
          const a=await companion.reveal(1,'paper');
          const b=await companion.reveal('1','rock');
          document.getElementById('state').textContent=a.choice==='rock' && b.playerChoice==='paper'?'亮了':'wrong';
        };</script>"""
        val result=check(source)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(1,result["choose_count"])
        assertEquals(1,result["reveal_count"])
    }
    @Test fun previewRejectsInvalidContractsInsteadOfMakingThemPass() {
        val source=html+"""<script>document.getElementById('light').onclick=async()=>{
          let denied=0;async function bad(action){try{await action()}catch(e){denied++}}
          await bad(()=>companion.choose(1.5,['rock','paper'],''));
          await bad(()=>companion.choose({},['rock','paper'],''));
          await bad(()=>companion.choose(1,['rock','rock'],''));
          await bad(()=>companion.choose(1,[1,2],''));
          await companion.choose(1,['rock','paper'],'');
          await bad(()=>companion.choose('1',['paper','rock'],''));
          await bad(()=>companion.reveal(1,'unknown'));
          document.getElementById('state').textContent=denied===6?'亮了':'wrong '+denied;
        };</script>"""
        val result=check(source)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(1,result["choose_count"])
        assertEquals(0,result["reveal_count"])
    }
    @Test fun nativeContractAlsoRejectsLossyJsonCoercion() {
        assertEquals("1",CreativeWebSandbox.turnId(1))
        assertEquals("01",CreativeWebSandbox.turnId("01"))
        for(value in listOf(null,true,JSONObject(),1.5,-1,9007199254740992.0,"   ")) assertNull(CreativeWebSandbox.turnId(value))
        assertNull(CreativeWebSandbox.options(JSONArray("[1,2]")))
        assertNull(CreativeWebSandbox.options(JSONArray("[\"a\",\"a\"]")))
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
    @Test fun observationWaitsForPublicWritesAndReadsActualTextAndAnimation() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val latch = CountDownLatch(1)
        var observed: JSONObject? = null
        lateinit var page: android.webkit.WebView
        instrumentation.runOnMainSync {
            page = CreativeWebSandbox.create(context, { raw ->
                val event = JSONObject(raw)
                if (event.optString("kind") == "observation") {
                    observed = event.getJSONObject("data"); latch.countDown()
                } else {
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        CreativeWebSandbox.reply(page,event.getString("id"),true)
                    },100)
                }
            }, { latch.countDown() })
            val source = """<style>@keyframes snowfall{from{opacity:1}to{opacity:.5}}#snow{animation:snowfall 8s infinite}</style>
              <h1 id="snow">圣诞快乐</h1><p id="progress">尚未保存</p><canvas width="20" height="20"></canvas>
              <script>companion.describe({kind:'static',content:'一封贺卡',effects:'雪花',resettable:false});
              companion.saveState({opened:true}).then(()=>document.getElementById('progress').textContent='已经保存');
              window.__workObserve('observation-test');</script>"""
            page.loadDataWithBaseURL(CreativeWebSandbox.ORIGIN,CreativeWebSandbox.document(source,"{}",false),"text/html","UTF-8",null)
        }
        try {
            assertTrue("observation timeout",latch.await(8,TimeUnit.SECONDS))
            val result = requireNotNull(observed)
            assertFalse(result.getBoolean("pending_writes"))
            assertTrue(result.getString("text").contains("已经保存"))
            assertTrue(result.getString("text").contains("圣诞快乐"))
            assertTrue(result.getJSONArray("animations").toString().contains("snowfall"))
            assertEquals(1,result.getInt("canvas_count"))
            assertFalse(result.toString().contains("NativeWork"))
        } finally { instrumentation.runOnMainSync { page.destroy() } }
    }

    @Test fun failedBridgeWritesDoNotBlockLaterSavingOrObservation() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val latch = CountDownLatch(1)
        var observed: JSONObject? = null
        var nativeSaves = 0
        lateinit var page: android.webkit.WebView
        instrumentation.runOnMainSync {
            page = CreativeWebSandbox.create(context, { raw ->
                val event = JSONObject(raw)
                when (event.optString("kind")) {
                    "observation" -> { observed = event.getJSONObject("data"); latch.countDown() }
                    "save" -> { nativeSaves++; CreativeWebSandbox.reply(page,event.getString("id"),true) }
                    else -> CreativeWebSandbox.reply(page,event.getString("id"),null,"save failed")
                }
            }, { latch.countDown() })
            val source = """<h1 id="result">等待保存</h1><script>(async()=>{
              let denied=0;async function bad(action){try{await action()}catch(e){denied++}}
              const cyclic={};cyclic.self=cyclic;
              await bad(()=>companion.saveState(cyclic));
              await bad(()=>companion.saveState('雪'.repeat(24000)));
              await bad(()=>companion.report({text:'rejected by host'}));
              await companion.saveState({round:1});
              document.getElementById('result').textContent=denied===3?'继续保存成功':'wrong '+denied;
              await window.__workObserve('failure-recovery');
            })();</script>"""
            page.loadDataWithBaseURL(CreativeWebSandbox.ORIGIN,CreativeWebSandbox.document(source,"{}",false),"text/html","UTF-8",null)
        }
        try {
            assertTrue("observation timeout",latch.await(8,TimeUnit.SECONDS))
            val result = requireNotNull(observed)
            assertFalse(result.getBoolean("pending_writes"))
            assertTrue(result.getString("text").contains("继续保存成功"))
            assertEquals(1,nativeSaves)
        } finally { instrumentation.runOnMainSync { page.destroy() } }
    }

    private val scoreAssertion = listOf(mapOf("selector" to "#score", "property" to "text", "state_path" to "score"))
    private val scoreCheck = listOf(mapOf("click" to "#next", "selector" to "#score", "text" to "1"))
    private fun scorePage(restore: Boolean = true, extra: String = "") = """
      <style>body{background:#18354e;color:white;font:24px sans-serif}button{padding:20px}</style>
      <h1 id="title">累计分数</h1><span id="score">0</span><button id="next">下一轮</button><span id="empty"></span>
      <script>let s=${if (restore) "companion.initialState" else "{}"};
      if(typeof s.score!=='number')s={score:0,title:'累计分数',empty:''};
      const score=document.getElementById('score');score.textContent=String(s.score);
      document.getElementById('next').onclick=async()=>{s.score++;await companion.saveState(s);score.textContent=String(s.score);};
      $extra</script>"""

    @Test fun localStatefulPageHasRealVersionedRestoreProof() {
        val source=scorePage()
        val result=check(source,scoreCheck,scoreAssertion)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(2,result["proof_version"])
        assertEquals(true,result["restore_required"])
        assertEquals(true,result["baseline_verified"])
        assertEquals(true,result["checkpoint_verified"])
        assertEquals(true,result["restore_verified"])
        assertEquals(1,result["save_seq"])
        assertEquals(2,result["reload_generation"])
        assertEquals(1,result["assertion_count"])
        assertEquals(1,result["changed_count"])
        assertEquals(1,result["restored_count"])
        val hash=java.security.MessageDigest.getInstance("SHA-256").digest(source.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        assertEquals(hash,result["source_hash"])
        assertFalse("Proof never contains the saved object",result.containsKey("state"))
    }

    @Test fun ignoringInitialStateFailsEvenWhenLegacyReloadClicksPass() {
        val checks=listOf(scoreCheck.single(),mapOf("reload" to "true", "click" to "#next", "selector" to "#score", "text" to "1"))
        val result=check(scorePage(restore=false),checks,scoreAssertion,true)
        assertEquals(false,result["ok"])
        assertEquals(listOf("step:1","step:2"),result["checks"])
        assertEquals(true,result["checkpoint_verified"])
        assertEquals(false,result["restore_verified"])
        assertEquals(0,result["restored_count"])
        assertTrue(result["errors"].toString().contains("冷重载后未恢复"))
    }

    @Test fun earlierReloadAndSaveCountsCannotReplaceRestoreAssertions() {
        val result=check(scorePage(),listOf(mapOf("reload" to "true","selector" to "#title","text" to "累计分数"),scoreCheck.single()))
        assertEquals(false,result["ok"])
        assertEquals(1,result["reload_count"])
        assertEquals(1,result["save_count"])
        assertEquals(false,result["restore_verified"])
        assertTrue(result["errors"].toString().contains("restore_assertions"))
    }

    @Test fun constantTitleAndEmptyTextCannotProveProgress() {
        val assertions=listOf(
            mapOf("selector" to "#title","property" to "text","state_path" to "title"),
            mapOf("selector" to "#empty","property" to "text","state_path" to "empty"))
        val result=check(scorePage(),scoreCheck,assertions,true)
        assertEquals(false,result["ok"])
        assertEquals(0,result["changed_count"])
        assertEquals(false,result["checkpoint_verified"])
        assertTrue(result["errors"].toString().contains("没有验证实际状态变化"))
    }

    @Test fun rejectedSaveIsNotACheckpointEvenIfPagePaintsSuccess() {
        val source=scorePage(extra="""document.getElementById('next').onclick=async()=>{
          try{await companion.saveState({score:1,padding:'x'.repeat(42000)})}catch(e){}
          score.textContent='1';};""")
        val result=check(source,scoreCheck,scoreAssertion,true)
        assertEquals(false,result["ok"])
        assertEquals(0,result["save_count"])
        assertEquals(0,result["save_seq"])
        assertEquals(false,result["checkpoint_verified"])
        assertTrue(result["errors"].toString().contains("没有成功保存"))
    }

    @Test fun delayedPublicSaveAndRenderUseLastSuccessfulSnapshot() {
        val source=scorePage(extra="""document.getElementById('next').onclick=async()=>{
          await companion.saveState({score:9});
          await new Promise(r=>setTimeout(r,500));
          s.score=1;await companion.saveState(s);await companion.report({text:'已结算'});
          score.textContent='1';};""")
        val result=check(source,scoreCheck,scoreAssertion,true)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(2,result["save_seq"])
        assertEquals(2,result["save_count"])
        assertEquals(1,result["restored_count"])
    }

    @Test fun restoredPageMayNotOverwriteCheckpointWhileDisplayingOldValue() {
        val source=scorePage(extra="""if(s.score===1)companion.saveState({score:0});""")
        val result=check(source,scoreCheck,scoreAssertion,true)
        assertEquals(false,result["ok"])
        assertEquals(true,result["checkpoint_verified"])
        assertEquals(false,result["restore_verified"])
        assertTrue(result["errors"].toString().contains("冷重载后未恢复"))
    }

    @Test fun oldPageTimersCannotWriteIntoColdReloadGeneration() {
        val source=scorePage(extra="""document.getElementById('next').onclick=async()=>{
          s.score=1;await companion.saveState(s);score.textContent='1';
          setTimeout(()=>companion.saveState({score:99}),900);
        };""")
        val result=check(source,listOf(scoreCheck.single(),mapOf("reload" to "true","selector" to "#score","text" to "1")),scoreAssertion,true)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(1,result["save_seq"])
        assertEquals(1,result["save_count"])
        assertEquals(3,result["reload_generation"])
        assertEquals(1,result["restored_count"])
    }

    @Test fun valueAndCheckedAssertionsReadNestedPublicScalars() {
        val source="""<h1>公开状态</h1><button id="next">继续</button><span id="status">0</span>
          <input id="name"><input id="enabled" type="checkbox"><script>
          let s=companion.initialState;if(!s.items)s={items:[{name:'初始',enabled:false}]};
          function render(){document.getElementById('name').value=s.items[0].name;document.getElementById('enabled').checked=s.items[0].enabled;}
          render();document.getElementById('next').onclick=async()=>{s.items[0]={name:'完成',enabled:true};await companion.saveState(s);render();document.getElementById('status').textContent='1';};
          </script>"""
        val assertions=listOf(
            mapOf("selector" to "#name","property" to "value","state_path" to "$.items[0].name"),
            mapOf("selector" to "#enabled","property" to "checked","state_path" to "items[0].enabled"))
        val result=check(source,listOf(mapOf("click" to "#next","selector" to "#status","text" to "1")),assertions,true)
        assertEquals(result.toString(),true,result["ok"])
        assertEquals(2,result["changed_count"])
        assertEquals(2,result["restored_count"])
    }

    @Test fun statelessLocalPageNeedsNoInventedSaveButCompanionDoes() {
        val local=check(html)
        assertEquals(local.toString(),true,local["ok"])
        assertEquals(false,local["restore_required"])
        assertEquals(false,local["restore_verified"])
        assertEquals("stateless",local["proof_phase"])
        val companion=check(html,assertions=listOf(mapOf("selector" to "#state","property" to "text","state_path" to "state")),requireRestore=true)
        assertEquals(false,companion["ok"])
        assertEquals(true,companion["restore_required"])
        assertEquals(false,companion["restore_verified"])
    }

    @Test fun invalidOrMissingStatePathNeverExecutesAsJavaScript() {
        val invalid=check(scorePage(),scoreCheck,listOf(mapOf("selector" to "#score","property" to "text","state_path" to "score;window.hacked=true")),true)
        assertEquals(false,invalid["ok"])
        assertTrue(invalid["errors"].toString().contains("state_path 无效"))
        val missing=check(scorePage(),scoreCheck,listOf(mapOf("selector" to "#score","property" to "text","state_path" to "missing")),true)
        assertEquals(false,missing["ok"])
        assertEquals(false,missing["checkpoint_verified"])
        assertTrue(missing["errors"].toString().contains("字段不存在"))
    }

}
