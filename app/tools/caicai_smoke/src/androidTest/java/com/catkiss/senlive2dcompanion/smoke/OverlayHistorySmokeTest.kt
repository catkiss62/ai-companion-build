package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test

class OverlayHistorySmokeTest {
    @Test fun readyBrainBeforeFirstAttachLoadsWithoutAnySendAndSurvivesHostRecreation() {
        val prefs = ApplicationProvider.getApplicationContext<Context>()
            .getSharedPreferences("overlay_history_smoke", Context.MODE_PRIVATE)
        prefs.edit().putString("messages", "old user|old assistant").commit()
        try {
            repeat(2) {
                ActivityScenario.launch(OverlayHistorySmokeActivity::class.java).use { scenario ->
                    scenario.onActivity { it.open(true) }
                    InstrumentationRegistry.getInstrumentation().waitForIdleSync()
                    scenario.onActivity {
                        assertFalse("Initial addView is not yet attached", it.attachedAtFirstRequest)
                        assertEquals(2, it.list.adapter.count)
                        assertEquals(1, it.reads)
                        it.closeWindow(); it.open(true)
                    }
                    InstrumentationRegistry.getInstrumentation().waitForIdleSync()
                    scenario.onActivity { assertEquals(2,it.list.adapter.count); assertEquals(2,it.reads) }
                }
            }
        } finally { prefs.edit().clear().commit() }
    }
    @Test fun lateBrainReadinessCompletesAnAlreadyAttachedWindow() {
        ActivityScenario.launch(OverlayHistorySmokeActivity::class.java).use { scenario ->
            scenario.onActivity { it.open(false) }
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            scenario.onActivity { assertEquals(0,it.reads); it.backendReady(); assertEquals(1,it.reads) }
        }
    }
}
