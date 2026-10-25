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
        assertTrue(QqPrivateService.enabled(app))
        assertEquals(QqPrivateService::class.java.name, shadowOf(app).nextStartedService.component!!.className)
        var stopped = false
        QqPrivateService.stop(app) { stopped = true }
        assertTrue(stopped)
        assertFalse(QqPrivateService.enabled(app))
    }
}
