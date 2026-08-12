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
    private val overlayCoverRecoveryCount = AtomicInteger(0)

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
            "overlayCoverRecoveryCount" to overlayCoverRecoveryCount.get(),
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

    fun consumeOverlayInputSuspect(): Boolean {
        val value = overlayInputSuspect
        overlayInputSuspect = false
        return value
    }

    fun noteOverlayCoverRecovered(reason: String) {
        overlayInputSuspect = false
        overlayLastCoverRecoveryAt = System.currentTimeMillis()
        overlayLastSelfHealReason = reason.take(120)
        overlayCoverRecoveryCount.incrementAndGet()
    }

    fun noteOverlayWindowVisibility(visibility: Int) {
        overlayLastWindowVisibility = visibility
    }
}
