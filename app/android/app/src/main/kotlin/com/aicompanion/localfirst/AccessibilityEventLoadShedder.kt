package com.aicompanion.localfirst

/**
 * Keeps high-frequency Accessibility content changes useful without allowing
 * them to synchronously flood SQLite from the service main thread.
 */
class AccessibilityEventLoadShedder(
    private val ordinaryMinIntervalMs: Long = 1_500L,
    private val windowMinIntervalMs: Long = 400L,
    private val duplicateQuietMs: Long = 5_000L,
) {
    private var lastPersistedAt = Long.MIN_VALUE
    private var lastWindowPersistedAt = Long.MIN_VALUE
    private var lastSignature = 0

    @Synchronized
    fun shouldPersist(
        nowElapsedMs: Long,
        signature: Int,
        windowChanged: Boolean,
    ): Boolean {
        if (windowChanged) {
            if (elapsedSince(nowElapsedMs, lastWindowPersistedAt) < windowMinIntervalMs) {
                return false
            }
            lastWindowPersistedAt = nowElapsedMs
            lastPersistedAt = nowElapsedMs
            lastSignature = signature
            return true
        }
        if (elapsedSince(nowElapsedMs, lastPersistedAt) < ordinaryMinIntervalMs) {
            return false
        }
        if (signature == lastSignature &&
            elapsedSince(nowElapsedMs, lastPersistedAt) < duplicateQuietMs
        ) {
            return false
        }
        lastPersistedAt = nowElapsedMs
        lastSignature = signature
        return true
    }

    private fun elapsedSince(now: Long, previous: Long): Long =
        if (previous == Long.MIN_VALUE || now < previous) Long.MAX_VALUE else now - previous
}
