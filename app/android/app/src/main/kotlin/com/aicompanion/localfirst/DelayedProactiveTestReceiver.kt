package com.aicompanion.localfirst

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

/** One low-risk, memory-free cross-App contact probe.
 *
 * The probe deliberately does not call the LLM or insert a chat message. It
 * validates AlarmManager wake-up, current-App resolution, notification heads-
 * up delivery and inline reply while keeping Memory/Thought/rhythm untouched.
 */
class DelayedProactiveTestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        val probeIntent = intent?.let { Intent(it) }
        Thread {
            try {
                runProbe(appContext, probeIntent)
            } catch (error: Throwable) {
                NativeEventStore.addDeviceEvent(
                    appContext,
                    source = "system",
                    eventType = "delayed_proactive_test_failed",
                    appPackage = appContext.packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun runProbe(context: Context, intent: Intent?) {
        val dueAt = intent?.getLongExtra(EXTRA_DUE_AT, 0L) ?: 0L
        val soundKey = normalizeSound(intent?.getStringExtra(EXTRA_SOUND_KEY))
        val now = System.currentTimeMillis()
        val current = CurrentAppResolver.resolveCurrentWithRetries(context)
        val tracker = CurrentAppResolver.diagnosticStatus(context)
        val retryCount = tracker["currentAppLastRetryCount"] as? Int ?: 0
        val label = current?.appLabel.orEmpty()
        val appPhrase = if (label.isNotBlank()) {
            "我刚看到你在用 $label。"
        } else {
            "这次没有可靠认出你正在看的 App。"
        }
        val messageId = "delayed-proactive-test-${if (dueAt > 0L) dueAt else now}"
        val notification = CompanionNotification.postMessage(
            context = context,
            title = "她按约来找你了",
            body = "5分钟主动联系测试到点。$appPhrase（测试不会进入聊天记忆）",
            messageId = messageId,
            intentKind = "diagnostic_test",
            deliveryStyle = "normal",
            soundKey = soundKey,
        )
        val overlayAssessment = overlayAssessment(context)
        val prefs = prefs(context)
        prefs.edit()
            .putString(KEY_STATUS, "completed")
            .putLong(KEY_FIRED_AT, now)
            .putLong(KEY_LATENCY_MS, if (dueAt > 0L) (now - dueAt).coerceAtLeast(0L) else -1L)
            .putString(KEY_APP_PACKAGE, current?.packageName.orEmpty())
            .putString(KEY_APP_LABEL, label)
            .putString(KEY_APP_CATEGORY, current?.appCategory ?: "unknown")
            .putString(KEY_APP_SOURCE, current?.source ?: "none")
            .putLong(KEY_APP_AGE_MS, current?.ageMs ?: -1L)
            .putBoolean(KEY_LABEL_RESOLVED, label.isNotBlank())
            .putString(KEY_APP_RESULT, if (current == null) "unresolved" else "resolved")
            .putInt(KEY_APP_RETRY_COUNT, retryCount)
            .putString(KEY_OVERLAY_ASSESSMENT, overlayAssessment)
            .putBoolean(KEY_NOTIFICATION_POSTED, notification["posted"] == true)
            .putString(KEY_NOTIFICATION_REASON, notification["reason"]?.toString().orEmpty())
            .putString(KEY_NOTIFICATION_CHANNEL, notification["channelId"]?.toString().orEmpty())
            .apply()

        NativeEventStore.addDeviceEvent(
            context,
            source = "system",
            eventType = "delayed_proactive_test_completed",
            appPackage = context.packageName,
            summary = "5分钟跨 App 主动联系测试已执行。",
            metadata = mapOf(
                "latencyBucket" to latencyBucket(if (dueAt > 0L) now - dueAt else -1L),
                "currentAppSource" to (current?.source ?: "none"),
                "currentAppAgeBucket" to ageBucket(current?.ageMs ?: -1L),
                "currentAppLabelResolved" to label.isNotBlank(),
                "currentAppResult" to if (current == null) "unresolved" else "resolved",
                "currentAppRetryCount" to retryCount,
                "currentAppPackageHash" to CompanionRuntimeState.privacyHash(
                    current?.packageName.orEmpty(),
                ),
                "overlayAssessment" to overlayAssessment,
                "notificationPosted" to (notification["posted"] == true),
                "notificationReason" to notification["reason"]?.toString().orEmpty(),
                "rawAppIncluded" to false,
                "memoryWritten" to false,
                "modelCalled" to false,
            ),
        )
    }

    companion object {
        private const val PREFS = "delayed_proactive_test"
        private const val REQUEST_CODE = 4217
        private const val EXTRA_DUE_AT = "due_at"
        private const val EXTRA_SOUND_KEY = "sound_key"
        private const val KEY_STATUS = "status"
        private const val KEY_SCHEDULED_AT = "scheduled_at"
        private const val KEY_DUE_AT = "due_at"
        private const val KEY_FIRED_AT = "fired_at"
        private const val KEY_LATENCY_MS = "latency_ms"
        private const val KEY_SOUND_KEY = "sound_key"
        private const val KEY_APP_PACKAGE = "app_package"
        private const val KEY_APP_LABEL = "app_label"
        private const val KEY_APP_CATEGORY = "app_category"
        private const val KEY_APP_SOURCE = "app_source"
        private const val KEY_APP_AGE_MS = "app_age_ms"
        private const val KEY_LABEL_RESOLVED = "label_resolved"
        private const val KEY_APP_RESULT = "app_result"
        private const val KEY_APP_RETRY_COUNT = "app_retry_count"
        private const val KEY_OVERLAY_ASSESSMENT = "overlay_assessment"
        private const val KEY_NOTIFICATION_POSTED = "notification_posted"
        private const val KEY_NOTIFICATION_REASON = "notification_reason"
        private const val KEY_NOTIFICATION_CHANNEL = "notification_channel"

        fun schedule(
            context: Context,
            delayMs: Long,
            soundKey: String,
        ): Map<String, Any> {
            val now = System.currentTimeMillis()
            val safeDelay = delayMs.coerceIn(30_000L, 60 * 60_000L)
            val dueAt = now + safeDelay
            val normalizedSound = normalizeSound(soundKey)
            val manager = context.getSystemService(AlarmManager::class.java)
            val pending = pendingIntent(context, dueAt, normalizedSound)
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAt, pending)
            prefs(context).edit()
                .clear()
                .putString(KEY_STATUS, "scheduled")
                .putLong(KEY_SCHEDULED_AT, now)
                .putLong(KEY_DUE_AT, dueAt)
                .putString(KEY_SOUND_KEY, normalizedSound)
                .apply()
            NativeEventStore.addDeviceEvent(
                context,
                source = "system",
                eventType = "delayed_proactive_test_scheduled",
                appPackage = context.packageName,
                summary = "已安排一次约5分钟后的跨 App 主动联系测试。",
                metadata = mapOf(
                    "delaySeconds" to safeDelay / 1000L,
                    "sound" to normalizedSound,
                    "exactAlarm" to false,
                    "memoryWillBeWritten" to false,
                ),
            )
            return status(context)
        }

        fun cancel(context: Context): Map<String, Any> {
            val previous = prefs(context)
            val dueAt = previous.getLong(KEY_DUE_AT, 0L)
            val sound = previous.getString(KEY_SOUND_KEY, "chime") ?: "chime"
            context.getSystemService(AlarmManager::class.java)
                .cancel(pendingIntent(context, dueAt, sound))
            previous.edit().putString(KEY_STATUS, "cancelled").apply()
            return status(context)
        }

        fun restoreIfScheduled(context: Context) {
            val snapshot = status(context)
            if (snapshot["status"] != "scheduled") return
            val dueAt = snapshot["dueAt"] as? Long ?: return
            val remaining = dueAt - System.currentTimeMillis()
            if (remaining <= 0L) {
                pendingIntent(
                    context,
                    dueAt,
                    snapshot["soundKey"]?.toString() ?: "chime",
                ).send()
            } else {
                val manager = context.getSystemService(AlarmManager::class.java)
                manager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    dueAt,
                    pendingIntent(
                        context,
                        dueAt,
                        snapshot["soundKey"]?.toString() ?: "chime",
                    ),
                )
            }
        }

        fun status(context: Context): Map<String, Any> {
            val p = prefs(context)
            return mapOf(
                "status" to (p.getString(KEY_STATUS, "idle") ?: "idle"),
                "scheduledAt" to p.getLong(KEY_SCHEDULED_AT, 0L),
                "dueAt" to p.getLong(KEY_DUE_AT, 0L),
                "firedAt" to p.getLong(KEY_FIRED_AT, 0L),
                "latencyMs" to p.getLong(KEY_LATENCY_MS, -1L),
                "soundKey" to (p.getString(KEY_SOUND_KEY, "chime") ?: "chime"),
                "appLabel" to (p.getString(KEY_APP_LABEL, "") ?: ""),
                "appCategory" to (p.getString(KEY_APP_CATEGORY, "unknown") ?: "unknown"),
                "appSource" to (p.getString(KEY_APP_SOURCE, "none") ?: "none"),
                "appAgeMs" to p.getLong(KEY_APP_AGE_MS, -1L),
                "labelResolved" to p.getBoolean(KEY_LABEL_RESOLVED, false),
                "appResolutionResult" to
                    (p.getString(KEY_APP_RESULT, "not_run") ?: "not_run"),
                "appRetryCount" to p.getInt(KEY_APP_RETRY_COUNT, 0),
                "overlayAssessment" to
                    (p.getString(KEY_OVERLAY_ASSESSMENT, "") ?: ""),
                "notificationPosted" to p.getBoolean(KEY_NOTIFICATION_POSTED, false),
                "notificationReason" to
                    (p.getString(KEY_NOTIFICATION_REASON, "") ?: ""),
                "notificationChannel" to
                    (p.getString(KEY_NOTIFICATION_CHANNEL, "") ?: ""),
                "memoryWritten" to false,
                "modelCalled" to false,
            )
        }

        fun diagnosticStatus(context: Context): Map<String, Any> {
            val p = prefs(context)
            val packageName = p.getString(KEY_APP_PACKAGE, "") ?: ""
            val label = p.getString(KEY_APP_LABEL, "") ?: ""
            return mapOf(
                "delayedProactiveTestStatus" to
                    (p.getString(KEY_STATUS, "idle") ?: "idle"),
                "delayedProactiveTestScheduledAt" to p.getLong(KEY_SCHEDULED_AT, 0L),
                "delayedProactiveTestDueAt" to p.getLong(KEY_DUE_AT, 0L),
                "delayedProactiveTestFiredAt" to p.getLong(KEY_FIRED_AT, 0L),
                "delayedProactiveTestLatencyMs" to p.getLong(KEY_LATENCY_MS, -1L),
                "delayedProactiveTestAppSource" to
                    (p.getString(KEY_APP_SOURCE, "none") ?: "none"),
                "delayedProactiveTestAppAgeMs" to p.getLong(KEY_APP_AGE_MS, -1L),
                "delayedProactiveTestAppCategory" to
                    (p.getString(KEY_APP_CATEGORY, "unknown") ?: "unknown"),
                "delayedProactiveTestPackageHash" to
                    CompanionRuntimeState.privacyHash(packageName),
                "delayedProactiveTestLabelHash" to
                    CompanionRuntimeState.privacyHash(label),
                "delayedProactiveTestLabelResolved" to
                    p.getBoolean(KEY_LABEL_RESOLVED, false),
                "delayedProactiveTestAppResolutionResult" to
                    (p.getString(KEY_APP_RESULT, "not_run") ?: "not_run"),
                "delayedProactiveTestAppRetryCount" to
                    p.getInt(KEY_APP_RETRY_COUNT, 0),
                "delayedProactiveTestOverlayAssessment" to
                    (p.getString(KEY_OVERLAY_ASSESSMENT, "") ?: ""),
                "delayedProactiveTestNotificationPosted" to
                    p.getBoolean(KEY_NOTIFICATION_POSTED, false),
                "delayedProactiveTestNotificationReason" to
                    (p.getString(KEY_NOTIFICATION_REASON, "") ?: ""),
                "delayedProactiveTestRawAppIncluded" to false,
                "delayedProactiveTestMemoryWritten" to false,
                "delayedProactiveTestModelCalled" to false,
            )
        }

        private fun pendingIntent(context: Context, dueAt: Long, soundKey: String): PendingIntent {
            val intent = Intent(context, DelayedProactiveTestReceiver::class.java)
                .putExtra(EXTRA_DUE_AT, dueAt)
                .putExtra(EXTRA_SOUND_KEY, normalizeSound(soundKey))
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun normalizeSound(raw: String?): String = when (raw) {
            "soft", "system", "silent" -> raw
            else -> "chime"
        }

        private fun overlayAssessment(context: Context): String {
            val power = context.getSystemService(PowerManager::class.java)
            return when {
                !CompanionRuntimeState.isOverlayUserEnabled(context) -> "user_disabled"
                !OverlayBubbleService.running -> "service_not_running"
                !CompanionRuntimeState.overlayBubbleAttached -> "view_detached"
                !power.isInteractive -> "screen_off"
                !CompanionRuntimeState.overlayVisible -> "internally_hidden"
                CompanionRuntimeState.isOverlaySystemCoverActive() -> "known_system_cover"
                else -> "attached_external_suppression_not_observable"
            }
        }

        private fun latencyBucket(value: Long): String = when {
            value < 0L -> "unknown"
            value < 15_000L -> "under_15s"
            value < 60_000L -> "15s_60s"
            value < 5 * 60_000L -> "1m_5m"
            else -> "over_5m"
        }

        private fun ageBucket(value: Long): String = when {
            value < 0L -> "unknown"
            value < 5_000L -> "under_5s"
            value < 30_000L -> "5s_30s"
            value < 120_000L -> "30s_2m"
            else -> "over_2m"
        }
    }
}
