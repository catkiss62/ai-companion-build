package com.aicompanion.localfirst

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ReferenceAudioEchoGuardTest {
    @Test
    fun `feature correlation recognizes the same waveform shape`() {
        val first = FloatArray(4096) { index ->
            (kotlin.math.sin(index / 11.0) * (0.2 + (index % 300) / 1000.0)).toFloat()
        }
        val scaled = FloatArray(first.size) { index -> first[index] * 0.55f }
        val firstFeatures = ReferenceAudioEchoGuard.features(first)
        val scaledFeatures = ReferenceAudioEchoGuard.features(scaled)

        assertTrue(
            ReferenceAudioEchoGuard.correlation(firstFeatures.first, scaledFeatures.first) > 0.999,
        )
        assertTrue(
            ReferenceAudioEchoGuard.correlation(firstFeatures.second, scaledFeatures.second) > 0.999,
        )
    }

    @Test
    fun `invalid or different feature vectors cannot create a match`() {
        assertEquals(
            -1.0,
            ReferenceAudioEchoGuard.correlation(doubleArrayOf(1.0), doubleArrayOf()),
            0.0,
        )
        assertTrue(
            ReferenceAudioEchoGuard.correlation(
                doubleArrayOf(-1.0, 0.0, 1.0),
                doubleArrayOf(1.0, 0.0, -1.0),
            ) < 0.0,
        )
    }
}
