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
    fun semanticAutonomyConsumesSleepAndThoughtWithoutCreatingState() {
        val sleepy = PetAutonomySnapshot(
            enabled = true,
            dominantDrive = "fatigue",
            driveLevel = 0.72,
            mood = "sleepy",
        )
        val yawn = PetAutonomyPolicy.chooseSemantic(
            snapshot = sleepy,
            idleMs = PetAutonomyPolicy.SLEEP_IDLE_MS,
            semanticReady = true,
            mobilityEnabled = true,
        )
        assertEquals("YAWNING", yawn?.actionId)
        assertTrue(yawn?.queueSleepAfter == true)

        val thought = PetAutonomyPolicy.chooseSemantic(
            snapshot = PetAutonomySnapshot(
                enabled = true,
                dominantDrive = "reflection",
                driveLevel = 0.66,
                mood = "reflective",
                thoughtActive = true,
                thoughtStrength = 0.74,
            ),
            idleMs = PetAutonomyPolicy.MIN_SEMANTIC_IDLE_MS,
            semanticReady = true,
            mobilityEnabled = true,
        )
        assertEquals("THINKING", thought?.actionId)
    }

    @Test
    fun ambientBagStaysAliveWithoutBrainProjectionAndRespectsStationaryMode() {
        val disabled = PetAutonomySnapshot(enabled = false)
        val mobile = PetAmbientActionPolicy.candidates(disabled, mobilityEnabled = true)
        val stationary = PetAmbientActionPolicy.candidates(disabled, mobilityEnabled = false)

        assertEquals(8, mobile.count { it == "STROLLING" })
        assertTrue("HAPPY" in mobile)
        assertTrue("SWEEPING" in mobile)
        assertTrue("EATING" in mobile)
        assertFalse("STROLLING" in stationary)
        assertTrue("HAPPY" in stationary)
        assertTrue("SWEEPING" in stationary)
        assertTrue(PetAmbientActionPolicy.nextDelayMs(0.0) >= 3_000L)
        assertTrue(PetAmbientActionPolicy.nextDelayMs(0.999) < 7_000L)
        assertTrue(PetAmbientActionPolicy.nextBlinkDelayMs(0.0) >= 4_000L)
        assertTrue(PetAmbientActionPolicy.nextBlinkDelayMs(0.999) < 7_000L)
    }

    @Test
    fun desireStateBiasesButDoesNotOwnAmbientChoices() {
        val duty = PetAmbientActionPolicy.candidates(
            PetAutonomySnapshot(
                enabled = true,
                dominantDrive = "duty",
                driveLevel = 0.8,
            ),
            mobilityEnabled = false,
        )
        assertEquals(2, duty.count { it == "SWEEPING" })

        val stationaryCuriosity = PetAutonomyPolicy.chooseSemantic(
            snapshot = PetAutonomySnapshot(
                enabled = true,
                dominantDrive = "curiosity",
                driveLevel = 0.8,
            ),
            idleMs = PetAutonomyPolicy.MIN_SEMANTIC_IDLE_MS,
            semanticReady = true,
            mobilityEnabled = false,
        )
        assertEquals("GLANCE", stationaryCuriosity?.actionId)
    }

    @Test
    fun mobilityModeDefaultsToMobileAndPersistsStationaryChoice() {
        assertEquals(PetMobilityPolicy.MOBILE, PetMobilityPolicy.normalized(null))
        assertEquals(PetMobilityPolicy.MOBILE, PetMobilityPolicy.normalized("unexpected"))
        assertEquals(
            PetMobilityPolicy.STATIONARY,
            PetMobilityPolicy.normalized(PetMobilityPolicy.STATIONARY),
        )
    }

    @Test
    fun autonomousMovementUsesContinuousPathsExceptAtScreenEdges() {
        val free = PetAutonomousMotionPolicy.plan(PetMotionPolicy.FREE, "")
        assertEquals("STROLLING", free?.actionId)
        assertTrue(free?.continuous2D == true)

        val half = PetAutonomousMotionPolicy.plan(PetMotionPolicy.HALF_TOP, "")
        assertEquals("STROLLING", half?.actionId)
        assertTrue(half?.continuous2D == true)

        val sideEdge = PetAutonomousMotionPolicy.plan(PetMotionPolicy.EDGE, "left")
        assertEquals("STROLLING", sideEdge?.actionId)
        assertEquals(listOf("up", "down"), sideEdge?.directions)
        assertFalse(sideEdge?.continuous2D ?: true)

        val horizontalEdge = PetAutonomousMotionPolicy.plan(PetMotionPolicy.EDGE, "bottom")
        assertEquals("WALKING", horizontalEdge?.actionId)
        assertEquals(listOf("left", "right"), horizontalEdge?.directions)
        assertFalse(horizontalEdge?.continuous2D ?: true)

        assertEquals(null, PetAutonomousMotionPolicy.plan(PetMotionPolicy.EDGE, ""))
    }

}

