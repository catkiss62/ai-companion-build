package com.catkiss62.geniettsbenchmark

/**
 * Extracts only semantic tokens emitted by the autoregressive stage decoder.
 *
 * The decoder output also contains the reference prompt prefix. A stop signal
 * on the first stage call therefore means there are zero generated tokens; it
 * must never fall back to the whole output tensor or the vocoder will recreate
 * the reference recording.
 */
class NoGeneratedSemanticTokensException(
    val decoderIterations: Int,
) : IllegalStateException("TTS decoder stopped before generating semantic tokens")

internal object GeneratedSemanticTokens {
    fun select(decoderValues: LongArray, generatedTokenCount: Int): LongArray {
        if (generatedTokenCount <= 0) throw NoGeneratedSemanticTokensException(1)
        check(decoderValues.isNotEmpty()) { "TTS decoder returned no semantic tensor" }

        val semanticCount = generatedTokenCount.coerceAtMost(decoderValues.size)
        val selected = decoderValues.copyOfRange(
            decoderValues.size - semanticCount,
            decoderValues.size,
        )
        // Match Genie's Python inference: force the final EOS value before the
        // invalid-token trim, without mutating the decoder-owned source array.
        selected[selected.lastIndex] = 0L
        val firstInvalid = selected.indexOfFirst { it >= 1024L }
        return when {
            firstInvalid > 0 -> selected.copyOf(firstInvalid)
            firstInvalid == 0 -> longArrayOf(0L)
            else -> selected
        }
    }
}
