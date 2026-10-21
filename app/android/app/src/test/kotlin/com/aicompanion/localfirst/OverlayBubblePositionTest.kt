package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class OverlayBubblePositionTest {
    @Test fun rightDockSurvivesPortraitToLandscape() {
        val position = OverlayBubblePosition.capture(876, 1000, 18, 18, 1062, 2382, 186, 186, false)
        val (x, y) = position.place(18, 18, 2382, 1062, 186, 186)
        assertEquals(2196, x)
        assertEquals(position.yFraction, (y - 18f) / 858, .001f)
    }
    @Test fun leftDockAndRetractionKeepLeftSide() {
        for (x in listOf(18, -114)) {
            val position = OverlayBubblePosition.capture(x, 400, 18, 18, 1062, 2382, 186, 186, x < 0)
            assertEquals(-1, position.edge)
            assertEquals(18, position.place(18, 18, 2382, 1062, 186, 186).first)
        }
    }
    @Test fun freePositionKeepsBothFractionsAcrossResolutionChange() {
        val position = OverlayBubblePosition.capture(450, 1107, 18, 18, 1068, 2382, 186, 186, false)
        assertEquals(0, position.edge)
        assertEquals(450 to 1107, position.place(18, 18, 1068, 2382, 186, 186))
    }
    @Test fun tinySafeAreaClampsToItsOrigin() {
        val position = OverlayBubblePosition(1, .5f, .8f)
        assertEquals(10 to 20, position.place(10, 20, 30, 40, 186, 186))
    }
}
