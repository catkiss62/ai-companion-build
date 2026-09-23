package com.aicompanion.localfirst

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TtsSessionPerformanceTest {
    @Test
    fun `session keeps detailed segment timing without plaintext`() {
        val session = TtsSessionPerformance(
            generation = 7L,
            manual = true,
            requestedRuntimeProfile = "auto_affinity_v084",
            startedAtEpochMs = 1_000L,
            startedAtNs = 1_000_000_000L,
        )
        session.recordSegment(
            segmentIndex = 0,
            inputChars = 12,
            textSha256 = "abc123",
            language = "zh",
            voice = "daily",
            checkpoint = checkpoint("auto_affinity_v084", 800L, 1_000L),
            generationCallMs = 910L,
            readyAtNs = 1_910_000_000L,
        )
        session.recordEnqueued(0, playbackSpeed = 1.0, atNs = 1_930_000_000L)
        session.recordPlaybackStarted(1_950_000_000L)

        val result = session.finish(
            stopped = false,
            playbackCompleted = true,
            completedAtEpochMs = 3_000L,
            completedAtNs = 3_000_000_000L,
        )

        assertEquals("completed", result["outcome"])
        assertEquals("auto_affinity_v084", result["runtimeProfile"])
        assertEquals(0.8, result["aggregateRtf"])
        assertEquals(910L, result["firstSegmentReadyMs"])
        assertEquals(950L, result["firstPlaybackStartMs"])
        assertFalse(result.toString().contains("这段文本"))
    }

    @Test
    fun `immediate stop is retained as rejected failed session`() {
        val session = TtsSessionPerformance(1L, false, "legacy_fixed_8", 1L, 0L)
        session.recordSegment(
            segmentIndex = 2,
            inputChars = 21,
            textSha256 = "deadbeef",
            language = "zh",
            voice = "cute",
            checkpoint = mapOf(
                "runtimeProfile" to "legacy_fixed_8",
                "immediateStop" to true,
                "semanticCount" to 0,
                "decoderIterations" to 1,
            ),
            generationCallMs = 30L,
            failureCode = "NoGeneratedSemanticTokensException",
            readyAtNs = 30_000_000L,
        )

        val result = session.finish(false, false, 40L, 40_000_000L)
        val segment = (result["segments"] as List<*>).single() as Map<*, *>
        assertEquals("failed", result["outcome"])
        assertEquals("rejected_no_generated_semantics", segment["outcome"])
        assertEquals(0, segment["semanticCount"])
    }

    @Test
    fun `same utterance compares native eight threads with auto affinity`() {
        val legacy = mapOf<String, Any?>(
            "utteranceSha256" to "same",
            "workloadSha256" to "same-workload",
            "runtimeProfile" to "legacy_fixed_8",
            "outcome" to "completed",
            "playbackCompleted" to true,
            "totalInferenceMs" to 2_000L,
            "aggregateRtf" to 1.1,
        )
        val affinity = mapOf<String, Any?>(
            "utteranceSha256" to "same",
            "workloadSha256" to "same-workload",
            "runtimeProfile" to "auto_affinity_v084",
            "outcome" to "completed",
            "playbackCompleted" to true,
            "totalInferenceMs" to 1_000L,
            "aggregateRtf" to 0.55,
        )

        val comparison = TtsPerformanceComparison.compare(listOf(legacy, affinity))

        assertTrue(comparison["comparable"] == true)
        assertEquals(50.0, comparison["autoAffinitySpeedupPercent"])
    }

    @Test
    fun `different utterances are never compared`() {
        val comparison = TtsPerformanceComparison.compare(
            listOf(
                mapOf("utteranceSha256" to "a", "workloadSha256" to "a", "runtimeProfile" to "legacy_fixed_8"),
                mapOf("utteranceSha256" to "b", "workloadSha256" to "b", "runtimeProfile" to "auto_affinity_v084"),
            ),
        )

        assertFalse(comparison["comparable"] == true)
        assertEquals("different_utterance", comparison["reason"])
    }

    @Test
    fun `partial or stopped sessions are never used for speedup`() {
        val comparison = TtsPerformanceComparison.compare(
            listOf(
                mapOf(
                    "utteranceSha256" to "same",
                    "workloadSha256" to "same-workload",
                    "runtimeProfile" to "legacy_fixed_8",
                    "outcome" to "partial",
                    "playbackCompleted" to true,
                ),
                mapOf(
                    "utteranceSha256" to "same",
                    "workloadSha256" to "same-workload",
                    "runtimeProfile" to "auto_affinity_v084",
                    "outcome" to "completed",
                    "playbackCompleted" to true,
                ),
            ),
        )

        assertFalse(comparison["comparable"] == true)
        assertEquals("incomplete_session", comparison["reason"])
    }

    private fun checkpoint(profile: String, inferenceMs: Long, audioMs: Long) = mapOf<String, Any>(
        "runtimeProfile" to profile,
        "modelLoadedThisRun" to true,
        "frontendMs" to 10L,
        "modelLoadMs" to 100L,
        "fixtureLoadMs" to 5L,
        "encoderMs" to 100L,
        "firstDecoderMs" to 50L,
        "autoregressiveMs" to 500L,
        "vocoderMs" to 150L,
        "totalInferenceMs" to inferenceMs,
        "endToEndMs" to 900L,
        "decoderIterations" to 80,
        "semanticCount" to 79,
        "pcmDurationMs" to audioMs,
        "coreRtf" to inferenceMs.toDouble() / audioMs,
    )
}
