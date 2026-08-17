package com.aicompanion.localfirst

import android.content.Context
import android.os.SystemClock
import java.util.concurrent.atomic.AtomicInteger

/**
 * Small process-local + SharedPreferences runtime state.
 *
 * Important: this is NOT relationship memory. It only records whether the user
 * asked for the persistent companion service, plus ephemeral Android lifecycle
 * status that is useful for diagnostics/reconciliation after Activity changes.
 */
object CompanionRuntimeState {
    private const val PREFS = "companion_runtime"
    private const val KEY_OVERLAY_USER_ENABLED = "overlay_user_enabled"
    private const val KEY_LAST_SERVICE_START = "last_service_start"
    private const val KEY_LAST_SERVICE_STOP = "last_service_stop"
    private const val KEY_LAST_SERVICE_REASON = "last_service_reason"
    private const val KEY_SERVICE_ACTIVE_MARKER = "service_active_marker"
    private const val KEY_SERVICE_START_COUNT = "service_start_count"
    private const val KEY_SERVICE_CLEAN_STOP_COUNT = "service_clean_stop_count"
    private const val KEY_SERVICE_UNCLEAN_RESTART_COUNT = "service_unclean_restart_count"
    private const val KEY_LAST_UNCLEAN_RESTART = "last_unclean_restart"
    private const val KEY_LAST_TASK_REMOVED = "last_task_removed"
    private const val KEY_LAST_TRIM_MEMORY = "last_trim_memory"
    private const val KEY_LAST_TRIM_MEMORY_LEVEL = "last_trim_memory_level"
    private const val KEY_BACKGROUND_BRAIN_READY_AT = "background_brain_ready_at"
    private const val KEY_BACKGROUND_BRAIN_READY_COUNT = "background_brain_ready_count"
    private const val KEY_BACKGROUND_BRAIN_FAILURE_AT = "background_brain_failure_at"
    private const val KEY_BACKGROUND_BRAIN_FAILURE_COUNT = "background_brain_failure_count"
    private const val KEY_BACKGROUND_BRAIN_FAILURE_REASON = "background_brain_failure_reason"
    private const val KEY_ACCESSIBILITY_LAST_CONNECTED = "accessibility_last_connected"
    private const val KEY_ACCESSIBILITY_LAST_DISCONNECTED = "accessibility_last_disconnected"
    private const val KEY_ACCESSIBILITY_LAST_INTERRUPT = "accessibility_last_interrupt"
    private const val KEY_ACCESSIBILITY_LAST_REASON = "accessibility_last_reason"

    private val visibleActivities = AtomicInteger(0)
    private val processStartedElapsedMs = SystemClock.elapsedRealtime()
    @Volatile private var serviceStartedElapsedMs: Long = 0L

    @Volatile var overlayVisible: Boolean = false
        private set
    @Volatile var overlayChatExpanded: Boolean = false
        private set
    @Volatile var notificationListenerConnected: Boolean = false
        private set
    @Volatile var accessibilityConnected: Boolean = false
        private set
    @Volatile var overlayBubbleAttached: Boolean = false
        private set
    @Volatile var overlayBubbleTouchable: Boolean = false
        private set
    @Volatile var overlayPositionSafe: Boolean = false
        private set
    @Volatile var overlayChatWindowAttached: Boolean = false
        private set
    @Volatile var overlayLastTouchAt: Long = 0L
        private set
    @Volatile var overlayLastTouchAction: String = ""
        private set
    @Volatile var overlayLastSelfHealAt: Long = 0L
        private set
    @Volatile var overlayLastSelfHealReason: String = ""
        private set
    private val overlaySelfHealCount = AtomicInteger(0)
    @Volatile var overlayInputSuspect: Boolean = false
        private set
    @Volatile var overlayLastSystemCoverAt: Long = 0L
        private set
    @Volatile var overlayLastSystemCoverReason: String = ""
        private set
    @Volatile var overlayLastCoverRecoveryAt: Long = 0L
        private set
    @Volatile var overlayLastWindowVisibility: Int = 0
        private set
    @Volatile var overlayRecoveryInProgress: Boolean = false
        private set
    private val overlayCoverRecoveryCount = AtomicInteger(0)
    @Volatile var overlayCoverState: String = "idle"
        private set
    @Volatile var overlaySystemCoverActive: Boolean = false
        private set
    @Volatile var overlayCoverSessionId: Int = 0
        private set
    @Volatile var overlayCoverRecoveryAttempt: Int = 0
        private set
    @Volatile var overlayLastCoverExitAt: Long = 0L
        private set
    @Volatile var overlayLastCoverExitReason: String = ""
        private set
    @Volatile var overlayLastCoverRecoveryResult: String = ""
        private set
    private val overlayCoverDetachCount = AtomicInteger(0)

