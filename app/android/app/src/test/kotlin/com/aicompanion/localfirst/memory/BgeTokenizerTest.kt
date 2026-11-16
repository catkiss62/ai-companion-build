package com.aicompanion.localfirst.memory

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class BgeTokenizerTest {
    private val tokenizer = BgeTokenizer(mapOf("[MASK]" to 103, "面" to 1, "试" to 2,
        "Hello" to 3, "##s" to 4, "!" to 5, "café" to 6))
    @Test fun chineseAndWordPieceKeepCaseAndAccents() {
        assertArrayEquals(longArrayOf(101,1,2,3,4,5,6,102), tokenizer.encode("面试 Hellos! café"))
        assertArrayEquals(longArrayOf(101,100,102), tokenizer.encode("hello"))
    }
    @Test fun specialTokensAndControlCharactersMatchBert() {
        assertArrayEquals(longArrayOf(101,103,1,2,102), tokenizer.encode("[MASK]面\u0000试"))
    }
    @Test fun truncationKeepsFinalSeparator() {
        assertArrayEquals(longArrayOf(101,1,2,1,102), tokenizer.encode("面试面试",5))
    }
}
