package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test

class SpeechPlaybackTimelineTest {
    private fun meta(start: Int, count: Int) = mapOf("textStart" to start,
        "textLength" to count, "fingerprint" to "a".repeat(64), "language" to "zh")
    @Test fun queuedAudioDoesNotAdvancePresentation() {
        val timeline = SpeechPlaybackTimeline()
        timeline.append(0, 1000, meta(0, 10))
        timeline.append(1000, 1000, meta(10, 20))
        assertEquals(5.0, timeline.sample(500)["spoken_position"])
        assertEquals(10.0, timeline.sample(1000)["spoken_position"])
        assertEquals(20.0, timeline.sample(1500)["spoken_position"])
    }
    @Test fun skippedFailedSpeechKeepsTheOriginalTextPosition() {
        val timeline = SpeechPlaybackTimeline()
        timeline.append(0, 1000, meta(20, 10))
        assertEquals(25.0, timeline.sample(500)["spoken_position"])
    }
    @Test fun pausesAndSpeedChangesFollowFramesInsteadOfWallTime() {
        val timeline = SpeechPlaybackTimeline()
        timeline.append(0, 1000, meta(0, 10))
        assertEquals(timeline.sample(200), timeline.sample(200))
        assertEquals(8.0, timeline.sample(800)["spoken_position"])
        assertTrue(timeline.sample(1000).isEmpty())
    }
    @Test fun missingOrInvalidMetadataCannotBorrowAnEarlierCue() {
        val timeline = SpeechPlaybackTimeline()
        timeline.append(0, 100, meta(0, 10))
        timeline.append(100, 100, null)
        timeline.append(200, 100, mapOf("textStart" to 0))
        assertTrue(timeline.sample(150).isEmpty())
        assertTrue(timeline.sample(250).isEmpty())
    }
}
