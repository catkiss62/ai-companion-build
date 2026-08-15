package com.aicompanion.localfirst.pet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PetActionStateMachineTest {
    private fun action(
        id: String,
        loop: Boolean = false,
        durationMs: Long? = 100L,
        priority: Int = 40,
        interruptible: Boolean = true,
        returnState: String = "IDLE",
    ) = PetActionSpec(
        id = id,
        assetId = id.lowercase(),
        loop = loop,
        durationMs = durationMs,
        priority = priority,
        interruptible = interruptible,
        returnState = returnState,
        anchor = PetAnchor(),
        effect = "breath",
        enter = null,
        exit = null,
    )

    private fun specs(): Map<String, PetActionSpec> = listOf(
        action("IDLE", loop = true, durationMs = null, priority = 10),
        action("WALKING", loop = true, durationMs = null, priority = 30),
        action("HAPPY", priority = 60),
        action("POKE_REACT", priority = 80, interruptible = false),
        action("DRAGGING", loop = true, durationMs = null, priority = 100, interruptible = false),
        action("FALLING", loop = true, durationMs = null, priority = 90, interruptible = false),
        action("LANDING", durationMs = 620L, priority = 85, interruptible = false),
        action("DIZZY", durationMs = 2100L, priority = 75, interruptible = false),
    ).associateBy { it.id }

    @Test
    fun nonInterruptiblePokeBlocksWalking() {
        val state = PetActionStateMachine(specs())
        assertNotNull(state.request("POKE_REACT", 1_000L, "tap"))
        assertNull(state.request("WALKING", 1_010L, "movement"))
        assertEquals("POKE_REACT", state.current)
    }

    @Test
    fun dragNeedsForcedLifecycleTransition() {
        val state = PetActionStateMachine(specs())
        assertNotNull(state.request("DRAGGING", 10L, "drag", force = true))
        assertNull(state.request("FALLING", 20L, "release"))
        assertNotNull(state.request("FALLING", 20L, "release", force = true))
        assertEquals("FALLING", state.current)
    }

    @Test
    fun landingCanQueueDizzy() {
        val state = PetActionStateMachine(specs())
        state.request("LANDING", 1_000L, "hard_landing", force = true)
        state.queueAfterCurrent("DIZZY")
        assertNull(state.update(1_619L))
        val change = state.update(1_620L)
        assertNotNull(change)
        assertEquals("DIZZY", state.current)
    }

    @Test
    fun finiteActionReturnsToIdleAtManifestDuration() {
        val state = PetActionStateMachine(specs())
        assertNotNull(state.request("HAPPY", 2_000L, "preview"))
        assertNull(state.update(2_099L))
        assertEquals("IDLE", state.update(2_100L)?.current)
    }

    @Test
    fun throwPhysicsSettlesAndReportsImpact() {
        val physics = PetThrowPhysics()
        physics.launch(0f, -100f, 300f, -200f)
        var settled = false
        var impact = 0f
        repeat(2_000) {
            val step = physics.step(
                1f / 120f,
                0f,
                0f,
                PetPhysicsBounds(-500f, -800f, 500f, 0f),
            )
            impact = maxOf(impact, step.impactSpeed)
            if (step.settled) {
                settled = true
                return@repeat
            }
        }
        assertTrue(settled)
        assertTrue(impact > 0f)
        assertFalse(physics.active)
    }
}
