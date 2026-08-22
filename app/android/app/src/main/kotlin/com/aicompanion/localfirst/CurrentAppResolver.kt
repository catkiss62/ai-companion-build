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

/** One native source of truth for full-App, overlay/background and alarm tests.
 *
 * Accessibility has the freshest window signal, but an AI Companion overlay
 * window must not replace the real app underneath it. A stale/self snapshot
 * therefore falls through to UsageEvents and finally UsageStats.
 */
object CurrentAppResolver {
    private const val ACCESSIBILITY_MAX_AGE_MS = 90_000L
    private const val USAGE_EVENT_MAX_AGE_MS = 120_000L
    private const val USAGE_STATS_MAX_AGE_MS = 120_000L

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
                if (isIgnoredPackage(context, packageName)) continue
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

        val current = resolveCurrent(context, eventCount)
        if (current != null) output += current.asUsageEvent(now)
        return output
    }

    fun resolveCurrent(context: Context, knownEventCount: Int = 0): ResolvedCurrentApp? {
        val now = System.currentTimeMillis()
        val power = context.getSystemService(PowerManager::class.java)
        if (!power.isInteractive) {
            noteFusion("screen_off", -1L, knownEventCount, false)
            return null
        }

        val accessibility = CompanionRuntimeState.foregroundWindowSnapshot()
        val accessibilityAge = accessibility
            ?.let { (now - it.observedAt).coerceAtLeast(0L) }
            ?: Long.MAX_VALUE
        if (accessibility != null && accessibilityAge <= ACCESSIBILITY_MAX_AGE_MS) {
            val selfWindow = accessibility.packageName == context.packageName
            if (!selfWindow || !CompanionRuntimeState.isAppVisible()) {
                if (!selfWindow && !isIgnoredPackage(context, accessibility.packageName)) {
                    return resolved(
                        context,
                        accessibility.packageName,
                        "accessibility_window",
                        accessibility.observedAt,
                        now,
                        knownEventCount,
                    )
                }
                // A self-owned overlay window is transparent to app identity.
                // Continue to UsageEvents instead of returning unknown.
            } else {
                noteFusion("self_activity", accessibilityAge, knownEventCount, false)
                return null
            }
        }

        if (!hasUsageAccess(context)) {
            noteFusion("usage_unavailable", -1L, knownEventCount, false)
            return null
        }
        val manager = context.getSystemService(UsageStatsManager::class.java)
        val events = manager.queryEvents((now - 10 * 60_000L).coerceAtLeast(0L), now)
        val event = UsageEvents.Event()
        var currentPackage = ""
        var observedAt = 0L
        var eventCount = 0
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (isIgnoredPackage(context, packageName)) continue
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    currentPackage = packageName
                    observedAt = event.timeStamp
                    eventCount += 1
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> if (currentPackage == packageName) {
                    currentPackage = ""
                    observedAt = 0L
                    eventCount += 1
                }
            }
        }
        if (currentPackage.isNotBlank() && now - observedAt <= USAGE_EVENT_MAX_AGE_MS) {
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
                (now - 10 * 60_000L).coerceAtLeast(0L),
                now,
            ).filter {
                !isIgnoredPackage(context, it.packageName) && it.lastTimeUsed > 0L
            }.maxByOrNull { it.lastTimeUsed }
        }.getOrNull()
        if (fallback != null && now - fallback.lastTimeUsed <= USAGE_STATS_MAX_AGE_MS) {
            return resolved(
                context,
                fallback.packageName,
                "usage_stats_fallback",
                fallback.lastTimeUsed,
                now,
                maxOf(knownEventCount, eventCount),
            )
        }
        noteFusion(
            if (accessibility?.packageName == context.packageName) "self_overlay_fallback_empty" else "none",
            accessibilityAge.takeIf { it != Long.MAX_VALUE } ?: -1L,
            maxOf(knownEventCount, eventCount),
            false,
        )
        return null
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

    private fun isIgnoredPackage(context: Context, packageName: String): Boolean =
        packageName == context.packageName ||
            packageName == "com.android.systemui" ||
            packageName == "com.miui.home" ||
            packageName == "com.android.launcher" ||
            packageName == "com.google.android.apps.nexuslauncher"

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
