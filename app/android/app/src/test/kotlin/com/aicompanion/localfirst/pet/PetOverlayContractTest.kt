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
}
