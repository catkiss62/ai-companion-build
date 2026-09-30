package com.aicompanion.localfirst.pet

import org.junit.Assert.assertEquals
import org.junit.Test

class PetEdgeDockPolicyTest {
    private fun edge(left: Int, right: Int, top: Int, bottom: Int, range: Int = 28) =
        PetEdgeDockPolicy.choose(left, right, top, bottom, range)

    @Test
    fun fourCornersPreferTopAndBottomEvenWhenSideIsCloser() {
        assertEquals(PetEdgeDockPolicy.TOP, edge(2, 998, 20, 980))
        assertEquals(PetEdgeDockPolicy.TOP, edge(998, 2, 20, 980))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(2, 998, 980, 20))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(998, 2, 980, 20))
    }

    @Test
    fun exactCornerTiesAlsoPreferTopAndBottom() {
        assertEquals(PetEdgeDockPolicy.TOP, edge(0, 1000, 0, 1000))
        assertEquals(PetEdgeDockPolicy.TOP, edge(1000, 0, 0, 1000))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(0, 1000, 1000, 0))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(1000, 0, 1000, 0))
    }

    @Test
    fun ordinaryEdgesKeepNearestEdgeBehavior() {
        assertEquals(PetEdgeDockPolicy.LEFT, edge(4, 996, 400, 600))
        assertEquals(PetEdgeDockPolicy.RIGHT, edge(996, 4, 400, 600))
        assertEquals(PetEdgeDockPolicy.TOP, edge(400, 600, 4, 996))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(400, 600, 996, 4))
        // The policy keeps nearest-edge selection when no axis is captured.
        assertEquals(PetEdgeDockPolicy.LEFT, edge(60, 940, 90, 910))
    }

    @Test
    fun captureBoundaryIsInclusiveAndOnePixelPastItKeepsSideDocking() {
        assertEquals(PetEdgeDockPolicy.TOP, edge(1, 999, 28, 972))
        assertEquals(PetEdgeDockPolicy.LEFT, edge(1, 999, 29, 971))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(999, 1, 972, 28))
        assertEquals(PetEdgeDockPolicy.RIGHT, edge(999, 1, 971, 29))
        // The range supplied by the overlay may grow with display size.
        assertEquals(PetEdgeDockPolicy.TOP, edge(3, 997, 40, 960, range = 40))
        assertEquals(PetEdgeDockPolicy.LEFT, edge(3, 997, 41, 959, range = 40))
    }

    @Test
    fun narrowAreasChooseTheCloserVerticalEdgeAtOverlappingCorners() {
        assertEquals(PetEdgeDockPolicy.TOP, edge(0, 10, 12, 16))
        assertEquals(PetEdgeDockPolicy.BOTTOM, edge(0, 10, 16, 12))
        assertEquals(PetEdgeDockPolicy.TOP, edge(0, 10, 14, 14))
    }
}
