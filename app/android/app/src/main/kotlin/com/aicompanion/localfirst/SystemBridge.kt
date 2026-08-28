package com.aicompanion.localfirst

import android.Manifest
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.ApplicationExitInfo
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
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import com.aicompanion.localfirst.pet.PetPreviewActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
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
    private var promptDocumentResult: MethodChannel.Result? = null
    private var promptDocumentOperation: String? = null
    private var promptDocumentContent: String? = null
    private var directPickerGuardDepth = 0

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
                "consumeOpenChatLaunch" -> {
                    val requested = activity.intent?.getBooleanExtra(
                        MainActivity.EXTRA_OPEN_CHAT,
                        false,
                    ) == true
                    activity.intent?.removeExtra(MainActivity.EXTRA_OPEN_CHAT)
                    result.success(requested)
                }
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
                "openExternalHttpsUrl" -> {
                    val uri = Uri.parse(call.argument<String>("url") ?: "")
                    if (uri.scheme != "https" || uri.host.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            addCategory(Intent.CATEGORY_BROWSABLE)
                        }
                        if (intent.resolveActivity(activity.packageManager) == null) {
                            result.success(false)
                        } else {
                            activity.startActivity(intent)
                            result.success(true)
                        }
                    }
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
                "openCompanionNotificationSettings" -> {
                    CompanionNotification.openMessageChannelSettings(
                        activity,
                        call.argument<String>("soundKey") ?: "chime",
                    )
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
                "beginSystemPickerOverlayGuard" -> {
                    result.success(
                        beginDirectPickerOverlayGuard(
                            call.argument<String>("reason") ?: "flutter_system_picker",
                        ),
                    )
                }
                "endSystemPickerOverlayGuard" -> {
                    result.success(
                        endDirectPickerOverlayGuard(
                            call.argument<String>("reason") ?: "flutter_system_picker_returned",
                        ),
                    )
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
                "acknowledgeCompanionNotifications" -> {
                    CompanionNotification.acknowledgeMessages(
                        activity,
                        call.argument<String>("reason") ?: "full_chat_visible",
                    )
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
                        call.argument<String>("soundKey") ?: "chime",
                    )
                    result.success(null)
                }
                "testCompanionNotification" -> {
                    result.success(
                        CompanionNotification.postMessage(
                            activity,
                            "主动消息弹窗测试",
                            "如果你看到了这条横幅，跨 App 联系和当前提示音可以工作。（不写入聊天和记忆）",
                            "notification-test-${System.currentTimeMillis()}",
                            "diagnostic_test",
                            "normal",
                            call.argument<String>("soundKey") ?: "chime",
                        ),
                    )
                }
                "previewCompanionNotificationSound" -> {
                    result.success(
                        NotificationSoundPreview.play(
                            activity,
                            call.argument<String>("soundKey") ?: "chime",
                        ),
                    )
                }
                "scheduleDelayedProactiveTest" -> {
                    result.success(
                        DelayedProactiveTestReceiver.schedule(
                            activity,
                            (call.argument<Number>("delayMs")?.toLong()
                                ?: 5 * 60_000L),
                            call.argument<String>("soundKey") ?: "chime",
                        ),
                    )
                }
                "delayedProactiveTestStatus" ->
                    result.success(DelayedProactiveTestReceiver.status(activity))
                "cancelDelayedProactiveTest" ->
                    result.success(
                        DelayedProactiveTestReceiver.cancel(
                            activity,
                            call.argument<Number>("expectedDueAt")?.toLong() ?: 0L,
                            call.argument<String>("reason") ?: "unknown_ui",
                        ),
                    )
                "deviceLabel" -> result.success(deviceLabel())
                "runtimeProcessEpoch" -> result.success(CompanionRuntimeState.runtimeProcessEpoch)
                "getPerceptionState" -> result.success(perceptionState())
                "getRecentUsage" -> result.success(
                    CurrentAppResolver.recentUsage(
                        activity,
                        call.argument<Int>("minutes") ?: 60,
                    ),
                )
                "resolveCurrentAppWithRetries" -> Thread {
                    val resolved = CurrentAppResolver.resolveCurrentForProactiveWithRetries(activity)
                        ?.asUsageEvent()
                    Handler(Looper.getMainLooper()).post { result.success(resolved) }
                }.start()
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
                "savePromptPack" -> startPromptPackSave(
                    content = call.argument<String>("content") ?: "",
                    suggestedName = call.argument<String>("suggestedName")
                        ?: "ai_companion_six_rules.json",
                    result = result,
                )
                "openPromptPack" -> startPromptPackOpen(result)
                else -> result.notImplemented()
            }
        }
    }

    fun notifyOpenChatLaunch(intent: Intent?) {
        if (intent?.getBooleanExtra(MainActivity.EXTRA_OPEN_CHAT, false) == true) {
            methodChannel.invokeMethod("openChatLaunch", null)
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
        promptDocumentResult?.error("activity_disposed", "Activity was destroyed during prompt import/export", null)
        clearPromptDocumentState()
        if (directPickerGuardDepth > 0) {
            directPickerGuardDepth = 1
            endDirectPickerOverlayGuard("system_bridge_disposed")
        }
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
        if (requestCode == REQUEST_PROMPT_SAVE || requestCode == REQUEST_PROMPT_OPEN) {
            endDirectPickerOverlayGuard(
                if (requestCode == REQUEST_PROMPT_SAVE) {
                    "prompt_pack_save_picker_returned"
                } else {
                    "prompt_pack_open_picker_returned"
                },
            )
            val result = promptDocumentResult ?: return
            val operation = promptDocumentOperation
            val content = promptDocumentContent
            val uri = data?.data
            clearPromptDocumentState()
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(null)
                return
            }
            Thread {
                runCatching {
                    when (operation) {
                        "save" -> {
                            val bytes = requireNotNull(content).toByteArray(Charsets.UTF_8)
                            require(bytes.size <= MAX_PROMPT_PACK_BYTES) { "prompt_pack_too_large" }
                            activity.contentResolver.openOutputStream(uri, "w").use { output ->
                                requireNotNull(output).write(bytes)
                            }
                            true
                        }
                        "open" -> activity.contentResolver.openInputStream(uri).use { input ->
                            requireNotNull(input)
                            val output = ByteArrayOutputStream()
                            val buffer = ByteArray(16 * 1024)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                output.write(buffer, 0, count)
                                require(output.size() <= MAX_PROMPT_PACK_BYTES) {
                                    "prompt_pack_too_large"
                                }
                            }
                            output.toString(Charsets.UTF_8.name())
                        }
                        else -> error("prompt_pack_unknown_operation")
                    }
                }.onSuccess { value ->
                    activity.runOnUiThread { result.success(value) }
                }.onFailure { error ->
                    activity.runOnUiThread {
                        result.error(
                            "prompt_pack_failed",
                            error.message ?: error.javaClass.simpleName,
                            null,
                        )
                    }
                }
            }.start()
            return
        }
        if (requestCode == REQUEST_DIAGNOSTIC_SAVE) {
            endDirectPickerOverlayGuard("diagnostic_export_picker_returned")
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
        endDirectPickerOverlayGuard(
            if (requestCode == REQUEST_MANUAL_SAVE) {
                "manual_snapshot_save_picker_returned"
            } else {
                "manual_snapshot_open_picker_returned"
            },
        )
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
        beginDirectPickerOverlayGuard("manual_snapshot_save_picker")
        runCatching { activity.startActivityForResult(intent, REQUEST_MANUAL_SAVE) }
            .onFailure { error ->
                endDirectPickerOverlayGuard("manual_snapshot_save_picker_launch_failed")
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
        beginDirectPickerOverlayGuard("manual_snapshot_open_picker")
        runCatching { activity.startActivityForResult(intent, REQUEST_MANUAL_OPEN) }
            .onFailure { error ->
                endDirectPickerOverlayGuard("manual_snapshot_open_picker_launch_failed")
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
        beginDirectPickerOverlayGuard("diagnostic_export_picker")
        runCatching { activity.startActivityForResult(intent, REQUEST_DIAGNOSTIC_SAVE) }
            .onFailure { error ->
                endDirectPickerOverlayGuard("diagnostic_export_picker_launch_failed")
                reportDocumentResult = null
                reportSourcePath = null
                result.error("diagnostic_export_picker", error.javaClass.simpleName, null)
            }
    }

    private fun startPromptPackSave(
        content: String,
        suggestedName: String,
        result: MethodChannel.Result,
    ) {
        if (!beginPromptDocumentOperation("save", content, result)) return
        val safeStem = suggestedName
            .removeSuffix(".json")
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(88)
            .ifBlank { "ai_companion_six_rules" }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, "$safeStem.json")
        }
        beginDirectPickerOverlayGuard("prompt_pack_save_picker")
        runCatching { activity.startActivityForResult(intent, REQUEST_PROMPT_SAVE) }
            .onFailure { error ->
                endDirectPickerOverlayGuard("prompt_pack_save_picker_launch_failed")
                clearPromptDocumentState()
                result.error("prompt_pack_picker", error.javaClass.simpleName, null)
            }
    }

    private fun startPromptPackOpen(result: MethodChannel.Result) {
        if (!beginPromptDocumentOperation("open", null, result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/json", "text/plain", "application/octet-stream"),
            )
        }
        beginDirectPickerOverlayGuard("prompt_pack_open_picker")
        runCatching { activity.startActivityForResult(intent, REQUEST_PROMPT_OPEN) }
            .onFailure { error ->
                endDirectPickerOverlayGuard("prompt_pack_open_picker_launch_failed")
                clearPromptDocumentState()
                result.error("prompt_pack_picker", error.javaClass.simpleName, null)
            }
    }

    private fun beginPromptDocumentOperation(
        operation: String,
        content: String?,
        result: MethodChannel.Result,
    ): Boolean {
        if (promptDocumentResult != null) {
            result.error("prompt_pack_busy", "Another prompt import/export picker is already open", null)
            return false
        }
        if (operation == "save" && (content.isNullOrBlank() ||
                    content.toByteArray(Charsets.UTF_8).size > MAX_PROMPT_PACK_BYTES)) {
            result.error("prompt_pack_invalid", "Prompt pack is empty or too large", null)
            return false
        }
        promptDocumentResult = result
        promptDocumentOperation = operation
        promptDocumentContent = content
        return true
    }

    private fun clearPromptDocumentState() {
        promptDocumentResult = null
        promptDocumentOperation = null
        promptDocumentContent = null
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

    private fun beginDirectPickerOverlayGuard(reason: String): Boolean {
        directPickerGuardDepth += 1
        if (directPickerGuardDepth > 1) return true
        val entered = OverlayBubbleService.notifySystemCoverEntered(
            activity,
            "direct_picker:${reason.take(80)}",
        )
        if (!entered) directPickerGuardDepth = 0
        return entered
    }

    private fun endDirectPickerOverlayGuard(reason: String): Boolean {
        if (directPickerGuardDepth <= 0) return false
        directPickerGuardDepth -= 1
        if (directPickerGuardDepth > 0) return true
        return OverlayBubbleService.notifySystemCoverExited(
            activity,
            "direct_picker:${reason.take(80)}",
        )
    }

    private fun preflightStatus(): Map<String, Any> =
        NativePreflightProbe.collect(activity, capabilityStatus())

    private fun capabilityStatus(): Map<String, Any> {
        val accessibilityStatus = accessibilityServiceStatus()
        val runtime = CompanionRuntimeState.runtimeInfo(activity)
        val power = activity.getSystemService(PowerManager::class.java)
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
        return HashMap<String, Any>().apply {
            put("overlay", Settings.canDrawOverlays(activity))
            put("usage", hasUsageAccess())
            val accessibilityAuthorized =
                accessibilityStatus["accessibilityComponentMatch"] == true
            put("accessibility", accessibilityAuthorized)
            put("accessibilityAuthorized", accessibilityAuthorized)
            putAll(accessibilityStatus)
            put("notificationListener", isNotificationListenerEnabled())
            put("postNotifications", hasNotificationPermission())
            put("overlayRunning", OverlayBubbleService.running)
            put("overlayEntryMode", OverlayBubbleService.entryMode(activity))
            put("overlayPetSize", OverlayBubbleService.petSize(activity))
            put("backgroundBrainReady", OverlayBubbleService.backgroundBrainReady)
            put("screenInteractive", power.isInteractive)
            put("deviceLocked", keyguard.isDeviceLocked)
            putAll(runtime)
            putAll(CurrentAppResolver.diagnosticStatus(activity))
            putAll(CompanionNotification.diagnosticStatus(activity))
            putAll(DelayedProactiveTestReceiver.diagnosticStatus(activity))
            putAll(historicalExitReason())
        }
    }

    private fun historicalExitReason(): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyMap()
        val manager = activity.getSystemService(ActivityManager::class.java)
        val info = runCatching {
            manager.getHistoricalProcessExitReasons(activity.packageName, 0, 5)
                .firstOrNull()
        }.getOrNull() ?: return emptyMap()
        return mapOf(
            "historicalExitReason" to exitReasonKey(info.reason),
            "historicalExitAt" to info.timestamp,
            "historicalExitStatus" to info.status,
            "historicalExitImportance" to info.importance,
            "historicalExitDescriptionIncluded" to false,
            "historicalExitTraceIncluded" to false,
        )
    }

    private fun exitReasonKey(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "exit_self"
        ApplicationExitInfo.REASON_SIGNALED -> "signaled"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
        ApplicationExitInfo.REASON_CRASH -> "crash"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "native_crash"
        ApplicationExitInfo.REASON_ANR -> "anr"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization_failure"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission_change"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive_resource"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "user_requested"
        ApplicationExitInfo.REASON_USER_STOPPED -> "user_stopped"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependency_died"
        ApplicationExitInfo.REASON_OTHER -> "other"
        ApplicationExitInfo.REASON_FREEZER -> "freezer"
        ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "package_state_change"
        ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "package_updated"
        else -> "unknown_$reason"
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

    private fun accessibilityServiceStatus(): Map<String, Any> {
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ).orEmpty()
        val expected = ComponentName(activity, AccessibilityBridgeService::class.java)
        val components = enabled
            .split(':')
            .mapNotNull { item ->
                val trimmed = item.trim()
                if (trimmed.isEmpty()) null else ComponentName.unflattenFromString(trimmed)
            }
        val componentMatch = components.any { component ->
            component.packageName.equals(expected.packageName, ignoreCase = true) &&
                component.className.equals(expected.className, ignoreCase = true)
        }
        val packageEntryCount = components.count { component ->
            component.packageName.equals(activity.packageName, ignoreCase = true)
        }
        CompanionRuntimeState.noteAccessibilityStatusProbe(
            activity,
            componentMatch,
        )
        return mapOf(
            "accessibilityComponentMatch" to componentMatch,
            "accessibilityEnabledEntryCount" to components.size,
            "accessibilityPackageEntryCount" to packageEntryCount,
            "accessibilityStatusProbeAt" to System.currentTimeMillis(),
        )
    }

    private fun isAccessibilityEnabled(): Boolean =
        accessibilityServiceStatus()["accessibilityComponentMatch"] == true

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
    private fun appLabel(packageName: String): String {
        val info = runCatching {
            if (Build.VERSION.SDK_INT >= 33) {
                activity.packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                activity.packageManager.getApplicationInfo(packageName, 0)
            }
        }.getOrNull() ?: return ""
        return runCatching {
            activity.packageManager.getApplicationLabel(info)
                .toString()
                .replace(Regex("\\s+"), " ")
                .trim()
                .take(80)
        }.getOrDefault("")
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
        val manager = activity.getSystemService(UsageStatsManager::class.java)
        val power = activity.getSystemService(PowerManager::class.java)
        val end = System.currentTimeMillis()
        val start = end - minutes.coerceIn(1, 24 * 60) * 60_000L
        val output = ArrayList<Map<String, Any>>()
        val categoryCache = HashMap<String, String>()
        val labelCache = HashMap<String, String>()
        var usageEventCount = 0
        var eventCurrentPackage = ""
        var eventCurrentObservedAt = 0L

        if (hasUsageAccess()) {
            val events = manager.queryEvents(start, end)
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val eventPackage = event.packageName ?: continue
                if (eventPackage == activity.packageName) continue
                val label = when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        eventCurrentPackage = eventPackage
                        eventCurrentObservedAt = event.timeStamp
                        "foreground"
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED -> {
                        if (eventCurrentPackage == eventPackage) {
                            eventCurrentPackage = ""
                            eventCurrentObservedAt = 0L
                        }
                        "background"
                    }
                    UsageEvents.Event.USER_INTERACTION -> "interaction"
                    else -> null
                } ?: continue
                usageEventCount += 1
                output += mapOf(
                    "packageName" to eventPackage,
                    "timestamp" to event.timeStamp,
                    "eventType" to label,
                    "appCategory" to categoryCache.getOrPut(eventPackage) {
                        appCategory(eventPackage)
                    },
                    "appLabel" to labelCache.getOrPut(eventPackage) {
                        appLabel(eventPackage)
                    },
                    "contextSource" to "usage_events",
                )
                if (output.size > 200) output.removeAt(0)
            }
        }

        var currentPackage = ""
        var currentSource = "none"
        var currentObservedAt = 0L
        if (power.isInteractive) {
            val accessibility = CompanionRuntimeState.foregroundWindowSnapshot()
            val accessibilityAge = accessibility
                ?.let { (end - it.observedAt).coerceAtLeast(0L) }
                ?: Long.MAX_VALUE
            if (accessibility != null && accessibilityAge <= 30 * 60_000L) {
                if (accessibility.packageName != activity.packageName) {
                    currentPackage = accessibility.packageName
                    currentSource = "accessibility_window"
                    currentObservedAt = accessibility.observedAt
                } else {
                    currentSource = "self_window"
                    currentObservedAt = accessibility.observedAt
                }
            } else if (eventCurrentPackage.isNotBlank()) {
                currentPackage = eventCurrentPackage
                currentSource = "usage_events"
                currentObservedAt = eventCurrentObservedAt
            } else if (hasUsageAccess()) {
                val fallback = runCatching {
                    manager.queryUsageStats(
                        UsageStatsManager.INTERVAL_DAILY,
                        (end - 10 * 60_000L).coerceAtLeast(0L),
                        end,
                    ).filter {
                        it.packageName != activity.packageName && it.lastTimeUsed > 0L
                    }.maxByOrNull { it.lastTimeUsed }
                }.getOrNull()
                if (fallback != null && end - fallback.lastTimeUsed <= 2 * 60_000L) {
                    currentPackage = fallback.packageName
                    currentSource = "usage_stats_fallback"
                    currentObservedAt = fallback.lastTimeUsed
                }
            }
        }

        if (currentPackage.isNotBlank()) {
            val resolvedLabel = labelCache.getOrPut(currentPackage) {
                appLabel(currentPackage)
            }
            output += mapOf(
                "packageName" to currentPackage,
                "timestamp" to end,
                "eventType" to "foreground",
                "appCategory" to categoryCache.getOrPut(currentPackage) {
                    appCategory(currentPackage)
                },
                "appLabel" to resolvedLabel,
                "contextSource" to currentSource,
            )
            CompanionRuntimeState.noteCurrentAppFusion(
                source = currentSource,
                ageMs = (end - currentObservedAt).coerceAtLeast(0L),
                usageEventCount = usageEventCount,
                labelResolved = resolvedLabel.isNotBlank(),
            )
        } else {
            CompanionRuntimeState.noteCurrentAppFusion(
                source = currentSource,
                ageMs = currentObservedAt.takeIf { it > 0L }
                    ?.let { (end - it).coerceAtLeast(0L) } ?: -1L,
                usageEventCount = usageEventCount,
                labelResolved = false,
            )
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
        private const val REQUEST_PROMPT_SAVE = 4206
        private const val REQUEST_PROMPT_OPEN = 4207
        private const val MAX_PROMPT_PACK_BYTES = 2 * 1024 * 1024
    }
}
