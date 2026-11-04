package com.aicompanion.localfirst

/** A transient AppOps read cannot tear down the engine; sustained denial still stops it. */
internal class OverlayPermissionProbe(private val intervalMs: Long = 1_500L) {
    enum class Result { GRANTED, SUSPECT, CONFIRMED }
    var checks = 0
        private set
    private var lastCheckAt = Long.MIN_VALUE
    fun observe(granted: Boolean, now: Long): Result {
        if (granted) { checks = 0; lastCheckAt = Long.MIN_VALUE; return Result.GRANTED }
        if (lastCheckAt == Long.MIN_VALUE || now < lastCheckAt || now - lastCheckAt >= intervalMs) {
            if (now < lastCheckAt) checks = 0
            checks++
            lastCheckAt = now
        }
        return if (checks >= 3) Result.CONFIRMED else Result.SUSPECT
    }
    fun delayUntilNext(now: Long): Long =
        if (lastCheckAt == Long.MIN_VALUE || now < lastCheckAt) intervalMs
        else (intervalMs - (now - lastCheckAt)).coerceIn(1L, intervalMs)
}
