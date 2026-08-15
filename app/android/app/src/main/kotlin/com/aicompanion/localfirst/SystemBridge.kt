package com.aicompanion.localfirst

import android.Manifest
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.app.Activity
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import com.aicompanion.localfirst.pet.PetPreviewActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.UUID

class SystemBridge(
    private val activity: android.app.Activity,
    flutterEngine: FlutterEngine,
) {
    private val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
    private val nearbyEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, NEARBY_EVENT_CHANNEL)
    private val nearby = NearbyTransferManager.get(activity)
    private val nearbyOwnerId = UUID.randomUUID().toString()
    private var nearbySink: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null
    private var permissionRequestCode: Int? = null
    private var manualDocumentResult: MethodChannel.Result? = null
    private var manualPassphrase: CharArray? = null
    private var manualSourcePath: String? = null
    private var manualOperation: String? = null
    private var reportDocumentResult: MethodChannel.Result? = null
    private var reportSourcePath: String? = null

    init {
        nearbyEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                nearbySink = events
                nearby.addListener(nearbyOwnerId) { message -> nearbySink?.success(message) }
            }

            override fun onCancel(arguments: Any?) {
                nearby.removeListener(nearbyOwnerId)
                nearbySink = null
            }
        })

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilityStatus" -> result.success(capabilityStatus())
                "preflightStatus" -> result.success(preflightStatus())
                "runtimeDiagnostics" -> result.success(
                    RuntimeDiagnosticStore.snapshot(activity, call.argument<Int>("limit") ?: 120),
                )
                "clearRuntimeDiagnostics" -> {
                    RuntimeDiagnosticStore.clear(activity)
                    result.success(null)
                }
                "openDesktopPetPreview" -> {
                    PetPreviewActivity.launch(activity)
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    activity.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${activity.packageName}"),
                        ),
                    )
                    result.success(null)
                }
                "openUsageSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openNotificationListenerSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "requestNotificationPermission" -> requestNotifications(result)
                "requestNearbyPermissions" -> requestNearbyPermissions(result)
                "startOverlay" -> {
                    OverlayBubbleService.startUserEnabled(activity)
                    result.success(null)
                }
                "stopOverlay" -> {
                    OverlayBubbleService.stopUserEnabled(activity)
                    result.success(null)
                }
                "setOverlayEntryMode" -> {
                    OverlayBubbleService.setEntryMode(
                        activity,
                        call.argument<String>("mode") ?: OverlayBubbleService.ENTRY_MODE_BUBBLE,
                    )
                    result.success(null)
                }
                "setPetOverlaySize" -> {
                    OverlayBubbleService.setPetSize(
                        activity,
                        call.argument<String>("size") ?: "medium",
                    )
                    result.success(null)
                }
                "suspendOverlayForStandby" -> {
                    OverlayBubbleService.stopForStandby(activity)
                    result.success(null)
                }
                "reconcileOverlayAfterTakeover" -> {
                    OverlayBubbleService.reconcileFromVisibleActivity(activity)
                    result.success(null)
                }
                "wakeBackgroundBrain" -> {
                    result.success(
                        OverlayBubbleService.requestBrainWake(
                            activity,
                            call.argument<String>("reason") ?: "full_app_wake",
                        ),
                    )
                }
                "setOverlayUnread" -> {
                    setOverlayUnread(call.argument<Int>("count") ?: 0)
                    result.success(null)
                }
                "incrementOverlayUnread" -> {
                    val prefs = activity.getSharedPreferences(OverlayBubbleService.PREFS, Context.MODE_PRIVATE)
                    setOverlayUnread(prefs.getInt(OverlayBubbleService.KEY_UNREAD, 0) + 1)
                    result.success(null)
                }
                "clearOverlayUnread" -> {
                    setOverlayUnread(0)
                    result.success(null)
                }
                "setPetConversationState" -> {
                    setPetConversationState(
                        generationActive = call.argument<Boolean>("generationActive") == true,
                        generationPhase = call.argument<String>("generationPhase") ?: "idle",
                        ttsPhase = call.argument<String>("ttsPhase") ?: "idle",
                    )
                    result.success(null)
                }
                "postCompanionNotification" -> {
                    CompanionNotification.postMessage(
                        activity,
                        call.argument<String>("title") ?: "AI Companion",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("messageId") ?: System.currentTimeMillis().toString(),
                        call.argument<String>("intentKind") ?: "",
                        call.argument<String>("deliveryStyle") ?: "normal",
                    )
                    result.success(null)
                }
                "deviceLabel" -> result.success(deviceLabel())
                "getPerceptionState" -> result.success(perceptionState())
                "getRecentUsage" -> result.success(recentUsage(call.argument<Int>("minutes") ?: 60))
                "startNearbyReceive" -> {
                    nearby.startAdvertising()
                    result.success(null)
                }
                "startNearbyDiscovery" -> {
                    nearby.startDiscovery()
                    result.success(null)
                }
                "stopNearby" -> {
                    nearby.stopAll()
                    result.success(null)
                }
                "connectNearby" -> {
                    nearby.requestConnection(call.argument<String>("endpointId") ?: "")
                    result.success(null)
                }
                "acceptNearbyConnection" -> {
                    nearby.acceptConnection(call.argument<String>("endpointId") ?: "")
                    result.success(null)
                }
                "rejectNearbyConnection" -> {
                    nearby.rejectConnection(call.argument<String>("endpointId") ?: "")
                    result.success(null)
                }
                "confirmNearbyTakeover" -> {
                    nearby.confirmTakeover(
                        endpointId = call.argument<String>("endpointId") ?: "",
                        snapshotId = call.argument<String>("snapshotId") ?: "",
                        lineageId = call.argument<String>("lineageId") ?: "",
                        sourceDeviceId = call.argument<String>("sourceDeviceId") ?: "",
                        sourceGeneration = (call.argument<Number>("sourceGeneration")?.toLong() ?: 0L),
                        stateSha256 = call.argument<String>("stateSha256") ?: "",
                        targetDeviceId = call.argument<String>("targetDeviceId") ?: "",
                        targetActivationGeneration = (call.argument<Number>("targetActivationGeneration")?.toLong() ?: 0L),
                    )
                    result.success(null)
                }
                "sendNearbyFile" -> {
                    nearby.sendFile(
                        endpointId = call.argument<String>("endpointId") ?: "",
                        path = call.argument<String>("filePath") ?: "",
                        snapshotId = call.argument<String>("snapshotId") ?: "",
                        lineageId = call.argument<String>("lineageId") ?: "",
                        sourceDeviceId = call.argument<String>("sourceDeviceId") ?: "",
                        sourceGeneration = (call.argument<Number>("sourceGeneration")?.toLong() ?: 0L),
                        stateSha256 = call.argument<String>("stateSha256") ?: "",
                    )
                    result.success(null)
                }
                "saveManualSnapshot" -> startManualSave(
                    sourcePath = call.argument<String>("sourcePath") ?: "",
                    passphrase = call.argument<String>("passphrase") ?: "",
                    suggestedName = call.argument<String>("suggestedName") ?: "ai_companion_transfer.aicomp",
                    result = result,
                )
                "openManualSnapshot" -> startManualOpen(
                    passphrase = call.argument<String>("passphrase") ?: "",
                    result = result,
                )
                "saveDiagnosticReport" -> startDiagnosticReportSave(
                    sourcePath = call.argument<String>("sourcePath") ?: "",
                    suggestedName = call.argument<String>("suggestedName") ?: "ai_companion_diagnostics.txt",
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        nearby.removeListener(nearbyOwnerId)
        nearbySink = null
        nearbyEventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        permissionResult?.error("activity_disposed", "Activity was destroyed during permission request", null)
        permissionResult = null
        permissionRequestCode = null
        manualDocumentResult?.error("activity_disposed", "Activity was destroyed during manual transfer", null)
        clearManualDocumentState()
        reportDocumentResult?.error("activity_disposed", "Activity was destroyed during diagnostic export", null)
        reportDocumentResult = null
        reportSourcePath = null
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (permissionRequestCode != requestCode) return
        val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        permissionResult?.success(ok)
        permissionResult = null
        permissionRequestCode = null
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_DIAGNOSTIC_SAVE) {
            val result = reportDocumentResult ?: return
            val sourcePath = reportSourcePath
            reportDocumentResult = null
            reportSourcePath = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null || sourcePath.isNullOrBlank()) {
                result.success(false)
                return
            }
            Thread {
                runCatching {
                    val source = File(sourcePath)
                    require(source.exists() && source.isFile) { "diagnostic_source_missing" }
                    activity.contentResolver.openOutputStream(uri, "w").use { output ->
                        requireNotNull(output)
                        FileInputStream(source).use { input -> input.copyTo(output) }
                    }
                    true
                }.onSuccess { saved -> activity.runOnUiThread { result.success(saved) } }
                    .onFailure { error ->
                        activity.runOnUiThread {
                            result.error("diagnostic_export_failed", error.javaClass.simpleName, null)
                        }
                    }
            }.start()
            return
        }
        if (requestCode != REQUEST_MANUAL_SAVE && requestCode != REQUEST_MANUAL_OPEN) return
        val result = manualDocumentResult ?: return
        val operation = manualOperation
        val passphrase = manualPassphrase
        val sourcePath = manualSourcePath
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || passphrase == null) {
            result.success(null)
            clearManualDocumentState()
            return
        }

        // Detach the one-shot state before background crypto so an Activity
        // callback cannot accidentally reuse the password/result a second time.
        manualDocumentResult = null
        manualPassphrase = null
        manualSourcePath = null
        manualOperation = null
        Thread {
            runCatching {
                when (operation) {
                    "save" -> {
                        val source = File(requireNotNull(sourcePath))
                        require(source.exists() && source.isFile) { "manual_snapshot_source_missing" }
                        val output = requireNotNull(activity.contentResolver.openOutputStream(uri, "w"))
                        ManualSnapshotCrypto.encrypt(source.inputStream(), output, passphrase)
                        mapOf("saved" to true, "uri" to uri.toString())
                    }
                    "open" -> {
                        val input = requireNotNull(activity.contentResolver.openInputStream(uri))
                        val destination = File(
                            activity.cacheDir,
                            "ai_companion_manual_${System.currentTimeMillis()}.zip",
                        )
                        try {
                            ManualSnapshotCrypto.decrypt(input, FileOutputStream(destination), passphrase)
                        } catch (e: Throwable) {
                            runCatching { destination.delete() }
                            throw e
                        }
                        mapOf("filePath" to destination.absolutePath)
                    }
                    else -> error("manual_snapshot_unknown_operation")
                }
            }.onSuccess { value ->
                activity.runOnUiThread { result.success(value) }
            }.onFailure { error ->
                activity.runOnUiThread {
                    result.error(
                        "manual_snapshot_failed",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }.start()
    }

    private fun startManualSave(
        sourcePath: String,
        passphrase: String,
        suggestedName: String,
        result: MethodChannel.Result,
    ) {
        if (!beginManualOperation("save", sourcePath, passphrase, result)) return
        val safeName = suggestedName
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(96)
            .ifBlank { "ai_companion_transfer.aicomp" }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, if (safeName.endsWith(".aicomp")) safeName else "$safeName.aicomp")
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_MANUAL_SAVE) }
            .onFailure { error ->
                clearManualDocumentState()
                result.error("manual_snapshot_picker", error.message ?: error.javaClass.simpleName, null)
            }
    }

    private fun startManualOpen(
        passphrase: String,
        result: MethodChannel.Result,
    ) {
        if (!beginManualOperation("open", null, passphrase, result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_MANUAL_OPEN) }
            .onFailure { error ->
                clearManualDocumentState()
                result.error("manual_snapshot_picker", error.message ?: error.javaClass.simpleName, null)
            }
    }

    private fun startDiagnosticReportSave(
        sourcePath: String,
        suggestedName: String,
        result: MethodChannel.Result,
    ) {
        if (reportDocumentResult != null) {
            result.error("diagnostic_export_busy", "A diagnostic export picker is already open", null)
            return
        }
        val source = File(sourcePath)
        if (!source.exists() || !source.isFile || source.length() > 2L * 1024L * 1024L) {
            result.error("diagnostic_source_invalid", "Diagnostic report source is missing or too large", null)
            return
        }
        val safeName = suggestedName
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(96)
            .ifBlank { "ai_companion_diagnostics.txt" }
        reportDocumentResult = result
        reportSourcePath = source.absolutePath
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, if (safeName.endsWith(".txt")) safeName else "$safeName.txt")
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_DIAGNOSTIC_SAVE) }
            .onFailure { error ->
                reportDocumentResult = null
                reportSourcePath = null
                result.error("diagnostic_export_picker", error.javaClass.simpleName, null)
            }
    }

    private fun beginManualOperation(
        operation: String,
        sourcePath: String?,
        passphrase: String,
        result: MethodChannel.Result,
    ): Boolean {
        if (manualDocumentResult != null) {
            result.error("manual_snapshot_busy", "Another manual transfer picker is already open", null)
            return false
        }
        if (passphrase.length !in 8..128) {
            result.error("manual_snapshot_passphrase", "Passphrase must be 8..128 characters", null)
            return false
        }
        if (operation == "save") {
            val file = File(sourcePath.orEmpty())
            if (!file.exists() || !file.isFile) {
                result.error("manual_snapshot_source_missing", "Snapshot ZIP does not exist", null)
                return false
            }
        }
        manualDocumentResult = result
        manualPassphrase = passphrase.toCharArray()
        manualSourcePath = sourcePath
        manualOperation = operation
        return true
    }

    private fun clearManualDocumentState() {
        manualPassphrase?.fill('\u0000')
        manualPassphrase = null
        manualSourcePath = null
        manualOperation = null
        manualDocumentResult = null
    }

    private fun preflightStatus(): Map<String, Any> =
        NativePreflightProbe.collect(activity, capabilityStatus())

    private fun capabilityStatus(): Map<String, Any> {
        val runtime = CompanionRuntimeState.runtimeInfo(activity)
        val power = activity.getSystemService(PowerManager::class.java)
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
        return HashMap<String, Any>().apply {
            put("overlay", Settings.canDrawOverlays(activity))
            put("usage", hasUsageAccess())
            val accessibilityAuthorized = isAccessibilityEnabled()
            put("accessibility", accessibilityAuthorized)
            put("accessibilityAuthorized", accessibilityAuthorized)
            put("notificationListener", isNotificationListenerEnabled())
            put("postNotifications", hasNotificationPermission())
            put("overlayRunning", OverlayBubbleService.running)
            put("overlayEntryMode", OverlayBubbleService.entryMode(activity))
            put("overlayPetSize", OverlayBubbleService.petSize(activity))
            put("backgroundBrainReady", OverlayBubbleService.backgroundBrainReady)
            put("screenInteractive", power.isInteractive)
            put("deviceLocked", keyguard.isDeviceLocked)
            putAll(runtime)
        }
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || hasNotificationPermission()) {
            result.success(true)
            return
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS, result)
    }

    private fun requestNearbyPermissions(result: MethodChannel.Result) {
        val missing = NativePreflightProbe.nearbyPermissionNames().distinct().filter {
            activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        requestPermissions(missing.toTypedArray(), REQUEST_NEARBY, result)
    }

    private fun requestPermissions(
        permissions: Array<String>,
        requestCode: Int,
        result: MethodChannel.Result,
    ) {
        if (permissionResult != null) {
            result.error("permission_busy", "Another permission request is active", null)
            return
        }
        permissionResult = result
        permissionRequestCode = requestCode
        activity.requestPermissions(permissions, requestCode)
    }

    private fun setOverlayUnread(count: Int) {
        val safe = count.coerceAtLeast(0)
        activity.getSharedPreferences(OverlayBubbleService.PREFS, Context.MODE_PRIVATE)
            .edit().putInt(OverlayBubbleService.KEY_UNREAD, safe).apply()
        if (OverlayBubbleService.running) {
            runCatching {
                activity.startService(
                    Intent(activity, OverlayBubbleService::class.java).apply {
                        action = OverlayBubbleService.ACTION_SET_UNREAD
                        putExtra(OverlayBubbleService.EXTRA_COUNT, safe)
                    },
                )
            }
        }
    }

    private fun setPetConversationState(
        generationActive: Boolean,
        generationPhase: String,
        ttsPhase: String,
    ) {
        if (!OverlayBubbleService.running) return
        runCatching {
            activity.startService(
                Intent(activity, OverlayBubbleService::class.java).apply {
                    action = OverlayBubbleService.ACTION_SET_PET_CONVERSATION
                    putExtra(OverlayBubbleService.EXTRA_GENERATION_ACTIVE, generationActive)
                    putExtra(OverlayBubbleService.EXTRA_GENERATION_PHASE, generationPhase)
                    putExtra(OverlayBubbleService.EXTRA_TTS_PHASE, ttsPhase)
                },
            )
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = activity.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                activity.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                activity.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ).orEmpty()
        val expected = ComponentName(activity, AccessibilityBridgeService::class.java).flattenToString()
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            "enabled_notification_listeners",
        ).orEmpty()
        return enabled.split(':').any { item ->
            runCatching { ComponentName.unflattenFromString(item)?.packageName == activity.packageName }
                .getOrDefault(false)
        }
    }

    private fun deviceLabel(): String = "${Build.MANUFACTURER} ${Build.MODEL}"
        .trim()
        .ifBlank { "Android device" }
        .take(80)

    private fun perceptionState(): Map<String, Any> {
        val power = activity.getSystemService(PowerManager::class.java)
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
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
                activity.packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                activity.packageManager.getApplicationInfo(packageName, 0)
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
        val manager = activity.getSystemService(UsageStatsManager::class.java)
        val end = System.currentTimeMillis()
        val start = end - minutes.coerceIn(1, 24 * 60) * 60_000L
        val events = manager.queryEvents(start, end)
        val event = UsageEvents.Event()
        val output = ArrayList<Map<String, Any>>()
        val categoryCache = HashMap<String, String>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName == null || event.packageName == activity.packageName) continue
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
        private const val NEARBY_EVENT_CHANNEL = "ai_companion/nearby_events"
        private const val REQUEST_NOTIFICATIONS = 4201
        private const val REQUEST_NEARBY = 4202
        private const val REQUEST_MANUAL_SAVE = 4203
        private const val REQUEST_MANUAL_OPEN = 4204
        private const val REQUEST_DIAGNOSTIC_SAVE = 4205
    }
}
