package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class OverlayWindowSessionTest {
    @Test fun reopenedWindowRejectsOldInputAndHistoryCallbacks() {
        val session = OverlayWindowSession()
        val first = session.invalidateWindow()
        assertTrue(session.matches(first))
        session.invalidateWindow()
        val reopened = session.invalidateWindow()
        assertFalse(session.matches(first))
        assertTrue(session.matches(reopened))
    }
    @Test fun replacementServiceNeverRevivesDestroyedInstance() {
        val old = OverlayWindowSession()
        val callback = old.invalidateWindow()
        old.destroy()
        val replacement = OverlayWindowSession()
        replacement.invalidateWindow()
        assertTrue(replacement.alive)
        assertFalse(old.alive)
        assertFalse(old.matches(callback))
        assertFalse(old.matches(old.windowEpoch))
    }
}
