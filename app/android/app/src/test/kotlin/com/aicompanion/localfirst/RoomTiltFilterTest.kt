package com.aicompanion.localfirst

import kotlin.math.cos
import kotlin.math.sin
import org.junit.Assert.*
import org.junit.Test

class RoomTiltFilterTest {
    private fun yRotation(angle: Float) = floatArrayOf(cos(angle),0f,sin(angle), 0f,1f,0f, -sin(angle),0f,cos(angle))
    private fun xRotation(angle: Float) = floatArrayOf(1f,0f,0f, 0f,cos(angle),-sin(angle), 0f,sin(angle),cos(angle))

    @Test fun relativeReferenceAndResetWorkAcrossAngleWrap() {
        val filter=RoomTiltFilter()
        filter.update(yRotation(3.10f),1)
        assertEquals(0f,filter.x,0f)
        repeat(30) { filter.update(yRotation(-3.10f),(it+1)*33_000_000L) }
        assertTrue(filter.x in .20f.. .26f)
        assertEquals(0f,filter.y,.001f)
        filter.reset()
        filter.update(yRotation(-1f),2_000_000_000)
        assertEquals(0f,filter.x,0f)
    }
    @Test fun uprightPhoneRemainsStableAndExtremeTiltIsBounded() {
        val filter=RoomTiltFilter()
        filter.update(xRotation(1.55f),1)
        repeat(30) { filter.update(xRotation(1.65f),(it+1)*33_000_000L) }
        assertEquals(.10f/.35f,filter.y,.002f)
        assertEquals(0f,filter.x,.001f)
        repeat(30) { filter.update(xRotation(3f),(it+31)*33_000_000L) }
        assertTrue(filter.y in .99f..1f)
        assertFalse(filter.update(FloatArray(9){Float.NaN},3_000_000_000))
        assertFalse(filter.update(xRotation(1f),1))
        assertTrue(filter.x.isFinite() && filter.y.isFinite())
    }
    @Test fun smoothingIsTimeBased() {
        fun value(step:Long):Float {
            val filter=RoomTiltFilter();filter.update(yRotation(0f),1)
            var t=step
            while(t<=990_000_000L) { filter.update(yRotation(.2f),t); t+=step }
            return filter.x
        }
        assertEquals(value(16_500_000),value(33_000_000),.001f)
    }
}
