package com.aicompanion.localfirst

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.app.KeyguardManager
import android.graphics.Bitmap
import android.os.Build
import android.os.PowerManager
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.io.ByteArrayOutputStream
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean

class AccessibilityBridgeService : AccessibilityService() {
    private var systemCoverActive = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
        CompanionRuntimeState.markAccessibilityConnected(this)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "accessibility_connected",
            appPackage = packageName,
            summary = "Accessibility 轻视觉服务已连接。",
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        val sourcePackage = e.packageName?.toString().orEmpty()
        val allowedPackage = PrivacyFilter.allowPackage(sourcePackage)
        CompanionRuntimeState.noteAccessibilityEvent(
            context = this,
            eventType = AccessibilityEvent.eventTypeToString(e.eventType),
            sourcePackage = sourcePackage,
            allowedPackage = allowedPackage,
            windowChanged = e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                e.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED,
            hasReadableRoot = runCatching { rootInActiveWindow != null }.getOrDefault(false),
        )
        val power = getSystemService(PowerManager::class.java)
        if (!power.isInteractive) {
            CurrentAppResolver.clearTrackedApp(this, "screen_off_accessibility")
        } else if (CurrentAppResolver.isLauncherPackage(sourcePackage)) {
            CurrentAppResolver.clearTrackedApp(this, "launcher_window")
        } else if (
            e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            e.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            refreshForegroundWindowTracker(sourcePackage)
        }

