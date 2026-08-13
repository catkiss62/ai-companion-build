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

    private val visibleActivities = AtomicInteger(0)

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
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_LAST_SERVICE_START, System.currentTimeMillis())
            .putString(KEY_LAST_SERVICE_REASON, reason.take(120))
            .apply()
    }

    fun markServiceStopped(context: Context, reason: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_LAST_SERVICE_STOP, System.currentTimeMillis())
            .putString(KEY_LAST_SERVICE_REASON, reason.take(120))
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
            "processUptimeMs" to SystemClock.elapsedRealtime(),
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

    fun setAccessibilityConnected(connected: Boolean) {
        accessibilityConnected = connected
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
