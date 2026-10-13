package com.catkiss.senlive2dcompanion.smoke

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.aicompanion.localfirst.PlaybackSessionRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PlaybackOwnershipSmokeTest {
    @Test fun staleOwnerCannotPublishPhaseOrStopNewCue() {
        PlaybackSessionRegistry.claim(10001L, "A", "reply-A")
        var oldCancelled = 0
        val firstCue = PlaybackSessionRegistry.claimCue("A", 10001L) { oldCancelled++ }
        PlaybackSessionRegistry.claim(10002L, "B", "reply-B")
        assertEquals(1, oldCancelled)
        PlaybackSessionRegistry.phase(10001L, "idle")
        assertEquals("reply-B", PlaybackSessionRegistry.snapshot()["message_id"])
        assertEquals("synthesizing", PlaybackSessionRegistry.snapshot()["phase"])
        var newerCancelled = 0
        PlaybackSessionRegistry.claimCue("B", 10002L) { newerCancelled++ }
        PlaybackSessionRegistry.stopCue("A", firstCue)
        assertEquals(0, newerCancelled)
        assertFalse(PlaybackSessionRegistry.current(10001L))
        assertTrue(PlaybackSessionRegistry.current(10002L))
        PlaybackSessionRegistry.invalidate(10002L)
        assertEquals(1, newerCancelled)
        assertEquals("idle", PlaybackSessionRegistry.snapshot()["phase"])
    }
}
