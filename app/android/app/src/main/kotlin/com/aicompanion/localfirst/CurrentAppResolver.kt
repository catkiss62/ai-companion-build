package com.aicompanion.localfirst

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.Process

data class ResolvedCurrentApp(
    val packageName: String,
    val appLabel: String,
    val appCategory: String,
    val source: String,
    val observedAt: Long,
    val ageMs: Long,
    val usageEventCount: Int,
) {
    fun asUsageEvent(now: Long = System.currentTimeMillis()): Map<String, Any> = mapOf(
        "packageName" to packageName,
        "timestamp" to now,
        "eventType" to "foreground",
        "appCategory" to appCategory,
        "appLabel" to appLabel,
        "contextSource" to source,
    )
}

/**
 * Shared current-App truth for the full app, overlay/background and alarms.
 * Accessibility continuously tracks the real external window. UsageEvents and
 * UsageStats are deliberately short-window fallbacks, not one-shot truth.
 */
object CurrentAppResolver {
    private const val PREFS = "current_app_tracker"
    private const val KEY_PACKAGE = "package"
    private const val KEY_OBSERVED_AT = "observed_at"
    private const val KEY_SOURCE = "source"
    private const val KEY_INVALIDATED_AT = "invalidated_at"
    private const val KEY_INVALIDATION_REASON = "invalidation_reason"
    private const val KEY_WINDOW_PROBE_AT = "window_probe_at"
    private const val KEY_WINDOW_COUNT = "window_count"
    private const val KEY_WINDOW_ACTIVE_COUNT = "window_active_count"
    private const val KEY_WINDOW_FOCUSED_COUNT = "window_focused_count"
    private const val KEY_WINDOW_CANDIDATE_COUNT = "window_candidate_count"
    private const val KEY_WINDOW_RESULT = "window_result"
    private const val KEY_LAST_RETRY_COUNT = "last_retry_count"
    private const val KEY_LAST_RETRY_RESULT = "last_retry_result"
    private const val KEY_LAST_RETRY_AT = "last_retry_at"

    // Screen-off/launcher explicitly clears the tracker. This long lifetime
    // lets a game stay foreground for hours without becoming falsely stale.
    private const val TRACKED_APP_MAX_AGE_MS = 24 * 60 * 60_000L
    private const val USAGE_EVENT_LOOKBACK_MS = 30_000L
    private const val USAGE_EVENT_MAX_AGE_MS = 15_000L
    private const val USAGE_STATS_MAX_AGE_MS = 15_000L
    // A proactive prompt may run long after the foreground Activity resumed.
    // This wider window is used only by the explicit retry path. The
    // invalidated-at boundary (screen off / launcher) below still prevents an
    // app from leaking across a device-state transition.
    private const val PROACTIVE_USAGE_STATS_MAX_AGE_MS = 6 * 60 * 60_000L

