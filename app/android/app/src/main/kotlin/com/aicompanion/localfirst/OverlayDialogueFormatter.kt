package com.aicompanion.localfirst

/** Pure text shaping shared by the native overlay and JVM contract tests. */
object OverlayDialogueFormatter {
    fun visibleText(value: String): String {
        val closed = Regex("（([^（）\\n]*)）|\\(([^()\\n]*)\\)").replace(value) { match ->
            match.groups[1]?.value ?: match.groups[2]?.value.orEmpty()
        }
        return Regex("(?m)(^|\\n)[（(](?=[^）)\\n]*(?:$|\\n))").replace(closed) { match ->
            match.groups[1]?.value.orEmpty()
        }
    }

    fun dialogueRanges(value: String): List<IntRange> =
        Regex("「[^」\\n]*(?:」|$)")
            .findAll(value)
            .map { it.range }
            .toList()
}
