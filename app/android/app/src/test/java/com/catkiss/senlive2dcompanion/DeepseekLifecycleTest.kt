package com.catkiss.senlive2dcompanion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],manifest=Config.NONE)
class DeepseekLifecycleTest {
    @Test fun suspensionDropsPatPreviewAndOldHitWithoutWritingAnyProfilePreferences() {
        val context=RuntimeEnvironment.getApplication()
        val prefs=context.getSharedPreferences("deepseek_appearance",0)
        prefs.edit().clear().putFloat("smallForm",.61f).commit()
        val caicai=context.getSharedPreferences("caicai_stage",0)
        caicai.edit().putFloat("headLeft",.23f).commit()
        repeat(50) {
            val model=DeepseekAvatarModel(context)
            model.preview(JSONObject().put("AngleX",5))
            assertTrue(model.trace().contains("preview=true"))
            model.beginPat(true,false)
            assertTrue(model.trace().contains("pat=held"))
            // A late semantic plan cannot steal a held face.
            model.performance(JSONObject().put("face","爱心眼"),false)
            assertTrue(model.trace().contains("pat=held"))
            model.suspend()
            assertTrue(model.trace().contains("pat=idle"))
            assertTrue(model.trace().contains("preview=false"))
            assertTrue(model.trace().contains("gesture=:idle"))
            assertFalse(model.screenToModel(.5f,.5f,FloatArray(2)))
            model.form(true);assertTrue(model.trace().contains("target=0.61 "))
            model.closeModel()
        }
        assertEquals(.61f,prefs.getFloat("smallForm",0f),0f)
        assertEquals(.23f,caicai.getFloat("headLeft",0f),0f)
    }
    @Test fun manualPreviewCanResumeStaticButOrdinaryPlanCannot() {
        val model=DeepseekAvatarModel(RuntimeEnvironment.getApplication())
        model.staticMode(true)
        model.performance(JSONObject().put("face","圈圈眼"),false)
        assertTrue(model.trace().contains("static=true"))
        model.preview(JSONObject().put("AngleX",3))
        assertTrue(model.trace().contains("static=false"))
        model.performance(JSONObject().put("face","爱心眼"),false)
        assertTrue(model.trace().contains("preview=true"))
        model.previewIdle(false)
        assertTrue(model.trace().contains("preview=false"))
        model.closeModel()
    }

    @Test fun baseEmotionUsesCaicaiDurationAndDuplicateRevisionsCannotExtendOrResurrectIt() {
        val context=RuntimeEnvironment.getApplication()
        val model=DeepseekAvatarModel(context)
        val other=DeepseekAvatarModel(context)
        val start=10_000_000_000L
        model.emotion("reply-1","playful",start)
        assertEquals(1f,model.emotionWeight(start+4_120_000_000L),.0001f)
        assertEquals(.5f,model.emotionWeight(start+4_310_000_000L),.0001f)
        assertEquals(0f,other.emotionWeight(start),0f)
        model.emotion("reply-1","happy",start+4_000_000_000L)
        assertEquals(0f,model.emotionWeight(start+4_500_000_000L),0f)
        model.emotion("reply-1","playful",start+7_000_000_000L)
        assertEquals(0f,model.emotionWeight(start+7_000_000_000L),0f)
        model.emotion("reply-2","happy",start+8_000_000_000L)
        assertEquals(1f,model.emotionWeight(start+8_000_000_000L),0f)
        model.suspend()
        model.emotion("reply-2","happy",start+8_100_000_000L)
        assertEquals(0f,model.emotionWeight(start+8_100_000_000L),0f)
        model.emotion("reply-3","happy",start+9_000_000_000L)
        assertEquals(1f,model.emotionWeight(start+9_000_000_000L),0f)
        model.closeModel();other.closeModel()
    }

    @Test fun speechAndPreviewReleaseCannotResurrectAnExpiredBaseEmotion() {
        val model=DeepseekAvatarModel(RuntimeEnvironment.getApplication())
        val values=mutableMapOf<String,Float>()
        val pose=object:DeepseekParameterPlan.Target {
            override fun accepts(id:String)=true
            override fun current(id:String)=values[id] ?: if(id.endsWith("Open")) 1f else 0f
            override fun write(id:String,value:Float) {values[id]=value}
        }
        val start=System.nanoTime()
        model.emotion("expired","playful",start-10_000_000_000L)
        model.performance(JSONObject().put("emotion","playful").put("cue","voice:1").put("animate",false),true)
        model.applyEmotion(.2f,false,pose,start+1_000_000L)
        assertTrue(values["ParamMouthForm"]!!>.7f)
        model.releaseSpeech(start+20_000_000L)
        model.applyEmotion(.016f,false,pose,start+195_000_000L)
        assertTrue(values["ParamMouthForm"]!!>0f && values["ParamMouthForm"]!!<.7f)
        model.releaseSpeech(start+200_000_000L) // Duplicate release cannot restart the fade.
        model.applyEmotion(.016f,false,pose,start+371_000_000L)
        assertEquals(0f,values["ParamMouthForm"]!!,0f)
        assertEquals(0f,values["MouthX"]!!,0f)
        model.performance(JSONObject().put("_preview",true).put("emotion","playful"),false)
        model.applyEmotion(.2f,false,pose,System.nanoTime())
        assertTrue(values["ParamMouthForm"]!!>.7f)
        model.applyEmotion(.016f,false,pose,System.nanoTime()+5_000_000_000L)
        assertEquals(0f,values["ParamMouthForm"]!!,0f)
        model.applyEmotion(.016f,true,pose,System.nanoTime()+5_000_000_000L)
        assertEquals(-1f,values["ParamMouthForm"]!!,0f)
        model.closeModel()
    }
}
