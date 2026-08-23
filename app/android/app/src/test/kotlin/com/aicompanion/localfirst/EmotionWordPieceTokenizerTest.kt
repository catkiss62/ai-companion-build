package com.aicompanion.localfirst

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class EmotionWordPieceTokenizerTest {
    private val vocabulary = mapOf(
        "[PAD]" to 0,
        "[UNK]" to 100,
        "[CLS]" to 101,
        "[SEP]" to 102,
        "高" to 200,
        "兴" to 201,
        "hello" to 202,
        "!" to 203,
    )

    @Test
    fun encodesChineseAndLatinWithFixedPadding() {
        val ids = EmotionWordPieceTokenizer(vocabulary).encode("高兴 hello!", 8)
        assertArrayEquals(
            longArrayOf(101, 200, 201, 202, 203, 102, 0, 0),
            ids,
        )
    }

    @Test
    fun unknownTokenUsesUnkWithoutChangingLength() {
        val ids = EmotionWordPieceTokenizer(vocabulary).encode("未知", 5)
        assertEquals(5, ids.size)
        assertEquals(101L, ids.first())
        assertEquals(102L, ids[3])
    }
}