    fun recentUsage(context: Context, minutes: Int): List<Map<String, Any>> {
        val now = System.currentTimeMillis()
        val manager = context.getSystemService(UsageStatsManager::class.java)
        val start = now - minutes.coerceIn(1, 24 * 60) * 60_000L
        val output = ArrayList<Map<String, Any>>()
        val categoryCache = HashMap<String, String>()
        val labelCache = HashMap<String, String>()
        var eventCount = 0

        if (hasUsageAccess(context)) {
            val events = manager.queryEvents(start, now)
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val packageName = event.packageName ?: continue
                if (!isTrackablePackage(context, packageName)) continue
                val type = when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> "foreground"
                    UsageEvents.Event.ACTIVITY_PAUSED -> "background"
                    UsageEvents.Event.USER_INTERACTION -> "interaction"
                    else -> null
                } ?: continue
                eventCount += 1
                output += mapOf(
                    "packageName" to packageName,
                    "timestamp" to event.timeStamp,
                    "eventType" to type,
                    "appCategory" to categoryCache.getOrPut(packageName) {
                        appCategory(context, packageName)
                    },
                    "appLabel" to labelCache.getOrPut(packageName) {
                        appLabel(context, packageName)
                    },
                    "contextSource" to "usage_events",
                )
                if (output.size > 200) output.removeAt(0)
            }
        }
        resolveCurrent(context, eventCount)?.let { output += it.asUsageEvent(now) }
        return output
    }

    /** Called only for a real external Accessibility window, never its text. */
    fun noteForegroundApp(context: Context, packageName: String, source: String) {
        if (!isTrackablePackage(context, packageName)) return
        val now = System.currentTimeMillis()
        CompanionRuntimeState.noteForegroundWindow(packageName)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_PACKAGE, packageName)
            .putLong(KEY_OBSERVED_AT, now)
            .putString(KEY_SOURCE, source.take(40))
            .apply()
    }

    /** Launcher/screen-off are boundaries; an old app cannot leak across them. */
    fun clearTrackedApp(context: Context, reason: String) {
        val now = System.currentTimeMillis()
        CompanionRuntimeState.clearForegroundWindow()
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(KEY_PACKAGE)
            .remove(KEY_OBSERVED_AT)
            .remove(KEY_SOURCE)
            .putLong(KEY_INVALIDATED_AT, now)
            .putString(KEY_INVALIDATION_REASON, reason.take(60))
            .apply()
    }

    fun noteWindowProbe(
        context: Context,
        total: Int,
        active: Int,
        focused: Int,
        candidates: Int,
        result: String,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_WINDOW_PROBE_AT, System.currentTimeMillis())
            .putInt(KEY_WINDOW_COUNT, total.coerceAtLeast(0))
            .putInt(KEY_WINDOW_ACTIVE_COUNT, active.coerceAtLeast(0))
            .putInt(KEY_WINDOW_FOCUSED_COUNT, focused.coerceAtLeast(0))
            .putInt(KEY_WINDOW_CANDIDATE_COUNT, candidates.coerceAtLeast(0))
            .putString(KEY_WINDOW_RESULT, result.take(60))
            .apply()
    }

    fun resolveCurrentWithRetries(
        context: Context,
        attempts: Int = 3,
        retryDelayMs: Long = 350L,
        usageStatsMaxAgeMs: Long = USAGE_STATS_MAX_AGE_MS,
    ): ResolvedCurrentApp? {
        val safeAttempts = attempts.coerceIn(1, 4)
        var result: ResolvedCurrentApp? = null
        var used = 0
        for (index in 0 until safeAttempts) {
            used = index + 1
            result = resolveCurrent(
                context,
                usageStatsMaxAgeMs = usageStatsMaxAgeMs,
            )
            if (result != null) break
            if (index < safeAttempts - 1) Thread.sleep(retryDelayMs.coerceIn(100L, 600L))
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt(KEY_LAST_RETRY_COUNT, used)
            .putString(KEY_LAST_RETRY_RESULT, result?.source ?: "none")
            .putLong(KEY_LAST_RETRY_AT, System.currentTimeMillis())
            .apply()
        return result
    }

    fun resolveCurrentForProactiveWithRetries(context: Context): ResolvedCurrentApp? =
        resolveCurrentWithRetries(
            context,
            usageStatsMaxAgeMs = PROACTIVE_USAGE_STATS_MAX_AGE_MS,
        )

    fun resolveCurrent(
        context: Context,
        knownEventCount: Int = 0,
        usageStatsMaxAgeMs: Long = USAGE_STATS_MAX_AGE_MS,
    ): ResolvedCurrentApp? {
        val now = System.currentTimeMillis()
        val power = context.getSystemService(PowerManager::class.java)
        if (!power.isInteractive) {
            clearTrackedApp(context, "screen_off_probe")
            noteFusion("screen_off", -1L, knownEventCount, false)
            return null
        }
        if (CompanionRuntimeState.isAppVisible()) {
            noteFusion("self_activity", 0L, knownEventCount, false)
            return null
        }

        val processSnapshot = CompanionRuntimeState.foregroundWindowSnapshot()
        val persisted = trackedSnapshot(context)
        val accessibility = listOfNotNull(
            processSnapshot?.let {
                Triple(
                    it.packageName,
                    it.observedAt,
                    persisted?.takeIf { saved -> saved.first == it.packageName }?.third
                        ?: "accessibility_window",
                )
            },
            persisted,
        ).filter {
            isTrackablePackage(context, it.first) &&
                now - it.second in 0..TRACKED_APP_MAX_AGE_MS
        }.maxByOrNull { it.second }
        if (accessibility != null) {
            return resolved(
                context,
                accessibility.first,
                accessibility.third,
                accessibility.second,
                now,
                knownEventCount,
            )
        }

        if (!hasUsageAccess(context)) {
            noteFusion("usage_unavailable", -1L, knownEventCount, false)
            return null
        }
        val manager = context.getSystemService(UsageStatsManager::class.java)
        val invalidatedAt = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_INVALIDATED_AT, 0L)
        val events = manager.queryEvents((now - USAGE_EVENT_LOOKBACK_MS).coerceAtLeast(0L), now)
        val event = UsageEvents.Event()
        var currentPackage = ""
        var observedAt = 0L
        var eventCount = 0
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (!isTrackablePackage(context, packageName)) continue
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                eventCount += 1
                if (event.timeStamp >= observedAt) {
                    currentPackage = packageName
                    observedAt = event.timeStamp
                }
            }
        }
        if (currentPackage.isNotBlank() && observedAt > invalidatedAt &&
            now - observedAt <= USAGE_EVENT_MAX_AGE_MS
        ) {
            noteForegroundApp(context, currentPackage, "usage_events")
            return resolved(
                context,
                currentPackage,
                "usage_events",
                observedAt,
                now,
                maxOf(knownEventCount, eventCount),
            )
        }

        val fallback = runCatching {
            manager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                (now - USAGE_EVENT_LOOKBACK_MS).coerceAtLeast(0L),
                now,
            ).filter {
                isTrackablePackage(context, it.packageName) && it.lastTimeUsed > invalidatedAt
            }.maxByOrNull { it.lastTimeUsed }
        }.getOrNull()
        val safeUsageStatsAge = usageStatsMaxAgeMs.coerceIn(
            USAGE_STATS_MAX_AGE_MS,
            PROACTIVE_USAGE_STATS_MAX_AGE_MS,
        )
        if (fallback != null && now - fallback.lastTimeUsed <= safeUsageStatsAge) {
            noteForegroundApp(context, fallback.packageName, "usage_stats_fallback")
            return resolved(
                context,
                fallback.packageName,
                "usage_stats_fallback",
                fallback.lastTimeUsed,
                now,
                maxOf(knownEventCount, eventCount),
            )
        }
        noteFusion("none", -1L, maxOf(knownEventCount, eventCount), false)
        return null
    }

    fun diagnosticStatus(context: Context): Map<String, Any> {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val packageName = p.getString(KEY_PACKAGE, "").orEmpty()
        val observedAt = p.getLong(KEY_OBSERVED_AT, 0L)
        return mapOf(
            "currentAppTrackerHasCandidate" to packageName.isNotBlank(),
            "currentAppTrackerPackageHash" to CompanionRuntimeState.privacyHash(packageName),
            "currentAppTrackerObservedAt" to observedAt,
            "currentAppTrackerAgeMs" to (
                observedAt.takeIf { it > 0L }
                    ?.let { (System.currentTimeMillis() - it).coerceAtLeast(0L) }
                    ?: -1L
            ),
            "currentAppTrackerSource" to p.getString(KEY_SOURCE, "").orEmpty(),
            "currentAppTrackerInvalidatedAt" to p.getLong(KEY_INVALIDATED_AT, 0L),
            "currentAppTrackerInvalidationReason" to
                p.getString(KEY_INVALIDATION_REASON, "").orEmpty(),
            "currentAppWindowProbeAt" to p.getLong(KEY_WINDOW_PROBE_AT, 0L),
            "currentAppWindowCount" to p.getInt(KEY_WINDOW_COUNT, 0),
            "currentAppWindowActiveCount" to p.getInt(KEY_WINDOW_ACTIVE_COUNT, 0),
            "currentAppWindowFocusedCount" to p.getInt(KEY_WINDOW_FOCUSED_COUNT, 0),
            "currentAppWindowCandidateCount" to p.getInt(KEY_WINDOW_CANDIDATE_COUNT, 0),
            "currentAppWindowResult" to p.getString(KEY_WINDOW_RESULT, "").orEmpty(),
            "currentAppLastRetryCount" to p.getInt(KEY_LAST_RETRY_COUNT, 0),
            "currentAppLastRetryResult" to p.getString(KEY_LAST_RETRY_RESULT, "").orEmpty(),
            "currentAppLastRetryAt" to p.getLong(KEY_LAST_RETRY_AT, 0L),
            "currentAppTrackerRawPackageIncluded" to false,
        )
    }

    private fun trackedSnapshot(context: Context): Triple<String, Long, String>? {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val packageName = p.getString(KEY_PACKAGE, "").orEmpty()
        val observedAt = p.getLong(KEY_OBSERVED_AT, 0L)
        if (packageName.isBlank() || observedAt <= p.getLong(KEY_INVALIDATED_AT, 0L)) return null
        return Triple(
            packageName,
            observedAt,
            p.getString(KEY_SOURCE, "accessibility_window").orEmpty(),
        )
    }

    private fun resolved(
        context: Context,
        packageName: String,
        source: String,
        observedAt: Long,
        now: Long,
        eventCount: Int,
    ): ResolvedCurrentApp {
        val label = appLabel(context, packageName)
        val result = ResolvedCurrentApp(
            packageName = packageName,
            appLabel = label,
            appCategory = appCategory(context, packageName),
            source = source,
            observedAt = observedAt,
            ageMs = (now - observedAt).coerceAtLeast(0L),
            usageEventCount = eventCount,
        )
        noteFusion(source, result.ageMs, eventCount, label.isNotBlank())
        return result
    }

    private fun noteFusion(source: String, ageMs: Long, count: Int, labelResolved: Boolean) {
        CompanionRuntimeState.noteCurrentAppFusion(source, ageMs, count, labelResolved)
    }

    @Suppress("DEPRECATION")
    fun appLabel(context: Context, packageName: String): String {
        val info = runCatching {
            if (Build.VERSION.SDK_INT >= 33) {
                context.packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                context.packageManager.getApplicationInfo(packageName, 0)
            }
        }.getOrNull() ?: return ""
        return runCatching {
            context.packageManager.getApplicationLabel(info).toString()
                .replace(Regex("\\s+"), " ").trim().take(80)
        }.getOrDefault("")
    }

    @Suppress("DEPRECATION")
    fun appCategory(context: Context, packageName: String): String {
        val info = runCatching {
            if (Build.VERSION.SDK_INT >= 33) {
                context.packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                context.packageManager.getApplicationInfo(packageName, 0)
            }
        }.getOrNull() ?: return "unknown"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return when (info.category) {
                ApplicationInfo.CATEGORY_GAME -> "game"
                ApplicationInfo.CATEGORY_AUDIO -> "audio"
                ApplicationInfo.CATEGORY_VIDEO -> "video"
                ApplicationInfo.CATEGORY_IMAGE -> "image"
                ApplicationInfo.CATEGORY_SOCIAL -> "social"
                ApplicationInfo.CATEGORY_NEWS -> "news"
                ApplicationInfo.CATEGORY_MAPS -> "maps"
                ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
                else -> if ((info.flags and ApplicationInfo.FLAG_IS_GAME) != 0) "game" else "unknown"
            }
        }
        return if ((info.flags and ApplicationInfo.FLAG_IS_GAME) != 0) "game" else "unknown"
    }

    fun isTrackablePackage(context: Context, packageName: String): Boolean =
        packageName.isNotBlank() && !isIgnoredPackage(context, packageName)

    fun isLauncherPackage(packageName: String): Boolean =
        packageName == "com.miui.home" ||
            packageName == "com.android.launcher" ||
            packageName == "com.google.android.apps.nexuslauncher"

    private fun isIgnoredPackage(context: Context, packageName: String): Boolean =
        packageName == context.packageName ||
            packageName == "com.android.systemui" ||
            isLauncherPackage(packageName)

    private fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
