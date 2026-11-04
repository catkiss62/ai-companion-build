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
    private var lastRootProbeAt = Long.MIN_VALUE
    private var lastWindowProbeAt = Long.MIN_VALUE
    private var probeBackoffUntil = Long.MIN_VALUE

    @Synchronized
    fun noteProbeDuration(nowElapsedMs: Long, durationMs: Long) {
        if (durationMs >= 200L) probeBackoffUntil = nowElapsedMs + 3_000L
    }

    /** Gate the Binder queries themselves, before event persistence is considered. */
    @Synchronized
    fun shouldProbeRoot(nowElapsedMs: Long, windowChanged: Boolean): Boolean {
        if (nowElapsedMs < probeBackoffUntil) return false
        val interval = if (windowChanged) 500L else ordinaryMinIntervalMs
        if (elapsedSince(nowElapsedMs, lastRootProbeAt) < interval) return false
        lastRootProbeAt = nowElapsedMs
        return true
    }

    @Synchronized
    fun shouldProbeWindows(nowElapsedMs: Long): Boolean {
        if (nowElapsedMs < probeBackoffUntil) return false
        if (elapsedSince(nowElapsedMs, lastWindowProbeAt) < 500L) return false
        lastWindowProbeAt = nowElapsedMs
        return true
    }

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
