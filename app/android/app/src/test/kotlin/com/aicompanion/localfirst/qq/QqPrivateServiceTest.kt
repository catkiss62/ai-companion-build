package com.aicompanion.localfirst.qq

import android.app.Application
import android.os.Looper
import java.time.Duration
import org.robolectric.annotation.LooperMode
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
    private fun recoveredHost(): QqPrivateService {
        val app:Application=RuntimeEnvironment.getApplication()
        val p=app.getSharedPreferences("qq_private_service_v1",0);p.edit().clear().commit()
        val service=Robolectric.buildService(QqPrivateService::class.java).create().get()
        QqPrivateService::class.java.getDeclaredField("alive").apply {isAccessible=true}.setBoolean(service,true)
        QqPrivateService::class.java.getDeclaredField("live").apply {isAccessible=true}.set(null,service)
        p.edit().putBoolean("enabled",true).putBoolean("autoReconnect",true).commit()
        return service
    }
    @Test @LooperMode(LooperMode.Mode.PAUSED)
    fun uncheckingAutoReconnectCancelsAnAlreadyScheduledRetry() {
        val app:Application=RuntimeEnvironment.getApplication();val service=recoveredHost()
        QqPrivateService::class.java.getDeclaredMethod("failed",String::class.java).apply {isAccessible=true}.invoke(service,"runtime_unresponsive")
        shadowOf(Looper.getMainLooper()).idle() // Dispose old runtime and schedule the delayed start.
        QqPrivateService.setAutoReconnect(app,false)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        assertFalse(QqPrivateService.enabled(app))
        assertEquals("stopped",QqPrivateService.snapshot(app)["connection"])
        assertNull(QqPrivateService::class.java.getDeclaredField("engine").apply {isAccessible=true}.get(service))
        service.onDestroy()
    }
    @Test @LooperMode(LooperMode.Mode.PAUSED)
    fun uncheckingWhileWatchdogPingIsPendingCancelsItsTimeout() {
        val app:Application=RuntimeEnvironment.getApplication();val service=recoveredHost()
        QqPrivateService::class.java.getDeclaredField("dartReady").apply {isAccessible=true}.setBoolean(service,true)
        (QqPrivateService::class.java.getDeclaredField("watchdog").apply {isAccessible=true}.get(service) as Runnable).run()
        QqPrivateService.setAutoReconnect(app,false)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(11))
        assertFalse(QqPrivateService::class.java.getDeclaredField("retryPending").apply {isAccessible=true}.getBoolean(service))
        assertEquals("stopped",QqPrivateService.snapshot(app)["connection"])
        service.onDestroy()
    }

}
