package com.aicompanion.localfirst

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessibilityEventLoadShedderTest {
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
