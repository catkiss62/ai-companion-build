package com.aicompanion.localfirst

import android.os.Handler
import android.os.Looper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowSettings
import java.time.Duration
import java.util.concurrent.ExecutorService

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class OverlayPermissionRecoveryTest {
    private fun get(service: OverlayBubbleService, name: String): Any? =
        OverlayBubbleService::class.java.getDeclaredField(name).apply { isAccessible = true }.get(service)
    private fun probe(service: OverlayBubbleService): Boolean =
        OverlayBubbleService::class.java.getDeclaredMethod("checkOverlayPermission").apply { isAccessible = true }.invoke(service) as Boolean
    private fun service(): OverlayBubbleService {
        ShadowSettings.setCanDrawOverlays(false)
        val service = Robolectric.buildService(OverlayBubbleService::class.java).create().get()
        CompanionRuntimeState.setOverlayUserEnabled(service, true)
        return service
    }
    private fun cleanup(service: OverlayBubbleService) {
        (get(service, "lifetime") as OverlayWindowSession).destroy()
        (get(service, "mainHandler") as Handler).removeCallbacksAndMessages(null)
        for (name in listOf("submissionIo", "submissionLogExecutor", "thumbnailExecutor"))
            (get(service, name) as ExecutorService).shutdownNow()
        CompanionRuntimeState.setOverlayUserEnabled(service, false)
        ShadowSettings.setCanDrawOverlays(false)
    }
    @Test fun transientPermissionFailureKeepsTheExistingRuntime() {
        val service = service()
        try {
            assertFalse(probe(service))
            assertNotEquals("overlay_permission_lost", get(service, "destroyReason"))
            ShadowSettings.setCanDrawOverlays(true)
            assertTrue(probe(service))
            assertEquals(0, (get(service, "permissionProbe") as OverlayPermissionProbe).checks)
            assertNotEquals("overlay_permission_lost", get(service, "destroyReason"))
        } finally { cleanup(service) }
    }
    @Test fun sustainedPermissionFailureStopsAfterSpacedMainLoopChecks() {
        val service = service()
        try {
            assertFalse(probe(service))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(2_999))
            assertNotEquals("overlay_permission_lost", get(service, "destroyReason"))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(2))
            assertEquals("overlay_permission_lost", get(service, "destroyReason"))
            assertEquals(3, (get(service, "permissionProbe") as OverlayPermissionProbe).checks)
        } finally { cleanup(service) }
    }
}
