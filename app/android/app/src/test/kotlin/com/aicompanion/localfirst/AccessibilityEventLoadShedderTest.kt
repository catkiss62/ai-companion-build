package com.aicompanion.localfirst

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessibilityEventLoadShedderTest {
    @Test fun `window floods cannot bypass remote query gates or slow query cooldown`() {
        val gate = AccessibilityEventLoadShedder()
        assertTrue(gate.shouldProbeRoot(0, true)); assertTrue(gate.shouldProbeWindows(0))
        for (now in 1L..499L) {
            assertFalse(gate.shouldProbeRoot(now, true)); assertFalse(gate.shouldProbeWindows(now))
        }
        assertTrue(gate.shouldProbeRoot(500, true)); assertTrue(gate.shouldProbeWindows(500))
        gate.noteProbeDuration(750, 250)
        assertFalse(gate.shouldProbeRoot(2_500, true)); assertFalse(gate.shouldProbeWindows(2_500))
        assertTrue(gate.shouldProbeRoot(3_750, true)); assertTrue(gate.shouldProbeWindows(3_750))
    }
    @Test fun `ordinary query rate and persistence decisions stay independent`() {
        val gate = AccessibilityEventLoadShedder()
        assertTrue(gate.shouldProbeRoot(1_000, false))
        assertTrue(gate.shouldPersist(1_000, 1, false))
        assertFalse(gate.shouldProbeRoot(2_000, false))
        assertTrue(gate.shouldProbeRoot(2_500, false))
        assertTrue(gate.shouldProbeWindows(2_500))
        assertTrue(gate.shouldPersist(2_500, 2, false))
    }
    @Test
    fun `ordinary content events are rate limited and duplicate suppressed`() {
        val shedder = AccessibilityEventLoadShedder()

        assertTrue(shedder.shouldPersist(1_000L, 7, windowChanged = false))
        assertFalse(shedder.shouldPersist(1_500L, 8, windowChanged = false))
        assertFalse(shedder.shouldPersist(3_000L, 7, windowChanged = false))
        assertTrue(shedder.shouldPersist(6_100L, 7, windowChanged = false))
    }

    @Test
    fun `window changes keep a faster but still bounded lane`() {
        val shedder = AccessibilityEventLoadShedder()

        assertTrue(shedder.shouldPersist(10_000L, 1, windowChanged = true))
        assertFalse(shedder.shouldPersist(10_200L, 2, windowChanged = true))
        assertTrue(shedder.shouldPersist(10_450L, 2, windowChanged = true))
    }
}
