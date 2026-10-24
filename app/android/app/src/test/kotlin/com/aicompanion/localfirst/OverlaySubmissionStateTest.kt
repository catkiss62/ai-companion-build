package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class OverlaySubmissionStateTest {
    @Test fun lateSendCannotFinishCancelOrNewSend() {
        var next = 0
        val state = OverlaySubmissionState { "request-${++next}" }
        val first = state.begin("first")
        val cancel = state.beginCancel()
        assertFalse(state.finish(first, true))
        assertTrue(state.finishCancel(cancel))
        val second = state.begin("second")
        assertFalse(state.finishCancel(cancel))
        assertFalse(state.finish(first, false))
        assertTrue(state.matches(second.epoch))
        assertTrue(state.finish(second, true))
        assertNull(state.retryText)
    }

    @Test fun uncertainDeliveryRetainsDraftAndStableRequestButChangesCallbackEpoch() {
        var next = 0
        val state = OverlaySubmissionState { "request-${++next}" }
        val first = state.begin("draft")
        state.engineLost()
        assertEquals("draft", state.retryText)
        assertFalse(state.finish(first, true))
        val retry = state.begin("draft")
        assertEquals(first.requestId, retry.requestId)
        assertNotEquals(first.epoch, retry.epoch)
        assertFalse(state.finish(first, false))
        assertTrue(state.finish(retry, true))
        assertNull(state.retryText)
    }

    @Test fun rejectionRestoresDraftButExplicitCancelStartsANewTurn() {
        var next = 0
        val state = OverlaySubmissionState { "request-${++next}" }
        val first = state.begin("text")
        assertTrue(state.finish(first, false))
        assertEquals("text", state.retryText)
        val retry = state.begin("text")
        assertEquals(first.requestId, retry.requestId)
        state.finishCancel(state.beginCancel())
        assertNotEquals(first.requestId, state.begin("text").requestId)
    }
}
