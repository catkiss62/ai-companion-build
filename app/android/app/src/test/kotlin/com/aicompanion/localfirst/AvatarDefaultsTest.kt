package com.aicompanion.localfirst

import android.app.Application
import android.content.Context
import com.catkiss.senlive2dcompanion.CaicaiModelRepository
import com.catkiss.senlive2dcompanion.Live2DProfiles
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class AvatarDefaultsTest {
    @Test fun independentProfilesRestoreImplicitDefaultsAndPreservePreviewExclusions() {
        val app: Application = RuntimeEnvironment.getApplication()
        val state = PortableCompanionState(app, CaicaiModelRepository(app)) {}
        val caicai = app.getSharedPreferences("caicai_stage", Context.MODE_PRIVATE)
        val deep = app.getSharedPreferences("deepseek_stage", Context.MODE_PRIVATE)
        caicai.edit().putFloat("scale", 1.2f).putFloat("rightEarX", 0.2f).commit()
        deep.edit().putFloat("scale", 2f).commit()
        val a = state.captureAvatar(Live2DProfiles.CAICAI)
        val b = state.captureAvatar(Live2DProfiles.DEEPSEEK)
        caicai.edit().putFloat("scale", 4f).putFloat("rightEarX", 0.8f).commit()
        deep.edit().putFloat("scale", 5f).commit()
        val outfit = app.getSharedPreferences("caicai_appearance", Context.MODE_PRIVATE)
        outfit.edit().putBoolean("双马尾", true).commit()
        state.applyAvatar(Live2DProfiles.CAICAI, a)
        assertEquals(1.2f, caicai.getFloat("scale", 0f), 0f)
        assertEquals(0.8f, caicai.getFloat("rightEarX", 0f), 0f)
        assertEquals(5f, deep.getFloat("scale", 0f), 0f)
        assertFalse(outfit.contains("双马尾"))
        assertTrue(runCatching { state.applyAvatar(Live2DProfiles.DEEPSEEK, a) }.isFailure)
        state.applyAvatar(Live2DProfiles.DEEPSEEK, b)
        assertEquals(2f, deep.getFloat("scale", 0f), 0f)
    }

    @Test fun highScoreSurvivesReentryAndPortableRoundTrip() {
        val app: Application = RuntimeEnvironment.getApplication()
        assertEquals(80, recordWordSliceBest(app, 80))
        assertEquals(80, recordWordSliceBest(app, 40))
        val state = PortableCompanionState(app, CaicaiModelRepository(app)) {}
        val saved = state.begin()
        state.finish(saved["token"] as String, true)
        val prefs = app.getSharedPreferences("companion_runtime", Context.MODE_PRIVATE)
        prefs.edit().remove("word_slice_best").commit()
        val lease = state.begin()["token"] as String
        state.apply(lease, saved["preferences"] as Map<*, *>, false)
        state.finish(lease, true)
        assertEquals(80, recordWordSliceBest(app, 0))
    }
}
