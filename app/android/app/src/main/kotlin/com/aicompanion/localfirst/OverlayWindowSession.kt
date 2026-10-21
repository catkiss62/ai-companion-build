package com.aicompanion.localfirst

/** Instance-owned lifetime; a replacement Service cannot revive old callbacks. */
class OverlayWindowSession {
    var alive = true
        private set
    var windowEpoch = 0L
        private set

    fun invalidateWindow(): Long = (++windowEpoch)
    fun matches(epoch: Long): Boolean = alive && epoch == windowEpoch
    fun destroy() {
        alive = false
        invalidateWindow()
    }
}
