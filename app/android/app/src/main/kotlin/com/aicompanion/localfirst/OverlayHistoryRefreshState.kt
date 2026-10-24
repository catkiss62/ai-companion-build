package com.aicompanion.localfirst

/** A current window waiting for attachment/Dart is pending, not obsolete. */
class OverlayHistoryRefreshState {
    data class Request(val epoch: Long, val serial: Long, val opened: Boolean, val messageRevision: Long = 0)
    private var window = Long.MIN_VALUE
    private var serial = 0L
    private var loading = false
    private var pending = false
    private var pendingOpen = false
    private var messageRevision = 0L

    fun messagesChanged() {
        messageRevision++
        if (loading) pending = true
    }
    fun mayApply(request: Request): Boolean = current(request) && request.messageRevision == messageRevision

    fun request(epoch: Long, ready: Boolean, opened: Boolean): Request? {
        if (window != epoch) {
            window = epoch
            loading = false
            pending = false
            pendingOpen = false
        }
        if (loading) {
            // Show/attach/DartReady can describe the same initial read. A real
            // history change during that read must instead trigger one reload.
            if (!opened) pending = true
            return null
        }
        pending = true
        pendingOpen = pendingOpen || opened
        if (!ready) return null
        loading = true
        pending = false
        return Request(epoch, ++serial, pendingOpen, messageRevision).also { pendingOpen = false }
    }

    fun current(request: Request): Boolean =
        loading && window == request.epoch && serial == request.serial

    fun finish(request: Request): Boolean {
        if (!current(request)) return false
        loading = false
        return pending
    }
}
