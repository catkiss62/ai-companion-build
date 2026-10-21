package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class OverlayHistoryRefreshStateTest {
    @Test fun firstOpenWaitsForAttachmentWithoutASend() {
        val state = OverlayHistoryRefreshState()
        assertNull(state.request(1, ready = false, opened = true))
        val attached = state.request(1, ready = true, opened = true)!!
        assertTrue(attached.opened)
        assertTrue(state.current(attached))
        assertFalse(state.finish(attached))
    }
    @Test fun dartReadyAfterAttachmentDrainsThePendingOpen() {
        val state = OverlayHistoryRefreshState()
        assertNull(state.request(1, ready = false, opened = true))
        assertNull(state.request(1, ready = false, opened = true))
        assertNotNull(state.request(1, ready = true, opened = true))
    }
    @Test fun duplicateOpenCoalescesButNewHistoryIsReadAfterInflight() {
        val state = OverlayHistoryRefreshState()
        val first = state.request(1, ready = true, opened = true)!!
        assertNull(state.request(1, ready = true, opened = true))
        assertNull(state.request(1, ready = true, opened = false))
        assertTrue(state.finish(first))
        val second = state.request(1, ready = true, opened = false)!!
        assertFalse(second.opened)
        assertFalse(state.current(first))
        assertTrue(state.current(second))
    }
    @Test fun reopenedAndReplacementWindowsNeverAcceptOldReads() {
        val state = OverlayHistoryRefreshState()
        val old = state.request(1, ready = true, opened = true)!!
        assertNull(state.request(2, ready = false, opened = true))
        assertFalse(state.current(old))
        assertFalse(state.finish(old))
        assertNotNull(state.request(2, ready = true, opened = true))
        val replacement = OverlayHistoryRefreshState()
        assertNotNull(replacement.request(1, ready = true, opened = true))
    }
}
