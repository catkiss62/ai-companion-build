package com.catkiss.senlive2dcompanion

import android.content.Context
import com.aicompanion.localfirst.PortableCompanionState
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class DeepseekAppearanceRestoreTest {
    private lateinit var context: Context
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        for (name in listOf("deepseek_appearance","deepseek_stage","caicai_stage","caicai_appearance",Live2DProfiles.REGISTRY))
            context.getSharedPreferences(name,0).edit().clear().commit()
        Live2DProfiles.restored(context)
    }
    private fun smallTarget(value: Float) {
        val model=DeepseekAvatarModel(context)
        model.form(true)
        assertTrue(model.trace(),model.trace().contains("target=$value "))
        model.form(false)
        assertTrue(model.trace(),model.trace().contains("target=0.0 "))
        model.form(true)
        assertTrue(model.trace(),model.trace().contains("target=$value "))
    }
    @Test fun absentValueUsesNewDefaultButSavedZeroAndOldValuesAlwaysWinOnRecreation() {
        smallTarget(.55f)
        for (value in listOf(0f,.63f,.8f,1f)) {
            context.getSharedPreferences("deepseek_appearance",0).edit().putFloat("smallForm",value).commit()
            smallTarget(value)
            smallTarget(value) // A new model after switch/recreation reads the same value.
        }
        assertFalse(context.getSharedPreferences("caicai_appearance",0).contains("smallForm"))
    }
    @Test fun archiveRoundTripsSizeAnchorAndCaicaiHeadBoxThenNewModelUsesRestoredTarget() {
        context.getSharedPreferences("deepseek_appearance",0).edit().putFloat("smallForm",.63f).commit()
        context.getSharedPreferences("deepseek_stage",0).edit().putFloat("anchorX",.44f).putFloat("anchorY",.31f).commit()
        context.getSharedPreferences("caicai_stage",0).edit().putFloat("headLeft",.21f).putFloat("headTop",.1f)
            .putFloat("headRight",.75f).putFloat("headBottom",.4f).commit()
        var refreshes=0
        val portable=PortableCompanionState(context,CaicaiModelRepository(context),releaseModel={},refreshPreferences={refreshes++})
        val snapshot=portable.begin()
        val preferences=snapshot["preferences"] as Map<*,*>
        portable.finish(snapshot["token"] as String,true)
        context.getSharedPreferences("deepseek_appearance",0).edit().putFloat("smallForm",.9f).commit()
        context.getSharedPreferences("deepseek_stage",0).edit().putFloat("anchorY",.8f).commit()
        context.getSharedPreferences("caicai_stage",0).edit().putFloat("headLeft",.3f).commit()
        val token=portable.begin()["token"] as String
        portable.apply(token,preferences,restoreModels=false)
        portable.finish(token,true)
        assertTrue(refreshes>0)
        smallTarget(.63f)
        assertTrue(DeepseekAvatarModel(context).trace().contains("anchor=0.44,0.31"))
        val head=context.getSharedPreferences("caicai_stage",0)
        for ((key,value) in mapOf("headLeft" to .21f,"headTop" to .1f,"headRight" to .75f,"headBottom" to .4f))
            assertEquals(value,head.getFloat(key,0f),0f)
    }

    @Test fun mouthDefaultsToCatAndLegacyZeroArchivesDoNotReplaceASavedArc() {
        val prefs=context.getSharedPreferences("deepseek_appearance",0)
        assertEquals(-1f,DeepseekAvatarModel(context).mouthStyle(),0f)
        for ((saved,effective) in listOf(0f to -1f,-1f to -1f,1f to 1f)) {
            prefs.edit().putFloat("MouthPressLipOpen",saved).commit()
            assertEquals(effective,DeepseekAvatarModel(context).mouthStyle(),0f)
            val portable=PortableCompanionState(context,CaicaiModelRepository(context),releaseModel={},refreshPreferences={})
            val snapshot=portable.begin();val preferences=snapshot["preferences"] as Map<*,*>
            portable.finish(snapshot["token"] as String,true)
            prefs.edit().putFloat("MouthPressLipOpen",-effective).commit()
            val token=portable.begin()["token"] as String
            portable.apply(token,preferences,restoreModels=false);portable.finish(token,true)
            assertEquals(effective,DeepseekAvatarModel(context).mouthStyle(),0f)
            assertFalse(context.getSharedPreferences("caicai_appearance",0).contains("MouthPressLipOpen"))
        }
    }
}
