package com.aicompanion.localfirst

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.Context
import android.os.PowerManager
import android.os.SystemClock
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

class AccessibilityBridgeService : AccessibilityService() {
    private var systemCoverActive = false
    private val eventLoadShedder = AccessibilityEventLoadShedder()
    private val windowProbeHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var windowProbePending = false
    private var pendingWindowPackage = ""
    private val deferredWindowProbe = object : Runnable {
        override fun run() {
            if (!windowProbePending || activeService !== this@AccessibilityBridgeService) return
            val now = SystemClock.elapsedRealtime()
            if (!eventLoadShedder.shouldProbeWindows(now)) {
                windowProbeHandler.postDelayed(this, eventLoadShedder.windowProbeDelay(now))
                return
            }
            windowProbePending = false
            val started = SystemClock.elapsedRealtime()
            runCatching { refreshForegroundWindowTracker(pendingWindowPackage) }
            pendingWindowPackage = ""
            val duration = SystemClock.elapsedRealtime() - started
            eventLoadShedder.noteProbeDuration(SystemClock.elapsedRealtime(), duration)
            CompanionRuntimeState.noteAccessibilityQueries(false, true, false, duration)
        }
    }
    private fun cancelWindowProbe() {
        windowProbePending = false
        pendingWindowPackage = ""
        windowProbeHandler.removeCallbacks(deferredWindowProbe)
    }
    private fun deferWindowProbe(eventPackage: String) {
        pendingWindowPackage = eventPackage
        if (windowProbePending) return
        windowProbePending = true
        windowProbeHandler.postDelayed(deferredWindowProbe,
            eventLoadShedder.windowProbeDelay(SystemClock.elapsedRealtime()))
    }
    private val eventWriter = ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        ArrayBlockingQueue(32),
        { runnable -> Thread(runnable, "accessibility-event-writer") },
        ThreadPoolExecutor.DiscardOldestPolicy(),
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
        CompanionRuntimeState.markAccessibilityConnected(this)
        // The pet may already be attached to a narrow application overlay if
        // this service connects after the foreground service on a fresh install.
        OverlayBubbleService.notifyPetVisualManagerReady(this)
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
        val elapsedNow = SystemClock.elapsedRealtime()
        val windowChanged = e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            e.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
        // A pending final-window read takes precedence over another root-only probe.
        val shouldProbeRoot = !windowProbePending && eventLoadShedder.shouldProbeRoot(elapsedNow, windowChanged)
        val rootStarted = SystemClock.elapsedRealtime()
        val hasReadableRoot = shouldProbeRoot && runCatching {
            val root = rootInActiveWindow
            if (root == null) false else { runCatching { root.recycle() }; true }
        }.getOrDefault(false)
        val rootDuration = if (shouldProbeRoot) SystemClock.elapsedRealtime() - rootStarted else 0L
        eventLoadShedder.noteProbeDuration(SystemClock.elapsedRealtime(), rootDuration)
        var windowProbed = false
        var windowDuration = 0L
        CompanionRuntimeState.noteAccessibilityEvent(
            context = this,
            eventType = AccessibilityEvent.eventTypeToString(e.eventType),
            sourcePackage = sourcePackage,
            allowedPackage = allowedPackage,
            windowChanged = windowChanged,
            hasReadableRoot = hasReadableRoot,
        )
        val power = getSystemService(PowerManager::class.java)
        if (!power.isInteractive) {
            cancelWindowProbe()
            CurrentAppResolver.clearTrackedApp(this, "screen_off_accessibility")
        } else if (CurrentAppResolver.isLauncherPackage(sourcePackage)) {
            cancelWindowProbe()
            CurrentAppResolver.clearTrackedApp(this, "launcher_window")
        } else if (windowChanged) {
            if (eventLoadShedder.shouldProbeWindows(elapsedNow)) {
                val started = SystemClock.elapsedRealtime()
                windowProbed = true
                cancelWindowProbe()
                runCatching { refreshForegroundWindowTracker(sourcePackage) }
                windowDuration = SystemClock.elapsedRealtime() - started
                eventLoadShedder.noteProbeDuration(SystemClock.elapsedRealtime(), windowDuration)
            } else {
                deferWindowProbe(sourcePackage)
                if (CurrentAppResolver.isTrackablePackage(this, sourcePackage)) {
                    // Preserve the immediate hint, then reconcile the final interactive window once.
                    CurrentAppResolver.noteForegroundApp(this, sourcePackage, "accessibility_event")
                }
            }
        }
        CompanionRuntimeState.noteAccessibilityQueries(shouldProbeRoot, windowProbed,
            !shouldProbeRoot || (windowChanged && !windowProbed), rootDuration + windowDuration)

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

        val eventType = AccessibilityEvent.eventTypeToString(e.eventType)
        val summary = sanitized.ifBlank { "窗口发生变化" }
        val signature = 31 * (31 * eventType.hashCode() + sourcePackage.hashCode()) +
            summary.hashCode()
        val persistEvent = eventLoadShedder.shouldPersist(
            nowElapsedMs = elapsedNow,
            signature = signature,
            windowChanged = windowChanged,
        )
        CompanionRuntimeState.noteAccessibilityDeviceEvent(persistEvent)
        if (persistEvent) {
            val safeClass = e.className?.toString()
            runCatching {
                eventWriter.execute {
                    NativeEventStore.addDeviceEvent(
                        this,
                        source = "accessibility",
                        eventType = eventType,
                        appPackage = sourcePackage,
                        summary = summary,
                        metadata = mapOf("class" to safeClass),
                    )
                }
            }.onFailure {
                CompanionRuntimeState.noteAccessibilityDeviceEvent(false)
            }
        }
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
                val root = window.root
                try { root?.packageName?.toString().orEmpty() }
                finally { runCatching { root?.recycle() } }
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
        observedWindows.forEach { window -> runCatching { window.recycle() } }
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
        cancelWindowProbe()
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
        cancelWindowProbe()
        if (activeService === this) activeService = null
        if (CompanionRuntimeState.accessibilityConnected) {
            CompanionRuntimeState.markAccessibilityDisconnected(this, "destroyed")
        }
        CompanionRuntimeState.noteAccessibilityDestroyed(this)
        eventWriter.shutdownNow()
        super.onDestroy()
    }

    companion object {
        @Volatile
        private var activeService: AccessibilityBridgeService? = null
        /** A trusted, non-touchable drawing surface for the desktop pet. */
        fun petVisualWindowManager(): WindowManager? =
            activeService?.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    }
}
