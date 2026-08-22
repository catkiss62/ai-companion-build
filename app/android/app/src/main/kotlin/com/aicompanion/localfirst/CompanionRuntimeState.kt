package com.aicompanion.localfirst

import android.content.Context
import android.os.SystemClock
import java.security.MessageDigest
import java.util.ArrayDeque
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
    private const val KEY_ACCESSIBILITY_SERVICE_GENERATION = "accessibility_service_generation"
    private const val KEY_ACCESSIBILITY_CONNECT_COUNT = "accessibility_connect_count"
    private const val KEY_ACCESSIBILITY_DISCONNECT_COUNT = "accessibility_disconnect_count"
    private const val KEY_ACCESSIBILITY_INTERRUPT_COUNT = "accessibility_interrupt_count"
    private const val KEY_ACCESSIBILITY_DESTROY_COUNT = "accessibility_destroy_count"
    private const val KEY_ACCESSIBILITY_EVENT_COUNT = "accessibility_event_count"
    private const val KEY_ACCESSIBILITY_ALLOWED_EVENT_COUNT = "accessibility_allowed_event_count"
    private const val KEY_ACCESSIBILITY_LAST_EVENT = "accessibility_last_event"
    private const val KEY_ACCESSIBILITY_LAST_EVENT_TYPE = "accessibility_last_event_type"
    private const val KEY_ACCESSIBILITY_LAST_EVENT_PACKAGE_HASH = "accessibility_last_event_package_hash"
    private const val KEY_ACCESSIBILITY_LAST_WINDOW_EVENT = "accessibility_last_window_event"
    private const val KEY_ACCESSIBILITY_LAST_ROOT = "accessibility_last_root"
    private const val KEY_ACCESSIBILITY_AUTHORIZATION_KNOWN =
        "accessibility_authorization_known"
    private const val KEY_ACCESSIBILITY_LAST_AUTHORIZED =
        "accessibility_last_authorized"
    private const val KEY_ACCESSIBILITY_LAST_AUTHORIZATION_CHANGED =
        "accessibility_last_authorization_changed"
    private const val KEY_ACCESSIBILITY_AUTHORIZATION_CHANGE_COUNT =
        "accessibility_authorization_change_count"
    private const val KEY_ACCESSIBILITY_LAST_STATUS_PROBE =
        "accessibility_last_status_probe"

    private val visibleActivities = AtomicInteger(0)
    private val processStartedElapsedMs = SystemClock.elapsedRealtime()
    private val processStartedWallMs = System.currentTimeMillis()
    @Volatile private var serviceStartedElapsedMs: Long = 0L

    @Volatile var overlayVisible: Boolean = false
        private set
    @Volatile var overlayChatExpanded: Boolean = false
        private set
    @Volatile var notificationListenerConnected: Boolean = false
        private set
    @Volatile var accessibilityConnected: Boolean = false
        private set
    @Volatile private var foregroundWindowPackage: String = ""
    @Volatile private var foregroundWindowObservedAt: Long = 0L
    @Volatile private var currentAppFusionSource: String = "none"
    @Volatile private var currentAppFusionAgeMs: Long = -1L
    @Volatile private var currentAppFusionEventCount: Int = 0
    @Volatile private var currentAppFusionLabelResolved: Boolean = false
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
    private const val OVERLAY_COVER_HISTORY_LIMIT = 24
    private val overlayCoverHistory = ArrayDeque<Map<String, Any>>()

    data class ForegroundWindowSnapshot(
        val packageName: String,
        val observedAt: Long,
    )

    fun noteForegroundWindow(sourcePackage: String) {
        if (sourcePackage.isBlank()) return
        foregroundWindowPackage = sourcePackage
        foregroundWindowObservedAt = System.currentTimeMillis()
    }

    fun foregroundWindowSnapshot(): ForegroundWindowSnapshot? {
        val packageName = foregroundWindowPackage
        val observedAt = foregroundWindowObservedAt
        if (packageName.isBlank() || observedAt <= 0L) return null
        return ForegroundWindowSnapshot(packageName, observedAt)
    }

    fun noteCurrentAppFusion(
        source: String,
        ageMs: Long,
        usageEventCount: Int,
        labelResolved: Boolean,
    ) {
        currentAppFusionSource = source.take(40)
        currentAppFusionAgeMs = ageMs.coerceAtLeast(-1L)
        currentAppFusionEventCount = usageEventCount.coerceAtLeast(0)
        currentAppFusionLabelResolved = labelResolved
    }

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
        val foregroundAgeMs = foregroundWindowObservedAt
            .takeIf { it > 0L }
            ?.let { (System.currentTimeMillis() - it).coerceAtLeast(0L) }
            ?: -1L
        return mapOf(
            "overlayUserEnabled" to prefs.getBoolean(KEY_OVERLAY_USER_ENABLED, false),
            "overlayVisible" to overlayVisible,
            "overlayChatExpanded" to overlayChatExpanded,
            "appVisible" to (visibleActivities.get() > 0),
            "notificationListenerConnected" to notificationListenerConnected,
            "accessibilityConnected" to accessibilityConnected,
            "foregroundWindowObserved" to (foregroundWindowPackage.isNotBlank()),
            "foregroundWindowPackageHash" to shortHash(foregroundWindowPackage),
            "foregroundWindowAgeMs" to foregroundAgeMs,
            "currentAppFusionSource" to currentAppFusionSource,
            "currentAppFusionAgeMs" to currentAppFusionAgeMs,
            "currentAppFusionUsageEventCount" to currentAppFusionEventCount,
            "currentAppFusionLabelResolved" to currentAppFusionLabelResolved,
            "currentAppRawPackageIncluded" to false,
            "accessibilityLastConnectedAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_CONNECTED, 0L),
            "accessibilityLastDisconnectedAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_DISCONNECTED, 0L),
            "accessibilityLastInterruptAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_INTERRUPT, 0L),
            "accessibilityLastReason" to (prefs.getString(KEY_ACCESSIBILITY_LAST_REASON, "") ?: ""),
            "accessibilityServiceGeneration" to
                prefs.getInt(KEY_ACCESSIBILITY_SERVICE_GENERATION, 0),
            "accessibilityConnectCount" to prefs.getInt(KEY_ACCESSIBILITY_CONNECT_COUNT, 0),
            "accessibilityDisconnectCount" to
                prefs.getInt(KEY_ACCESSIBILITY_DISCONNECT_COUNT, 0),
            "accessibilityInterruptCount" to
                prefs.getInt(KEY_ACCESSIBILITY_INTERRUPT_COUNT, 0),
            "accessibilityDestroyCount" to prefs.getInt(KEY_ACCESSIBILITY_DESTROY_COUNT, 0),
            "accessibilityEventCount" to prefs.getInt(KEY_ACCESSIBILITY_EVENT_COUNT, 0),
            "accessibilityAllowedEventCount" to
                prefs.getInt(KEY_ACCESSIBILITY_ALLOWED_EVENT_COUNT, 0),
            "accessibilityLastEventAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_EVENT, 0L),
            "accessibilityLastEventType" to
                (prefs.getString(KEY_ACCESSIBILITY_LAST_EVENT_TYPE, "") ?: ""),
            "accessibilityLastEventPackageHash" to
                (prefs.getString(KEY_ACCESSIBILITY_LAST_EVENT_PACKAGE_HASH, "") ?: ""),
            "accessibilityLastWindowEventAt" to
                prefs.getLong(KEY_ACCESSIBILITY_LAST_WINDOW_EVENT, 0L),
            "accessibilityLastRootAt" to prefs.getLong(KEY_ACCESSIBILITY_LAST_ROOT, 0L),
            "accessibilityLastAuthorizationChangedAt" to
                prefs.getLong(KEY_ACCESSIBILITY_LAST_AUTHORIZATION_CHANGED, 0L),
            "accessibilityAuthorizationChangeCount" to
                prefs.getInt(KEY_ACCESSIBILITY_AUTHORIZATION_CHANGE_COUNT, 0),
            "accessibilityLastStatusProbeAt" to
                prefs.getLong(KEY_ACCESSIBILITY_LAST_STATUS_PROBE, 0L),
            "processStartedAt" to processStartedWallMs,
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
            "overlayCoverHistory" to overlayCoverHistorySnapshot(),
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

    fun noteAccessibilityStatusProbe(context: Context, authorized: Boolean) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val known = prefs.getBoolean(KEY_ACCESSIBILITY_AUTHORIZATION_KNOWN, false)
        val previous = prefs.getBoolean(KEY_ACCESSIBILITY_LAST_AUTHORIZED, false)
        val now = System.currentTimeMillis()
        prefs.edit()
            .putBoolean(KEY_ACCESSIBILITY_AUTHORIZATION_KNOWN, true)
            .putBoolean(KEY_ACCESSIBILITY_LAST_AUTHORIZED, authorized)
            .putLong(KEY_ACCESSIBILITY_LAST_STATUS_PROBE, now)
            .apply {
                if (known && previous != authorized) {
                    putLong(KEY_ACCESSIBILITY_LAST_AUTHORIZATION_CHANGED, now)
                    putInt(
                        KEY_ACCESSIBILITY_AUTHORIZATION_CHANGE_COUNT,
                        prefs.getInt(KEY_ACCESSIBILITY_AUTHORIZATION_CHANGE_COUNT, 0) + 1,
                    )
                }
            }
            .apply()
    }

    fun markAccessibilityConnected(context: Context) {
        accessibilityConnected = true
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_ACCESSIBILITY_LAST_CONNECTED, System.currentTimeMillis())
            .putString(KEY_ACCESSIBILITY_LAST_REASON, "connected")
            .putInt(
                KEY_ACCESSIBILITY_SERVICE_GENERATION,
                prefs.getInt(KEY_ACCESSIBILITY_SERVICE_GENERATION, 0) + 1,
            )
            .putInt(
                KEY_ACCESSIBILITY_CONNECT_COUNT,
                prefs.getInt(KEY_ACCESSIBILITY_CONNECT_COUNT, 0) + 1,
            )
            .apply()
    }

    fun markAccessibilityDisconnected(context: Context, reason: String) {
        accessibilityConnected = false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_ACCESSIBILITY_LAST_DISCONNECTED, System.currentTimeMillis())
            .putString(KEY_ACCESSIBILITY_LAST_REASON, reason.take(120))
            .putInt(
                KEY_ACCESSIBILITY_DISCONNECT_COUNT,
                prefs.getInt(KEY_ACCESSIBILITY_DISCONNECT_COUNT, 0) + 1,
            )
            .apply()
    }

    fun noteAccessibilityInterrupted(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_ACCESSIBILITY_LAST_INTERRUPT, System.currentTimeMillis())
            .putString(KEY_ACCESSIBILITY_LAST_REASON, "interrupted")
            .putInt(
                KEY_ACCESSIBILITY_INTERRUPT_COUNT,
                prefs.getInt(KEY_ACCESSIBILITY_INTERRUPT_COUNT, 0) + 1,
            )
            .apply()
    }

    fun noteAccessibilityDestroyed(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_ACCESSIBILITY_LAST_REASON, "destroyed")
            .putInt(
                KEY_ACCESSIBILITY_DESTROY_COUNT,
                prefs.getInt(KEY_ACCESSIBILITY_DESTROY_COUNT, 0) + 1,
            )
            .apply()
    }

    fun noteAccessibilityEvent(
        context: Context,
        eventType: String,
        sourcePackage: String,
        allowedPackage: Boolean,
        windowChanged: Boolean,
        hasReadableRoot: Boolean,
    ) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        prefs.edit()
            .putLong(KEY_ACCESSIBILITY_LAST_EVENT, now)
            .putString(KEY_ACCESSIBILITY_LAST_EVENT_TYPE, eventType.take(80))
            .putString(
                KEY_ACCESSIBILITY_LAST_EVENT_PACKAGE_HASH,
                shortHash(sourcePackage),
            )
            .putInt(
                KEY_ACCESSIBILITY_EVENT_COUNT,
                prefs.getInt(KEY_ACCESSIBILITY_EVENT_COUNT, 0) + 1,
            )
            .apply {
                if (allowedPackage) {
                    putInt(
                        KEY_ACCESSIBILITY_ALLOWED_EVENT_COUNT,
                        prefs.getInt(KEY_ACCESSIBILITY_ALLOWED_EVENT_COUNT, 0) + 1,
                    )
                }
                if (windowChanged) putLong(KEY_ACCESSIBILITY_LAST_WINDOW_EVENT, now)
                if (hasReadableRoot) putLong(KEY_ACCESSIBILITY_LAST_ROOT, now)
            }
            .apply()
    }

    private fun shortHash(value: String): String {
        if (value.isBlank()) return ""
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
        return digest.take(6).joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    fun privacyHash(value: String): String = shortHash(value)

    @Synchronized
    private fun appendOverlayCoverHistory(stage: String, reason: String) {
        if (overlayCoverHistory.size >= OVERLAY_COVER_HISTORY_LIMIT) {
            overlayCoverHistory.removeFirst()
        }
        overlayCoverHistory.addLast(
            mapOf(
                "at" to System.currentTimeMillis(),
                "stage" to stage.take(40),
                "reason" to reason.take(120),
                "sessionId" to overlayCoverSessionId,
                "attempt" to overlayCoverRecoveryAttempt,
                "bubbleAttached" to overlayBubbleAttached,
                "bubbleTouchable" to overlayBubbleTouchable,
                "appVisible" to (visibleActivities.get() > 0),
            ),
        )
    }

    @Synchronized
    private fun overlayCoverHistorySnapshot(): List<Map<String, Any>> =
        overlayCoverHistory.toList()

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
        appendOverlayCoverHistory("suspect", reason)
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
        appendOverlayCoverHistory(
            if (detached) "entered_detached" else "entered_suspect",
            reason,
        )
        return overlayCoverSessionId
    }

    @Synchronized
    fun noteOverlayCoverExited(reason: String, sessionId: Int) {
        if (sessionId != overlayCoverSessionId) return
        overlaySystemCoverActive = false
        overlayCoverState = "exit_pending"
        overlayLastCoverExitAt = System.currentTimeMillis()
        overlayLastCoverExitReason = reason.take(120)
        appendOverlayCoverHistory("exited", reason)
    }

    @Synchronized
    fun noteOverlayCoverRecoveryScheduled(sessionId: Int, attempt: Int, reason: String) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverState = "recovery_scheduled"
        overlayCoverRecoveryAttempt = attempt
        overlayLastCoverExitReason = reason.take(120)
        appendOverlayCoverHistory("recovery_scheduled", reason)
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
        appendOverlayCoverHistory(
            if (success) "recovery_succeeded" else "recovery_retry",
            reason,
        )
    }

    @Synchronized
    fun noteOverlayCoverRecoveryFailed(sessionId: Int, attempt: Int, reason: String) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverRecoveryAttempt = attempt
        overlayCoverState = "failed"
        overlayLastCoverRecoveryResult = "failed:${reason.take(100)}"
        appendOverlayCoverHistory("recovery_failed", reason)
    }

    @Synchronized
    fun noteOverlayCoverRecoveryDeferred(sessionId: Int, reason: String) {
        if (sessionId != overlayCoverSessionId) return
        overlayCoverState = "exit_pending"
        overlayCoverRecoveryAttempt = 0
        overlayLastCoverRecoveryResult = "deferred:${reason.take(100)}"
        appendOverlayCoverHistory("recovery_deferred", reason)
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
        appendOverlayCoverHistory("recovered_legacy", reason)
    }

    fun noteOverlayWindowVisibility(visibility: Int) {
        overlayLastWindowVisibility = visibility
        appendOverlayCoverHistory("window_visibility", visibility.toString())
    }

    fun setOverlayRecoveryInProgress(value: Boolean) {
        overlayRecoveryInProgress = value
    }
}

