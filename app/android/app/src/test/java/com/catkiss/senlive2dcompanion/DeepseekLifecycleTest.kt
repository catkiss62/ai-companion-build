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
}
