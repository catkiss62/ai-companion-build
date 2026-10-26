package com.aicompanion.localfirst.qq

import android.app.Application
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class QqPrivateServiceTest {
    @Test fun disabledServiceCannotStartDartOrRequireAnOverlay() {
        val app: Application = RuntimeEnvironment.getApplication()
        app.getSharedPreferences("qq_private_service_v1", 0).edit().clear().commit()
        val controller = Robolectric.buildService(QqPrivateService::class.java).create()
        assertFalse(QqPrivateService.enabled(app))
        assertFalse(QqPrivateService.snapshot(app)["running"] as Boolean)
        assertTrue(shadowOf(controller.get()).isStoppedBySelf)
        controller.destroy()
    }

    @Test fun enablingQqRequestsOnlyItsOwnServiceAndStopClearsOptIn() {
        val app: Application = RuntimeEnvironment.getApplication()
        app.getSharedPreferences("qq_private_service_v1", 0).edit().clear().commit()
        QqPrivateService.start(app)
        QqPrivateService.setAutoReconnect(app, true)
        assertTrue(QqPrivateService.enabled(app))
        assertTrue(QqPrivateService.autoReconnect(app))
        assertEquals(QqPrivateService::class.java.name, shadowOf(app).nextStartedService.component!!.className)
        var stopped = false
        QqPrivateService.stop(app) { stopped = true }
        assertTrue(stopped)
        assertFalse(QqPrivateService.enabled(app))
        assertFalse(QqPrivateService.autoReconnect(app))
    }

    @Test fun recoveryRespectsExplicitStopAndTerminalConfigurationErrors() {
        val app: Application = RuntimeEnvironment.getApplication()
        val preferences = app.getSharedPreferences("qq_private_service_v1", 0)
        preferences.edit().clear().commit()
        QqPrivateService.setAutoReconnect(app, true)
        QqPrivateService.maybeRecover(app)
        assertNull(shadowOf(app).nextStartedService) // A checkbox alone cannot override a stopped intent.
        preferences.edit().putBoolean("enabled", true).putBoolean("blocked", true).commit()
        QqPrivateService.maybeRecover(app)
        assertNull(shadowOf(app).nextStartedService)
        preferences.edit().putBoolean("blocked", false).commit()
        QqPrivateService.maybeRecover(app)
        assertEquals(QqPrivateService::class.java.name, shadowOf(app).nextStartedService.component!!.className)
        QqPrivateService.stop(app) {}
        QqPrivateService.maybeRecover(app)
        assertNull(shadowOf(app).nextStartedService)
    }

    @Test fun runtimeFailureRetriesWithBackoffButPermissionFailureStops() {
        val app: Application = RuntimeEnvironment.getApplication()
        val p = app.getSharedPreferences("qq_private_service_v1", 0)
        p.edit().clear().commit()
        val controller = Robolectric.buildService(QqPrivateService::class.java).create()
        val service = controller.get()
        QqPrivateService::class.java.getDeclaredField("alive").apply { isAccessible = true }.setBoolean(service, true)
        p.edit().putBoolean("enabled", true).putBoolean("autoReconnect", true).commit()
        val failed = QqPrivateService::class.java.getDeclaredMethod("failed", String::class.java).apply { isAccessible = true }
        failed.invoke(service, "runtime_unresponsive")
        assertTrue(QqPrivateService.enabled(app))
        assertEquals("recovering", QqPrivateService.snapshot(app)["connection"].let { if (it == "not_running") p.getString("connection", "") else it })
        assertTrue(QqPrivateService::class.java.getDeclaredField("retryPending").apply { isAccessible = true }.getBoolean(service))
        controller.destroy() // Cancel the actual delayed engine start, keeping this a native host test.

        p.edit().putBoolean("enabled", false).commit()
        val terminal = Robolectric.buildService(QqPrivateService::class.java).create()
        QqPrivateService::class.java.getDeclaredField("alive").apply { isAccessible = true }.setBoolean(terminal.get(), true)
        p.edit().putBoolean("enabled", true).commit()
        failed.invoke(terminal.get(), "permission_error")
        assertFalse(QqPrivateService.enabled(app))
        assertTrue(p.getBoolean("blocked", false))
        assertEquals("permission_error", p.getString("connection", ""))
        terminal.destroy()
        assertEquals(15000L, QqRecoveryPolicy.retryDelay(1))
        assertEquals(30000L, QqRecoveryPolicy.retryDelay(2))
        assertEquals(300000L, QqRecoveryPolicy.retryDelay(20))
    }
}
