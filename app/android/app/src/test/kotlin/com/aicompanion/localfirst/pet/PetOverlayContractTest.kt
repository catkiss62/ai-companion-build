package com.aicompanion.localfirst.pet

import org.junit.Assert.assertEquals
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
}
