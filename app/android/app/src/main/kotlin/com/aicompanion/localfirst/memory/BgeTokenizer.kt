package com.aicompanion.localfirst.memory

/** BertNormalizer (case sensitive, no accent stripping) + BertPreTokenizer + WordPiece.
 * Matches the pinned Xenova tokenizer.json; special tokens are supplied by the caller. */
class BgeTokenizer(private val vocab: Map<String, Int>) {
    fun encode(text: String, limit: Int = 512): LongArray {
        val basic = mutableListOf<String>()
        val word = StringBuilder()
        fun flush() { if (word.isNotEmpty()) { basic.add(word.toString()); word.setLength(0) } }
        fun consume(part: String) { part.codePoints().forEach { cp ->
            val type = Character.getType(cp)
            when {
                cp == 0 || cp == 0xfffd -> Unit
                cp == 9 || cp == 10 || cp == 13 || cp == 32 || type == Character.SPACE_SEPARATOR.toInt() -> flush()
                type == Character.CONTROL.toInt() || type == Character.FORMAT.toInt() -> Unit
                chinese(cp) || punctuation(cp) -> { flush(); basic.add(String(Character.toChars(cp))) }
                else -> word.appendCodePoint(cp)
            }
        }
        flush()
        }
        var cursor = 0
        Regex("\\[(?:UNK|SEP|PAD|CLS|MASK)\\]").findAll(text).forEach { match ->
            consume(text.substring(cursor, match.range.first))
            basic.add(match.value)
            cursor = match.range.last + 1
        }
        consume(text.substring(cursor))
        val ids = mutableListOf(101L)
        for (token in basic) {
            val points = token.codePoints().toArray()
            val pieces = mutableListOf<Long>()
            var start = 0
            var failed = points.size > 100
            while (!failed && start < points.size) {
                var end = points.size
                var found: Int? = null
                while (end > start) {
                    val piece = (if (start > 0) "##" else "") + java.lang.String(points, start, end - start).toString()
                    found = vocab[piece]
                    if (found != null) break
                    end--
                }
                if (found == null) failed = true else { pieces.add(found.toLong()); start = end }
            }
            for (id in if (failed) listOf(100L) else pieces) {
                if (ids.size >= limit - 1) break
                ids.add(id)
            }
            if (ids.size >= limit - 1) break
        }
        ids.add(102L)
        return ids.toLongArray()
    }
    private fun chinese(c: Int) = c in 0x4e00..0x9fff || c in 0x3400..0x4dbf ||
        c in 0x20000..0x2a6df || c in 0x2a700..0x2b73f || c in 0x2b740..0x2b81f ||
        c in 0x2b820..0x2ceaf || c in 0xf900..0xfaff || c in 0x2f800..0x2fa1f
    private fun punctuation(c: Int): Boolean {
        if (c in 33..47 || c in 58..64 || c in 91..96 || c in 123..126) return true
        return Character.getType(c) in setOf(Character.CONNECTOR_PUNCTUATION.toInt(),
            Character.DASH_PUNCTUATION.toInt(), Character.START_PUNCTUATION.toInt(),
            Character.END_PUNCTUATION.toInt(), Character.INITIAL_QUOTE_PUNCTUATION.toInt(),
            Character.FINAL_QUOTE_PUNCTUATION.toInt(), Character.OTHER_PUNCTUATION.toInt())
    }
}
