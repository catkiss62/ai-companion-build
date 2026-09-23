package com.aicompanion.localfirst

import android.content.Context
import org.json.JSONObject
import java.security.MessageDigest
import kotlin.math.ln
import kotlin.math.sqrt

data class ReferenceAudioEchoAssessment(
    val suspected: Boolean,
    val similarity: Double = 0.0,
    val reason: String = "none",
)

data class ReferenceAudioSignature(
    val durationMs: Long,
    val inputTextSha256: String,
    val envelope: DoubleArray,
    val zeroCrossing: DoubleArray,
)

/**
 * Detects the voice-conditioning reference leaking into generated playback.
 * Only compact, non-reversible acoustic features are packaged; reference WAVs
 * remain removed from the APK. A high-confidence match is rejected instead of
 * being replaced with system TTS, a canned sentence or the reference itself.
 */
class ReferenceAudioEchoGuard(context: Context) {
    private val signatures: Map<String, ReferenceAudioSignature> = runCatching {
        context.assets.open(ASSET).bufferedReader().use { reader ->
            parse(JSONObject(reader.readText()))
        }
    }.getOrDefault(emptyMap())

    fun assess(
        referenceCaseId: String,
        normalizedText: String,
        audio: FloatArray,
        sampleRate: Int,
    ): ReferenceAudioEchoAssessment {
        val reference = signatures[referenceCaseId]
            ?: return ReferenceAudioEchoAssessment(false, reason = "signature_unavailable")
        if (audio.isEmpty() || sampleRate <= 0) {
            return ReferenceAudioEchoAssessment(false, reason = "invalid_generated_audio")
        }
        if (sha256(normalizedText.trim()) == reference.inputTextSha256) {
            return ReferenceAudioEchoAssessment(false, reason = "requested_reference_text")
        }
        val durationMs = audio.size.toLong() * 1000L / sampleRate
        val durationTolerance = maxOf(250L, (reference.durationMs * 0.08).toLong())
        if (kotlin.math.abs(durationMs - reference.durationMs) > durationTolerance) {
            return ReferenceAudioEchoAssessment(false, reason = "duration_mismatch")
        }
        val generated = features(audio, reference.envelope.size)
        val envelopeSimilarity = correlation(reference.envelope, generated.first)
        val crossingSimilarity = correlation(reference.zeroCrossing, generated.second)
        val combined = (envelopeSimilarity * 0.72 + crossingSimilarity * 0.28)
            .coerceIn(-1.0, 1.0)
        val suspected = envelopeSimilarity >= 0.965 &&
            crossingSimilarity >= 0.88 &&
            combined >= 0.945
        return ReferenceAudioEchoAssessment(
            suspected = suspected,
            similarity = combined,
            reason = if (suspected) "acoustic_reference_match" else "acoustic_mismatch",
        )
    }

    companion object {
        private const val ASSET = "benchmark/reference_echo_guard.json"

        fun parse(root: JSONObject): Map<String, ReferenceAudioSignature> {
            val cases = root.optJSONObject("cases") ?: return emptyMap()
            return cases.keys().asSequence().mapNotNull { id ->
                val item = cases.optJSONObject(id) ?: return@mapNotNull null
                fun values(key: String): DoubleArray {
                    val array = item.optJSONArray(key) ?: return DoubleArray(0)
                    return DoubleArray(array.length()) { index -> array.optDouble(index, 0.0) }
                }
                val envelope = values("envelope")
                val crossing = values("zero_crossing")
                if (envelope.size < 16 || crossing.size != envelope.size) {
                    return@mapNotNull null
                }
                id to ReferenceAudioSignature(
                    durationMs = item.optLong("duration_ms", 0L),
                    inputTextSha256 = item.optString("input_text_sha256", ""),
                    envelope = envelope,
                    zeroCrossing = crossing,
                )
            }.toMap()
        }

        fun features(samples: FloatArray, bins: Int = 64): Pair<DoubleArray, DoubleArray> {
            if (samples.isEmpty() || bins <= 0) return DoubleArray(0) to DoubleArray(0)
            val envelope = DoubleArray(bins)
            val crossing = DoubleArray(bins)
            for (bin in 0 until bins) {
                val start = samples.size * bin / bins
                val end = maxOf(start + 1, samples.size * (bin + 1) / bins)
                    .coerceAtMost(samples.size)
                var energy = 0.0
                var changes = 0
                var previous = samples[start]
                for (index in start until end) {
                    val value = samples[index].toDouble()
                    energy += value * value
                    if (index > start && (samples[index] >= 0f) != (previous >= 0f)) changes += 1
                    previous = samples[index]
                }
                envelope[bin] = ln(1.0 + 1000.0 * sqrt(energy / (end - start)))
                crossing[bin] = changes.toDouble() / maxOf(1, end - start - 1)
            }
            return normalize(envelope) to normalize(crossing)
        }

        fun correlation(first: DoubleArray, second: DoubleArray): Double {
            if (first.size != second.size || first.isEmpty()) return -1.0
            var dot = 0.0
            var firstNorm = 0.0
            var secondNorm = 0.0
            for (index in first.indices) {
                dot += first[index] * second[index]
                firstNorm += first[index] * first[index]
                secondNorm += second[index] * second[index]
            }
            if (firstNorm <= 1e-12 || secondNorm <= 1e-12) return -1.0
            return dot / sqrt(firstNorm * secondNorm)
        }

        private fun normalize(values: DoubleArray): DoubleArray {
            val mean = values.average()
            val variance = values.sumOf { value ->
                val centered = value - mean
                centered * centered
            } / values.size
            val scale = sqrt(variance).coerceAtLeast(1e-9)
            return DoubleArray(values.size) { index -> (values[index] - mean) / scale }
        }

        private fun sha256(value: String): String = MessageDigest
            .getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte) }
    }
}
