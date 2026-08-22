package com.aicompanion.localfirst

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Minimal system channel exposed to the background FlutterEngine.
 *
 * Deliberately does not expose permission prompts, Nearby UI, or settings
 * screens: the background brain may observe already-granted capabilities and
 * publish a companion message, but may not initiate user-facing permission
 * flows by itself.
 */
class BackgroundSystemBridge(
    private val context: Context,
    flutterEngine: FlutterEngine,
) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceLabel" -> result.success(deviceLabel())
                "getPerceptionState" -> result.success(perceptionState())
                "getRecentUsage" -> result.success(
                    CurrentAppResolver.recentUsage(
                        context,
                        call.argument<Int>("minutes") ?: 60,
                    ),
                )
                "setOverlayUnread" -> {
                    setOverlayUnread(call.argument<Int>("count") ?: 0)
                    result.success(null)
                }
                "incrementOverlayUnread" -> {
                    val prefs = context.getSharedPreferences(
                        OverlayBubbleService.PREFS,
                        Context.MODE_PRIVATE,
                    )
                    setOverlayUnread(prefs.getInt(OverlayBubbleService.KEY_UNREAD, 0) + 1)
                    result.success(null)
                }
                "clearOverlayUnread" -> {
                    setOverlayUnread(0)
                    result.success(null)
                }
                "postCompanionNotification" -> {
                    CompanionNotification.postMessage(
                        context,
                        call.argument<String>("title") ?: "她找你",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("messageId")
                            ?: System.currentTimeMillis().toString(),
                        call.argument<String>("intentKind") ?: "",
                        call.argument<String>("deliveryStyle") ?: "normal",
                        call.argument<String>("soundKey") ?: "chime",
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }


    private fun setOverlayUnread(count: Int) {
        val safe = count.coerceAtLeast(0)
        context.getSharedPreferences(OverlayBubbleService.PREFS, Context.MODE_PRIVATE)
            .edit().putInt(OverlayBubbleService.KEY_UNREAD, safe).apply()
        if (OverlayBubbleService.running) {
            runCatching {
                context.startService(
                    Intent(context, OverlayBubbleService::class.java)
                        .setAction(OverlayBubbleService.ACTION_SET_UNREAD)
                        .putExtra(OverlayBubbleService.EXTRA_COUNT, safe),
                )
            }
        }
    }

    private fun hasUsageAccess(): Boolean {
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

    private fun deviceLabel(): String = "${Build.MANUFACTURER} ${Build.MODEL}"
        .trim()
        .ifBlank { "Android device" }
        .take(80)

    private fun perceptionState(): Map<String, Any> {
        val power = context.getSystemService(PowerManager::class.java)
        val keyguard = context.getSystemService(KeyguardManager::class.java)
        return mapOf(
            "usageAccess" to hasUsageAccess(),
            "screenInteractive" to power.isInteractive,
            "deviceLocked" to keyguard.isDeviceLocked,
            "notificationListenerConnected" to CompanionRuntimeState.notificationListenerConnected,
            "accessibilityConnected" to CompanionRuntimeState.accessibilityConnected,
        )
    }

    @Suppress("DEPRECATION")
    private fun appCategory(packageName: String): String {
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

    private fun recentUsage(minutes: Int): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val manager = context.getSystemService(UsageStatsManager::class.java)
        val end = System.currentTimeMillis()
        val start = end - minutes.coerceIn(1, 24 * 60) * 60_000L
        val events = manager.queryEvents(start, end)
        val event = UsageEvents.Event()
        val output = ArrayList<Map<String, Any>>()
        val categoryCache = HashMap<String, String>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName == null || event.packageName == context.packageName) continue
            val label = when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> "foreground"
                UsageEvents.Event.ACTIVITY_PAUSED -> "background"
                UsageEvents.Event.USER_INTERACTION -> "interaction"
                else -> null
            } ?: continue
            output += mapOf(
                "packageName" to event.packageName,
                "timestamp" to event.timeStamp,
                "eventType" to label,
                "appCategory" to categoryCache.getOrPut(event.packageName) { appCategory(event.packageName) },
            )
            if (output.size > 200) output.removeAt(0)
        }
        return output
    }

    companion object {
        private const val METHOD_CHANNEL = "ai_companion/system"
    }
}
