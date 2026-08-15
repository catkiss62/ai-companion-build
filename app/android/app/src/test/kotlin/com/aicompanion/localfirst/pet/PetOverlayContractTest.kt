package com.aicompanion.localfirst.pet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PetOverlayContractTest {
    @Test
    fun sourceRegionGeometryKeepsHeadTailAndBodyDistinct() {
        assertEquals("head", PetTouchRegions.classify(50f, 10f, 100, 100))
        assertEquals("face", PetTouchRegions.classify(50f, 30f, 100, 100))
        assertEquals("tail", PetTouchRegions.classify(82f, 65f, 100, 100))
        assertEquals("tail", PetTouchRegions.classify(18f, 65f, 100, 100))
        assertEquals("body", PetTouchRegions.classify(50f, 70f, 100, 100))
    }

    @Test
    fun displaySizeAndRasterTierRemainSeparate() {
        assertEquals(112, PetOverlaySizing.windowDp(PetOverlaySizing.SMALL))
        assertEquals(152, PetOverlaySizing.windowDp(PetOverlaySizing.MEDIUM))
        assertEquals(200, PetOverlaySizing.windowDp(PetOverlaySizing.LARGE))
        assertEquals(187, PetOverlaySizing.assetHeight(PetOverlaySizing.SMALL))
        assertEquals(238, PetOverlaySizing.assetHeight(PetOverlaySizing.MEDIUM))
        assertEquals(306, PetOverlaySizing.assetHeight(PetOverlaySizing.LARGE))
        assertEquals(PetOverlaySizing.MEDIUM, PetOverlaySizing.normalized("unexpected"))
    }

    @Test
    fun motionModesDefaultToFreeAndKeepEveryHalfDistinct() {
        assertEquals(PetMotionPolicy.FREE, PetMotionPolicy.normalized(null))
        assertEquals(PetMotionPolicy.FREE, PetMotionPolicy.normalized("unexpected"))
        assertEquals(PetMotionPolicy.EDGE, PetMotionPolicy.normalized("edge"))
        assertEquals(true, PetMotionPolicy.isHalf(PetMotionPolicy.HALF_TOP))
        assertEquals(true, PetMotionPolicy.isHalf(PetMotionPolicy.HALF_RIGHT))
        assertEquals(false, PetMotionPolicy.isHalf(PetMotionPolicy.EDGE))
    }

    @Test
    fun throwNeedsSpeedTravelDistanceAndAnUnstableTail() {
        assertEquals(true, PetMotionPolicy.shouldThrow(900f, 60f, 120f, false))
        assertEquals(false, PetMotionPolicy.shouldThrow(900f, 60f, 120f, true))
        assertEquals(false, PetMotionPolicy.shouldThrow(500f, 60f, 120f, false))
        assertEquals(false, PetMotionPolicy.shouldThrow(900f, 18f, 120f, false))
        assertEquals(false, PetMotionPolicy.shouldThrow(900f, 60f, 30f, false))
    }

    @Test
    fun conversationCueUsesRealGenerationAndPlaybackState() {
        assertEquals(
            PetConversationPolicy.IDLE,
            PetConversationPolicy.cueFor(false, "idle", "idle"),
        )
        assertEquals(
            PetConversationPolicy.THINKING,
            PetConversationPolicy.cueFor(true, "thinking", "idle"),
        )
        assertEquals(
            PetConversationPolicy.THINKING,
            PetConversationPolicy.cueFor(true, "cancelling", "synthesizing"),
        )
        assertEquals(
            PetConversationPolicy.IDLE,
            PetConversationPolicy.cueFor(false, "idle", "synthesizing"),
        )
        assertEquals(
            PetConversationPolicy.TALKING,
            PetConversationPolicy.cueFor(true, "answering", "idle"),
        )
        assertEquals(
            PetConversationPolicy.TALKING,
            PetConversationPolicy.cueFor(false, "idle", "playing"),
        )
        assertEquals("THINKING", PetConversationPolicy.actionFor("thinking"))
        assertEquals("TALKING", PetConversationPolicy.actionFor("talking"))
        assertEquals(null, PetConversationPolicy.actionFor("idle"))
    }

    @Test
    fun autonomyConsumesSleepAndThoughtWithoutCreatingNewState() {
        val sleepy = PetAutonomySnapshot(
            enabled = true,
            dominantDrive = "fatigue",
            driveLevel = 0.72,
            mood = "sleepy",
        )
        val yawn = PetAutonomyPolicy.choose(
            sleepy,
            idleMs = PetAutonomyPolicy.SLEEP_IDLE_MS,
            semanticReady = true,
            microReady = true,
            cadenceBucket = 1L,
        )
        assertEquals("YAWNING", yawn?.actionId)
        assertTrue(yawn?.queueSleepAfter == true)

        val thought = PetAutonomyPolicy.choose(
            PetAutonomySnapshot(
                enabled = true,
                dominantDrive = "reflection",
                driveLevel = 0.66,
                mood = "reflective",
                thoughtActive = true,
                thoughtStrength = 0.74,
            ),
            idleMs = PetAutonomyPolicy.MIN_SEMANTIC_IDLE_MS,
            semanticReady = true,
            microReady = true,
            cadenceBucket = 2L,
        )
        assertEquals("THINKING", thought?.actionId)
    }

    @Test
    fun autonomyHonorsBrainOwnershipAndUsesStableMicroCadence() {
        val disabled = PetAutonomyPolicy.choose(
            PetAutonomySnapshot(enabled = false),
            idleMs = 999_999L,
            semanticReady = true,
            microReady = true,
            cadenceBucket = 3L,
        )
        assertEquals(null, disabled)

        val blink = PetAutonomyPolicy.choose(
            PetAutonomySnapshot(enabled = true),
            idleMs = PetAutonomyPolicy.MIN_MICRO_IDLE_MS,
            semanticReady = false,
            microReady = true,
            cadenceBucket = 5L,
        )
        assertEquals("BLINK", blink?.actionId)
        assertFalse(blink?.semantic ?: true)
    }

    @Test
    fun dailyActionsStaySeparateFromBlinkCadence() {
        val stroll = PetAutonomyPolicy.choose(
            PetAutonomySnapshot(enabled = true),
            idleMs = PetAutonomyPolicy.MIN_DAILY_IDLE_MS,
            semanticReady = false,
            microReady = true,
            cadenceBucket = 1L,
            dailyReady = true,
        )
        assertEquals("STROLLING", stroll?.actionId)
        assertFalse(stroll?.semantic ?: true)

        val sweep = PetAutonomyPolicy.choose(
            PetAutonomySnapshot(enabled = true),
            idleMs = PetAutonomyPolicy.MIN_DAILY_IDLE_MS,
            semanticReady = false,
            microReady = true,
            cadenceBucket = 5L,
            dailyReady = true,
        )
        assertEquals("SWEEPING", sweep?.actionId)
    }

    @Test
    fun autonomousMovementUsesTheRequestedModeDirectionTable() {
        val free = PetAutonomousMotionPolicy.plan(PetMotionPolicy.FREE, "")
        assertEquals("STROLLING", free?.actionId)
        assertEquals(listOf("left", "right", "up", "down"), free?.directions)

        val half = PetAutonomousMotionPolicy.plan(PetMotionPolicy.HALF_TOP, "")
        assertEquals("STROLLING", half?.actionId)
        assertEquals(listOf("left", "right", "up", "down"), half?.directions)

        val sideEdge = PetAutonomousMotionPolicy.plan(PetMotionPolicy.EDGE, "left")
        assertEquals("STROLLING", sideEdge?.actionId)
        assertEquals(listOf("up", "down"), sideEdge?.directions)

        val horizontalEdge = PetAutonomousMotionPolicy.plan(PetMotionPolicy.EDGE, "bottom")
        assertEquals("WALKING", horizontalEdge?.actionId)
        assertEquals(listOf("left", "right"), horizontalEdge?.directions)

        assertEquals(null, PetAutonomousMotionPolicy.plan(PetMotionPolicy.EDGE, ""))
    }

}