    fun setOverlayUserEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_OVERLAY_USER_ENABLED, enabled).apply()
    }

    fun isOverlayUserEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_OVERLAY_USER_ENABLED, false)

    fun markServiceStarted(context: Context, reason: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val possibleUncleanRestart = prefs.getBoolean(KEY_SERVICE_ACTIVE_MARKER, false)
        serviceStartedElapsedMs = SystemClock.elapsedRealtime()
        prefs.edit()
            .putLong(KEY_LAST_SERVICE_START, now)
            .putString(KEY_LAST_SERVICE_REASON, reason.take(120))
            .putBoolean(KEY_SERVICE_ACTIVE_MARKER, true)
            .putInt(KEY_SERVICE_START_COUNT, prefs.getInt(KEY_SERVICE_START_COUNT, 0) + 1)
            .apply {
                if (possibleUncleanRestart) {
                    putInt(
                        KEY_SERVICE_UNCLEAN_RESTART_COUNT,
                        prefs.getInt(KEY_SERVICE_UNCLEAN_RESTART_COUNT, 0) + 1,
                    )
                    putLong(KEY_LAST_UNCLEAN_RESTART, now)
                }
            }
            .apply()
    }

    fun noteServiceCommand(context: Context, reason: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_LAST_SERVICE_REASON, reason.take(120))
            .apply()
    }

    fun markServiceStopped(context: Context, reason: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        serviceStartedElapsedMs = 0L
        prefs.edit()
            .putLong(KEY_LAST_SERVICE_STOP, System.currentTimeMillis())
            .putString(KEY_LAST_SERVICE_REASON, reason.take(120))
            .putBoolean(KEY_SERVICE_ACTIVE_MARKER, false)
            .putInt(
                KEY_SERVICE_CLEAN_STOP_COUNT,
                prefs.getInt(KEY_SERVICE_CLEAN_STOP_COUNT, 0) + 1,
            )
            .apply()
    }

    fun noteTaskRemoved(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_LAST_TASK_REMOVED, System.currentTimeMillis())
            .apply()
    }

    fun noteTrimMemory(context: Context, level: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_LAST_TRIM_MEMORY, System.currentTimeMillis())
            .putInt(KEY_LAST_TRIM_MEMORY_LEVEL, level)
            .apply()
    }

    fun noteBackgroundBrainReady(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_BACKGROUND_BRAIN_READY_AT, System.currentTimeMillis())
            .putInt(
                KEY_BACKGROUND_BRAIN_READY_COUNT,
                prefs.getInt(KEY_BACKGROUND_BRAIN_READY_COUNT, 0) + 1,
            )
            .apply()
    }

    fun noteBackgroundBrainFailure(context: Context, reason: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_BACKGROUND_BRAIN_FAILURE_AT, System.currentTimeMillis())
            .putInt(
                KEY_BACKGROUND_BRAIN_FAILURE_COUNT,
                prefs.getInt(KEY_BACKGROUND_BRAIN_FAILURE_COUNT, 0) + 1,
            )
            .putString(KEY_BACKGROUND_BRAIN_FAILURE_REASON, reason.take(120))
            .apply()
    }

    fun runtimeInfo(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "overlayUserEnabled" to prefs.getBoolean(KEY_OVERLAY_USER_ENABLED, false),
            "overlayVisible" to overlayVisible,
            "overlayChatExpanded" to overlayChatExpanded,
            "appVisible" to (visibleActivities.get() > 0),
            "notificationListenerConnected" to notificationListenerConnected,
            "accessibilityConnected" to accessibilityConnected,
            "accessibilityLastConnectedAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_CONNECTED, 0L),
            "accessibilityLastDisconnectedAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_DISCONNECTED, 0L),
            "accessibilityLastInterruptAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_INTERRUPT, 0L),
            "accessibilityLastReason" to (prefs.getString(KEY_ACCESSIBILITY_LAST_REASON, "") ?: ""),
            "overlayBubbleAttached" to overlayBubbleAttached,
            "overlayBubbleTouchable" to overlayBubbleTouchable,
            "overlayPositionSafe" to overlayPositionSafe,
            "overlayChatWindowAttached" to overlayChatWindowAttached,
            "overlayLastTouchAt" to overlayLastTouchAt,
            "overlayLastTouchAction" to overlayLastTouchAction,
            "overlayLastSelfHealAt" to overlayLastSelfHealAt,
            "overlayLastSelfHealReason" to overlayLastSelfHealReason,
            "overlaySelfHealCount" to overlaySelfHealCount.get(),
            "overlayInputSuspect" to overlayInputSuspect,
            "overlayLastSystemCoverAt" to overlayLastSystemCoverAt,
            "overlayLastSystemCoverReason" to overlayLastSystemCoverReason,
            "overlayLastCoverRecoveryAt" to overlayLastCoverRecoveryAt,
            "overlayLastWindowVisibility" to overlayLastWindowVisibility,
            "overlayRecoveryInProgress" to overlayRecoveryInProgress,
            "overlayCoverRecoveryCount" to overlayCoverRecoveryCount.get(),
            "overlayCoverState" to overlayCoverState,
            "overlaySystemCoverActive" to overlaySystemCoverActive,
            "overlayCoverSessionId" to overlayCoverSessionId,
            "overlayCoverRecoveryAttempt" to overlayCoverRecoveryAttempt,
            "overlayLastCoverExitAt" to overlayLastCoverExitAt,
            "overlayLastCoverExitReason" to overlayLastCoverExitReason,
            "overlayLastCoverRecoveryResult" to overlayLastCoverRecoveryResult,
            "overlayCoverDetachCount" to overlayCoverDetachCount.get(),
            "lastServiceStart" to prefs.getLong(KEY_LAST_SERVICE_START, 0L),
            "lastServiceStop" to prefs.getLong(KEY_LAST_SERVICE_STOP, 0L),
            "lastServiceReason" to (prefs.getString(KEY_LAST_SERVICE_REASON, "") ?: ""),
            "processAgeMs" to
                (SystemClock.elapsedRealtime() - processStartedElapsedMs).coerceAtLeast(0L),
            // Backward-compatible diagnostic alias; unlike the old value this
            // now measures this process lifetime rather than device uptime.
            "processUptimeMs" to
                (SystemClock.elapsedRealtime() - processStartedElapsedMs).coerceAtLeast(0L),
            "serviceUptimeMs" to if (serviceStartedElapsedMs > 0L) {
                (SystemClock.elapsedRealtime() - serviceStartedElapsedMs).coerceAtLeast(0L)
            } else {
                0L
            },
            "serviceStartCount" to prefs.getInt(KEY_SERVICE_START_COUNT, 0),
            "serviceCleanStopCount" to prefs.getInt(KEY_SERVICE_CLEAN_STOP_COUNT, 0),
            "possibleUncleanRestartCount" to
                prefs.getInt(KEY_SERVICE_UNCLEAN_RESTART_COUNT, 0),
            "lastPossibleUncleanRestartAt" to prefs.getLong(KEY_LAST_UNCLEAN_RESTART, 0L),
            "lastTaskRemovedAt" to prefs.getLong(KEY_LAST_TASK_REMOVED, 0L),
            "lastTrimMemoryAt" to prefs.getLong(KEY_LAST_TRIM_MEMORY, 0L),
            "lastTrimMemoryLevel" to prefs.getInt(KEY_LAST_TRIM_MEMORY_LEVEL, 0),
            "backgroundBrainReadyAt" to prefs.getLong(KEY_BACKGROUND_BRAIN_READY_AT, 0L),
            "backgroundBrainReadyCount" to prefs.getInt(KEY_BACKGROUND_BRAIN_READY_COUNT, 0),
            "backgroundBrainFailureAt" to prefs.getLong(KEY_BACKGROUND_BRAIN_FAILURE_AT, 0L),
            "backgroundBrainFailureCount" to
                prefs.getInt(KEY_BACKGROUND_BRAIN_FAILURE_COUNT, 0),
            "backgroundBrainFailureReason" to
                (prefs.getString(KEY_BACKGROUND_BRAIN_FAILURE_REASON, "") ?: ""),
        )
    }

    fun activityStarted() {
        visibleActivities.incrementAndGet()
    }

    fun activityStopped() {
        visibleActivities.updateAndGet { current -> if (current <= 0) 0 else current - 1 }
    }

    fun isAppVisible(): Boolean = visibleActivities.get() > 0

    fun setOverlayVisible(visible: Boolean) {
        overlayVisible = visible
    }

    fun setOverlayChatExpanded(expanded: Boolean) {
        overlayChatExpanded = expanded
    }

    fun setNotificationListenerConnected(connected: Boolean) {
        notificationListenerConnected = connected
    }

    fun markAccessibilityConnected(context: Context) {
        accessibilityConnected = true
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_ACCESSIBILITY_LAST_CONNECTED, System.currentTimeMillis())
            .putString(KEY_ACCESSIBILITY_LAST_REASON, "connected")
            .apply()
    }

    fun markAccessibilityDisconnected(context: Context, reason: String) {
        accessibilityConnected = false
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_ACCESSIBILITY_LAST_DISCONNECTED, System.currentTimeMillis())
            .putString(KEY_ACCESSIBILITY_LAST_REASON, reason.take(120))
            .apply()
    }

    fun noteAccessibilityInterrupted(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_ACCESSIBILITY_LAST_INTERRUPT, System.currentTimeMillis())
            .putString(KEY_ACCESSIBILITY_LAST_REASON, "interrupted")
            .apply()
    }

    fun setOverlayTouchHealth(
        bubbleAttached: Boolean,
        bubbleTouchable: Boolean,
        positionSafe: Boolean,
        chatWindowAttached: Boolean,
    ) {
        overlayBubbleAttached = bubbleAttached
        overlayBubbleTouchable = bubbleTouchable
        overlayPositionSafe = positionSafe
        overlayChatWindowAttached = chatWindowAttached
    }

    fun noteOverlayTouch(action: String) {
        overlayLastTouchAt = System.currentTimeMillis()
        overlayLastTouchAction = action.take(40)
    }

    fun noteOverlaySelfHeal(reason: String) {
        overlayLastSelfHealAt = System.currentTimeMillis()
        overlayLastSelfHealReason = reason.take(120)
        overlaySelfHealCount.incrementAndGet()
    }

    fun noteOverlaySystemCover(reason: String) {
        overlayInputSuspect = true
        overlayLastSystemCoverAt = System.currentTimeMillis()
        overlayLastSystemCoverReason = reason.take(120)
    }

    @Synchronized
    fun noteOverlayCoverEntered(reason: String, detached: Boolean): Int {
        if (!overlaySystemCoverActive) {
            overlayCoverSessionId += 1
            overlayCoverRecoveryAttempt = 0
        }
        overlaySystemCoverActive = true
        overlayCoverState = if (detached) "covered_detached" else "covered_suspect"
        overlayInputSuspect = true
        overlayLastSystemCoverAt = System.currentTimeMillis()
        overlayLastSystemCoverReason = reason.take(120)
        overlayLastCoverRecoveryResult = ""
        if (detached) overlayCoverDetachCount.incrementAndGet()
        return overlayCoverSessionId
    }

    @Synchronized
    fun noteOverlayCoverExited(reason: String, sessionId: Int) {
        if (sessionId != overlayCoverSessionId) return
        overlaySystemCoverActive = false
        overlayCoverState = "exit_pending"
        overlayLastCoverExitAt = System.currentTimeMillis()
        overlayLastCoverExitReason = reason.take(120)
    }

    @Synchronized
    fun noteOverlayCoverRecoveryScheduled(sessionId: Int, attempt: Int, reason: String) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverState = "recovery_scheduled"
        overlayCoverRecoveryAttempt = attempt
        overlayLastCoverExitReason = reason.take(120)
    }

    @Synchronized
    fun noteOverlayCoverRecoveryResult(
        sessionId: Int,
        attempt: Int,
        success: Boolean,
        reason: String,
    ) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverRecoveryAttempt = attempt
        overlayLastCoverRecoveryResult = if (success) {
            "success:${reason.take(100)}"
        } else {
            "retry:${reason.take(100)}"
        }
        if (success) {
            overlaySystemCoverActive = false
            overlayCoverState = "settled"
            overlayInputSuspect = false
            overlayLastCoverRecoveryAt = System.currentTimeMillis()
            overlayLastSelfHealReason = reason.take(120)
            overlayCoverRecoveryCount.incrementAndGet()
        } else {
            overlayCoverState = "exit_pending"
        }
    }

    @Synchronized
    fun noteOverlayCoverRecoveryFailed(sessionId: Int, attempt: Int, reason: String) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverRecoveryAttempt = attempt
        overlayCoverState = "failed"
        overlayLastCoverRecoveryResult = "failed:${reason.take(100)}"
    }

    @Synchronized
    fun noteOverlayCoverRecoveryDeferred(sessionId: Int, reason: String) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverState = "exit_pending"
        overlayCoverRecoveryAttempt = 0
        overlayLastCoverRecoveryResult = "deferred:${reason.take(100)}"
    }

    fun isOverlaySystemCoverActive(): Boolean = overlaySystemCoverActive

    fun currentOverlayCoverSessionId(): Int = overlayCoverSessionId

    fun consumeOverlayInputSuspect(): Boolean {
        val value = overlayInputSuspect
        overlayInputSuspect = false
        return value
    }

    fun noteOverlayCoverRecovered(reason: String) {
        overlayInputSuspect = false
        overlaySystemCoverActive = false
        overlayCoverState = "settled"
        overlayLastCoverRecoveryAt = System.currentTimeMillis()
        overlayLastSelfHealReason = reason.take(120)
        overlayCoverRecoveryCount.incrementAndGet()
    }

    fun noteOverlayWindowVisibility(visibility: Int) {
        overlayLastWindowVisibility = visibility
    }

    fun setOverlayRecoveryInProgress(value: Boolean) {
        overlayRecoveryInProgress = value
    }
}
