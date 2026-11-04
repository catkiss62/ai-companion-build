package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class OverlayPermissionProbeTest {
    @Test fun oneTransientDenialDoesNotConfirmRevocation() {
        val p = OverlayPermissionProbe()
        assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, 100))
        assertEquals(OverlayPermissionProbe.Result.GRANTED, p.observe(true, 200))
        assertEquals(0, p.checks)
        assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, 300))
    }
    @Test fun eventStormCannotAccelerateTheConfirmationWindow() {
        val p = OverlayPermissionProbe()
        repeat(1_500) { assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, it.toLong())) }
        assertEquals(1, p.checks)
        assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, 1_500))
        assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, 2_999))
        assertEquals(OverlayPermissionProbe.Result.CONFIRMED, p.observe(false, 3_000))
    }
    @Test fun scheduledRechecksKeepTheirDeadlineUnderRepeatedWindowFailures() {
        val p = OverlayPermissionProbe(); p.observe(false, 1_000)
        assertEquals(1_500L, p.delayUntilNext(1_000))
        p.observe(false, 1_700)
        assertEquals(800L, p.delayUntilNext(1_700))
        assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, 2_500))
        assertEquals(OverlayPermissionProbe.Result.CONFIRMED, p.observe(false, 4_000))
    }
    @Test fun returningClockCannotTurnOldFailuresIntoARevocation() {
        val p = OverlayPermissionProbe(); p.observe(false, 10_000); p.observe(false, 11_500)
        assertEquals(OverlayPermissionProbe.Result.SUSPECT, p.observe(false, 100))
        assertEquals(1, p.checks)
    }
}
