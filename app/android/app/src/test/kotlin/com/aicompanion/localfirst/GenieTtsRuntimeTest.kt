package com.aicompanion.localfirst

import com.catkiss62.geniettsbenchmark.PreparedText
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class GenieTtsRuntimeTest {
    @Test
    fun legacyNaiyouJapaneseDropsUnsupportedPitchMarkersAndMatchingBertRows() {
        val prepared = PreparedText(
            text = "テスト",
            normalizedText = "テスト",
            sequence = longArrayOf(1, 322, 40, 323, 321),
            bert = floatArrayOf(10f, 11f, 20f, 21f, 30f, 31f, 40f, 41f, 50f, 51f),
            bertDim = 2,
            frontendMs = 1,
            diagnostic = "OpenJTalk",
        )

        val sanitized = GenieTtsRuntime.sanitizeLegacyJapanese(prepared)

        assertArrayEquals(longArrayOf(1, 40, 321), sanitized.sequence)
        assertArrayEquals(floatArrayOf(10f, 11f, 30f, 31f, 50f, 51f), sanitized.bert, 0f)
        assertEquals(6, sanitized.bert.size)
        assertEquals(true, sanitized.diagnostic.contains("过滤2个"))
    }

    @Test
    fun compatibleJapanesePreparedTextIsReturnedWithoutCopying() {
        val prepared = PreparedText(
            text = "テスト",
            normalizedText = "テスト",
            sequence = longArrayOf(1, 40, 321),
            bert = FloatArray(6),
            bertDim = 2,
            frontendMs = 1,
            diagnostic = "OpenJTalk",
        )

        assertSame(prepared, GenieTtsRuntime.sanitizeLegacyJapanese(prepared))
    }
}
