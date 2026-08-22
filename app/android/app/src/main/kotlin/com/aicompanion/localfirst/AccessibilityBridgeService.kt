package com.aicompanion.localfirst

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class AccessibilityBridgeService : AccessibilityService() {
    private var systemCoverActive = false

    override fun onServiceConnected() {
        super.onServiceConnected()
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
            windowChanged = e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            hasReadableRoot = runCatching { rootInActiveWindow != null }.getOrDefault(false),
        )
        if (e.isPassword || sourcePackage.isBlank()) return

        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // System file pickers/settings/permission surfaces may ask Android
            // to suppress third-party overlays. Track only the coarse state;
            // package/class names are never written into this recovery path.
            val systemSurface = isLikelySystemSurface(
                sourcePackage,
                e.className?.toString().orEmpty(),
            )
            val transientSystemUi = sourcePackage == "com.android.systemui" ||
                sourcePackage == "com.miui.home"
            val ownWindow = sourcePackage == packageName
            if (!systemSurface && !transientSystemUi &&
                (!ownWindow || CompanionRuntimeState.isAppVisible())
            ) {
                // App identity is process-local and may include finance apps;
                // password fields and Accessibility text remain blocked below.
                // An overlay owned by this process is deliberately transparent:
                // it must not replace Bilibili/game/finance app underneath it.
                CompanionRuntimeState.noteForegroundWindow(sourcePackage)
            }
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
            p == "com.miui.securitycenter" ||
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
        if (CompanionRuntimeState.accessibilityConnected) {
            CompanionRuntimeState.markAccessibilityDisconnected(this, "destroyed")
        }
        CompanionRuntimeState.noteAccessibilityDestroyed(this)
        super.onDestroy()
    }
}
