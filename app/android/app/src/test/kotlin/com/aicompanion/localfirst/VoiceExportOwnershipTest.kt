package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class VoiceExportOwnershipTest {
    @Test fun appPlaybackHasPriorityAndOldExportCannotCancelNewOwner() {
        val gate = VoiceExportOwnership()
        assertNull(gate.claim("qq", 1, false))
        val old = gate.claim("qq", 1, true)!!
        assertNull(gate.claim("other", 1, true))
        gate.invalidate() // App claim/Stop advances the shared generation.
        assertFalse(gate.finish("qq", old, 2))
        val newer = gate.claim("qq", 2, true)!!
        assertFalse(gate.finish("qq", old, 2))
        assertFalse(gate.finish("other", newer, 2))
        assertTrue(gate.current("qq", newer, 2))
        assertTrue(gate.finish("qq", newer, 2))
        assertFalse(gate.current("qq", newer, 2))
    }
    @Test fun generationAndHostMustBothMatchForCancellation() {
        val gate = VoiceExportOwnership()
        val id = gate.claim("background", 8, true)!!
        assertFalse(gate.current("background", id, 9))
        assertFalse(gate.current("activity", id, 8))
        assertNull(gate.owned("activity"))
        assertEquals(id, gate.owned("background"))
        assertFalse(gate.finish("background", id, 9))
        assertTrue(gate.finish("background", id, 8))
    }
}
