package com.catkiss62.geniettsbenchmark

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class GeneratedSemanticTokensTest {
    @Test
    fun `first stage stop rejects every bundled voice prompt instead of vocoding it`() {
        // Daily/cute lengths are taken from the v0.42.3 device report; the
        // other two cases protect the same invariant for all selectable voices.
        mapOf(
            "daily" to 122,
            "gentle" to 96,
            "lively" to 104,
            "cute" to 87,
        ).forEach { (_, promptLength) ->
            val prompt = LongArray(promptLength) { (it + 1).toLong() }
            val error = assertThrows(NoGeneratedSemanticTokensException::class.java) {
                GeneratedSemanticTokens.select(prompt, generatedTokenCount = 0)
            }
            assertEquals(
                "TTS decoder stopped before generating semantic tokens",
                error.message,
            )
        }
    }

    @Test
    fun `normal generation selects only emitted tail and keeps source untouched`() {
        val decoderValues = longArrayOf(91L, 92L, 93L, 11L, 12L, 13L)

        val selected = GeneratedSemanticTokens.select(
            decoderValues,
            generatedTokenCount = 3,
        )

        assertArrayEquals(longArrayOf(11L, 12L, 0L), selected)
        assertArrayEquals(longArrayOf(91L, 92L, 93L, 11L, 12L, 13L), decoderValues)
    }

    @Test
    fun `generated count is bounded by decoder tensor length`() {
        val selected = GeneratedSemanticTokens.select(
            longArrayOf(7L, 8L, 9L),
            generatedTokenCount = 99,
        )

        assertArrayEquals(longArrayOf(7L, 8L, 0L), selected)
    }
}
