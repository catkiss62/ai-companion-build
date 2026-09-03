package com.aicompanion.localfirst

/** Pure text shaping shared by the native overlay and JVM contract tests. */
object OverlayDialogueFormatter {
    fun visibleText(value: String): String {
        val closed = Regex("（([^（）\\n]*)）|\\(([^()\\n]*)\\)").replace(value) { match ->
            match.groups[1]?.value ?: match.groups[2]?.value.orEmpty()
        }
        val withoutOpening = Regex("(?m)(^|\\n)[（(](?=[^）)\\n]*(?:$|\\n))").replace(closed) { match ->
            match.groups[1]?.value.orEmpty()
        }
        return Regex("([^\\n])\\n(?=「)").replace(withoutOpening, "$1\n\n")
    }

    fun dialogueRanges(value: String): List<IntRange> {
        val result = mutableListOf<IntRange>()
        var index = 0
        while (index < value.length) {
            if (value[index] != '「') {
                index += 1
                continue
            }

            val start = index
            var depth = 1
            index += 1
            while (index < value.length && value[index] != '\n') {
                when (value[index]) {
                    '「' -> depth += 1
                    '」' -> {
                        depth -= 1
                        index += 1
                        if (depth == 0) break
                        continue
                    }
                }
                index += 1
            }

            // Unclosed streaming dialogue remains tinted through the current
            // end. A malformed cross-line quote does not consume later blocks.
            val reachedEnd = index == value.length
            if (depth == 0 || reachedEnd) {
                result += start until index
            }
        }
        // Plain assistant text is dialogue. Without this fallback the overlay
        // rendered every no-action response as white italic action text.
        return if (result.isEmpty() && value.isNotEmpty()) listOf(value.indices) else result
    }

    fun actionRanges(value: String): List<IntRange> {
        val dialogue = dialogueRanges(value)
        if (dialogue.isEmpty()) return emptyList()
        val result = mutableListOf<IntRange>()
        var cursor = 0
        dialogue.forEach { range ->
            if (range.first > cursor) result += cursor until range.first
            cursor = range.last + 1
        }
        if (cursor < value.length) result += cursor until value.length
        return result
    }
}