        if (e.isPassword || sourcePackage.isBlank()) return

        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // System file pickers/settings/permission surfaces may ask Android
            // to suppress third-party overlays. Track only the coarse state;
            // package/class names are never written into this recovery path.
            val systemSurface = isLikelySystemSurface(
                sourcePackage,
                e.className?.toString().orEmpty(),
            )
            // Foreground identity was already refreshed from the interactive
            // window list above, with event-package fallback for OEM gaps.
            val sourceHash = CompanionRuntimeState.privacyHash(sourcePackage)
            if (systemSurface) {
                systemCoverActive = true
                OverlayBubbleService.notifySystemCoverEntered(
                    this,
                    "accessibility_system_surface:$sourceHash",
                )
            } else if (systemCoverActive || CompanionRuntimeState.isOverlaySystemCoverActive()) {
                systemCoverActive = false
                OverlayBubbleService.notifySystemCoverExited(
                    this,
                    "accessibility_non_system_window:$sourceHash",
                )
            }
        }

        if (!allowedPackage) return

        val content = buildList {
            e.contentDescription?.let { add(it.toString()) }
            e.text?.forEach { if (!it.isNullOrBlank()) add(it.toString()) }
        }.distinct().joinToString(" · ")
        val sanitized = PrivacyFilter.sanitize(content)
        if (sanitized.isBlank() && e.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        NativeEventStore.addDeviceEvent(
            this,
            source = "accessibility",
            eventType = AccessibilityEvent.eventTypeToString(e.eventType),
            appPackage = sourcePackage,
            summary = sanitized.ifBlank { "窗口发生变化" },
            metadata = mapOf("class" to e.className?.toString()),
        )
        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // Window changes are a useful coarse sign that the user's context
            // changed, but the wake reason deliberately contains no package or
            // accessibility text.
            OverlayBubbleService.requestSignalBrainWake(this, "accessibility_window")
        }
    }

    private fun refreshForegroundWindowTracker(eventPackage: String) {
        val observedWindows = runCatching { windows.orEmpty() }.getOrDefault(emptyList())
        data class WindowCandidate(
            val packageName: String,
            val active: Boolean,
            val focused: Boolean,
            val layer: Int,
        )
        val candidates = observedWindows.mapNotNull { window ->
            if (window.type != AccessibilityWindowInfo.TYPE_APPLICATION) return@mapNotNull null
            val packageName = runCatching {
                window.root?.packageName?.toString().orEmpty()
            }.getOrDefault("")
            if (!CurrentAppResolver.isTrackablePackage(this, packageName)) return@mapNotNull null
            WindowCandidate(
                packageName = packageName,
                active = window.isActive,
                focused = window.isFocused,
                layer = window.layer,
            )
        }
        val selected = candidates.sortedWith(
            compareByDescending<WindowCandidate> { it.active }
                .thenByDescending { it.focused }
                .thenByDescending { it.layer },
        ).firstOrNull()
        if (selected != null) {
            CurrentAppResolver.noteForegroundApp(
                this,
                selected.packageName,
                "accessibility_interactive_window",
            )
        } else if (CurrentAppResolver.isTrackablePackage(this, eventPackage)) {
            CurrentAppResolver.noteForegroundApp(this, eventPackage, "accessibility_event")
        }
        CurrentAppResolver.noteWindowProbe(
            context = this,
            total = observedWindows.size,
            active = observedWindows.count { it.isActive },
            focused = observedWindows.count { it.isFocused },
            candidates = candidates.size,
            result = when {
                selected != null -> "interactive_window_selected"
                CurrentAppResolver.isTrackablePackage(this, eventPackage) -> "event_package_fallback"
                observedWindows.isEmpty() -> "windows_empty"
                else -> "no_external_candidate"
            },
        )
    }

    private fun isLikelySystemSurface(sourcePackage: String, sourceClass: String): Boolean {
        // v0.30.2 treated every system / updated-system app as a cover surface.
        // On HyperOS that is far too broad and caused repeated overlay rebuilds.
        // Only recognize surfaces that are actually known to suppress overlays.
        val p = sourcePackage.lowercase()
        val c = sourceClass.lowercase()
        return p == "com.android.documentsui" ||
            p == "com.google.android.documentsui" ||
            p == "com.android.providers.media.module" ||
            p == "com.google.android.providers.media.module" ||
            p == "com.android.photopicker" ||
            p == "com.google.android.photopicker" ||
            p == "com.android.intentresolver" ||
            p == "com.google.android.files" ||
            p == "com.miui.fileexplorer" ||
            p == "com.android.permissioncontroller" ||
            p == "com.google.android.permissioncontroller" ||
            p == "com.android.packageinstaller" ||
            p == "com.miui.packageinstaller" ||
            p == "com.android.settings" ||
            // Do not treat the whole HyperOS Security Center package as a
            // cover. Game Turbo emits short-lived window-state events from
            // this package while ordinary games are foreground; detaching the
            // pet here creates the exact disappear/recover loop we are trying
            // to avoid. Actual permission/install surfaces remain covered by
            // their dedicated PermissionController/PackageInstaller packages.
            p.contains("documentsui") ||
            p.contains("fileexplorer") ||
            p.contains("photopicker") ||
            (p.contains("providers.media") && c.contains("picker"))
    }

    override fun onInterrupt() {
        CompanionRuntimeState.noteAccessibilityInterrupted(this)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "accessibility_interrupted",
            appPackage = packageName,
            summary = "Accessibility 轻视觉被系统暂时中断。",
        )
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (activeService === this) activeService = null
        CompanionRuntimeState.markAccessibilityDisconnected(this, "unbound")
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "accessibility_unbound",
            appPackage = packageName,
            summary = "Accessibility 轻视觉服务已与系统解绑。",
        )
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (activeService === this) activeService = null
        if (CompanionRuntimeState.accessibilityConnected) {
            CompanionRuntimeState.markAccessibilityDisconnected(this, "destroyed")
        }
        CompanionRuntimeState.noteAccessibilityDestroyed(this)
        super.onDestroy()
    }

    private fun containsPasswordField(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 500) {
            val node = queue.removeFirst()
            visited += 1
            if (node.isPassword) return true
            for (index in 0 until node.childCount) {
                runCatching { node.getChild(index) }.getOrNull()?.let(queue::add)
            }
        }
        return false
    }

    private fun captureGate(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return "android_api_unsupported"
        val power = getSystemService(PowerManager::class.java)
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (!power.isInteractive || keyguard.isDeviceLocked) return "device_locked"
        val root = runCatching { rootInActiveWindow }.getOrNull()
            ?: return "foreground_unknown"
        val rootPackage = root.packageName?.toString().orEmpty()
        val trackedExternal =
            CompanionRuntimeState.foregroundWindowSnapshot()?.packageName.orEmpty()
        val packageName = when {
            rootPackage == this.packageName && !CompanionRuntimeState.isAppVisible() ->
                trackedExternal
            rootPackage.isNotBlank() -> rootPackage
            else -> trackedExternal
        }
        if (packageName.isBlank()) return "foreground_unknown"
        if (!PrivacyFilter.allowScreenObservationPackage(this, packageName, this.packageName)) {
            return "sensitive_surface"
        }
        if (containsPasswordField(root)) return "password_surface"
        return null
    }

    private fun captureCurrentScreenOnce(callback: (Map<String, Any>) -> Unit) {
        val gate = captureGate()
        if (gate != null) {
            callback(mapOf("status" to "blocked", "errorCode" to gate))
            return
        }
        if (!captureInFlight.compareAndSet(false, true)) {
            callback(mapOf("status" to "blocked", "errorCode" to "capture_in_flight"))
            return
        }
        try {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                mainExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        val payload = decodeScreenshot(screenshot)
                        captureInFlight.set(false)
                        callback(payload)
                    }

                    override fun onFailure(errorCode: Int) {
                        captureInFlight.set(false)
                        // Secure-window is API 34 / value 6. Keep the numeric
                        // comparison behind the SDK gate so this source still
                        // compiles and runs with the Android 11 screenshot API.
                        val secureWindow = Build.VERSION.SDK_INT >= 34 && errorCode == 6
                        callback(
                            mapOf(
                                "status" to if (secureWindow) "blocked" else "failed",
                                "errorCode" to if (secureWindow) {
                                    "secure_window"
                                } else {
                                    "capture_failed"
                                },
                            ),
                        )
                    }
                },
            )
        } catch (_: Throwable) {
            captureInFlight.set(false)
            callback(mapOf("status" to "failed", "errorCode" to "capture_start_failed"))
        }
    }

    private fun decodeScreenshot(screenshot: ScreenshotResult): Map<String, Any> {
        return try {
            val hardware = screenshot.hardwareBuffer
            val wrapped = Bitmap.wrapHardwareBuffer(hardware, screenshot.colorSpace)
            val bitmap = try {
                wrapped?.copy(Bitmap.Config.ARGB_8888, false)
            } finally {
                wrapped?.recycle()
                hardware.close()
            }
            if (bitmap == null) {
                return mapOf("status" to "failed", "errorCode" to "bitmap_unavailable")
            }
            val bytes = try {
                ByteArrayOutputStream().use { output ->
                    if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                        ByteArray(0)
                    } else {
                        output.toByteArray()
                    }
                }
            } finally {
                bitmap.recycle()
            }
            if (bytes.isEmpty() || bytes.size > 16 * 1024 * 1024) {
                mapOf("status" to "failed", "errorCode" to "invalid_image_size")
            } else {
                mapOf(
                    "status" to "succeeded",
                    "errorCode" to "",
                    "pngBytes" to bytes,
                )
            }
        } catch (_: Throwable) {
            mapOf("status" to "failed", "errorCode" to "capture_decode_failed")
        }
    }

    companion object {
        @Volatile
        private var activeService: AccessibilityBridgeService? = null
        private val captureInFlight = AtomicBoolean(false)

        fun captureOnce(callback: (Map<String, Any>) -> Unit) {
            val service = activeService
            if (service == null) {
                callback(mapOf("status" to "blocked", "errorCode" to "accessibility_not_connected"))
                return
            }
            service.captureCurrentScreenOnce(callback)
        }
    }
}
