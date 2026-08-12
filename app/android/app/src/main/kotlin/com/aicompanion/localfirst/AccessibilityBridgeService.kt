package com.aicompanion.localfirst

import android.accessibilityservice.AccessibilityService
import android.content.pm.ApplicationInfo
import android.view.accessibility.AccessibilityEvent

class AccessibilityBridgeService : AccessibilityService() {
    private var systemCoverActive = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        CompanionRuntimeState.setAccessibilityConnected(true)
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
        if (e.isPassword) return
        val sourcePackage = e.packageName?.toString() ?: return

        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            // System file pickers/settings/permission surfaces may ask Android
            // to suppress third-party overlays. Track only the coarse state;
            // package/class names are never written into this recovery path.
            val systemSurface = isLikelySystemSurface(sourcePackage)
            if (systemSurface) {
                systemCoverActive = true
                CompanionRuntimeState.noteOverlaySystemCover("system_surface_entered")
            } else if (systemCoverActive) {
                systemCoverActive = false
                OverlayBubbleService.requestSystemCoverRecovery(
                    this,
                    "system_surface_return",
                )
            }
        }

        if (!PrivacyFilter.allowPackage(sourcePackage)) return

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

    private fun isLikelySystemSurface(sourcePackage: String): Boolean {
        val p = sourcePackage.lowercase()
        if (p.contains("documentsui") ||
            p.contains("permissioncontroller") ||
            p.contains("packageinstaller") ||
            p.contains("fileexplorer") ||
            p.contains("filemanager")) {
            return true
        }
        return runCatching {
            val info = packageManager.getApplicationInfo(sourcePackage, 0)
            info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        }.getOrDefault(false)
    }

    override fun onInterrupt() {
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "accessibility_interrupted",
            appPackage = packageName,
            summary = "Accessibility 轻视觉被系统暂时中断。",
        )
    }

    override fun onDestroy() {
        CompanionRuntimeState.setAccessibilityConnected(false)
        super.onDestroy()
    }
}
