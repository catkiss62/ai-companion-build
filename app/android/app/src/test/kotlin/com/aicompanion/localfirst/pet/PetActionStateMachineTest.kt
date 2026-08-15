package com.aicompanion.localfirst.pet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PetActionStateMachineTest {
    @Test
    fun dragCannotBeInterruptedByLowerPriorityAction() {
        val state = PetActionStateMachine()
        assertTrue(state.request("dragging", PetActionSource.DRAG, false, 10L))
        assertFalse(state.request("talk", PetActionSource.SPEAK, true, 20L))
        assertEquals("dragging", state.active.actionId)
    }

    @Test
    fun oneShotCompletionReturnsToIdle() {
        val state = PetActionStateMachine()
        assertTrue(state.request("happy", PetActionSource.NOTICE, true, 10L))
        assertEquals("idle", state.complete(30L).actionId)
    }

    @Test
    fun pausedStateRejectsNonSystemActions() {
        val state = PetActionStateMachine()
        state.setPaused(true, 10L)
        assertFalse(state.request("blink", PetActionSource.RANDOM_IDLE, true, 20L))
        state.setPaused(false, 30L)
        assertTrue(state.request("blink", PetActionSource.RANDOM_IDLE, true, 40L))
    }
}
