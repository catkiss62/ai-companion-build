package com.aicompanion.localfirst

/** Display-only semantic positions indexed by real PCM frames, not enqueue time. */
internal class SpeechPlaybackTimeline {
    private data class Span(val first: Long, val last: Long, val start: Int,
        val count: Int, val fingerprint: String, val language: String)
    private val spans = ArrayDeque<Span>()

    @Synchronized fun append(first: Long, frames: Long, metadata: Map<*, *>?) {
        if (frames <= 0 || metadata == null) return
        val start = (metadata["textStart"] as? Number)?.toInt() ?: return
        val count = (metadata["textLength"] as? Number)?.toInt() ?: return
        val fingerprint = metadata["fingerprint"] as? String ?: return
        val language = metadata["language"] as? String ?: return
        if (start < 0 || count <= 0 || !Regex("[a-f0-9]{64}").matches(fingerprint)) return
        spans.addLast(Span(first, first + frames, start, count, fingerprint, language))
    }

    @Synchronized fun sample(head: Long): Map<String, Any> {
        while (spans.isNotEmpty() && spans.first().last <= head) spans.removeFirst()
        val span = spans.firstOrNull()?.takeIf { head >= it.first && head < it.last }
            ?: return emptyMap()
        val progress = (head - span.first).toDouble() / (span.last - span.first)
        return mapOf("spoken_position" to (span.start + progress * span.count),
            "spoken_fingerprint" to span.fingerprint, "spoken_language" to span.language)
    }
}
