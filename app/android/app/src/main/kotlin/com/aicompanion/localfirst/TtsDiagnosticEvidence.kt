package com.aicompanion.localfirst

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/** Pure, plaintext-free evidence helpers for diagnosing degenerate TTS output. */
object TtsDiagnosticEvidence {
    fun characterClasses(value: String): String {
        var cjk = 0
        var hiragana = 0
        var katakana = 0
        var latin = 0
        var digits = 0
        var punctuation = 0
        var whitespace = 0
        var other = 0
        value.codePoints().forEach { point ->
            when {
                point in 0x3400..0x9fff -> cjk += 1
                point in 0x3040..0x309f -> hiragana += 1
                point in 0x30a0..0x30ff -> katakana += 1
                point in 'A'.code..'Z'.code || point in 'a'.code..'z'.code -> latin += 1
                point in '0'.code..'9'.code -> digits += 1
                Character.isWhitespace(point) -> whitespace += 1
                isPunctuation(point) -> punctuation += 1
                else -> other += 1
            }
        }
        val total = cjk + hiragana + katakana + latin + digits + punctuation + whitespace + other
        return "total=$total;cjk=$cjk;hiragana=$hiragana;katakana=$katakana;latin=$latin;digits=$digits;punctuation=$punctuation;whitespace=$whitespace;other=$other"
    }

    fun pcmPayloadHash(wav: ByteArray): String {
        val range = wavDataRange(wav) ?: return ""
        return sha256(wav.copyOfRange(range.first, range.last + 1))
    }

    fun wavDurationMs(wav: ByteArray): Long {
        if (wav.size < 44 || ascii(wav, 0) != "RIFF" || ascii(wav, 8) != "WAVE") return 0L
        var channels = 0
        var sampleRate = 0
        var bitsPerSample = 0
        var dataBytes = 0
        var offset = 12
        while (offset + 8 <= wav.size) {
            val id = ascii(wav, offset)
            val size = littleEndianInt(wav, offset + 4).coerceAtLeast(0)
            val body = offset + 8
            if (body > wav.size) break
            if (id == "fmt " && size >= 16 && body + 16 <= wav.size) {
                channels = littleEndianShort(wav, body + 2)
                sampleRate = littleEndianInt(wav, body + 4)
                bitsPerSample = littleEndianShort(wav, body + 14)
            } else if (id == "data") {
                dataBytes = size.coerceAtMost(wav.size - body)
                break
            }
            val next = body.toLong() + size.toLong() + (size and 1)
            if (next <= offset || next > Int.MAX_VALUE) break
            offset = next.toInt()
        }
        val bytesPerSecond = sampleRate.toLong() * channels.toLong() * bitsPerSample.toLong() / 8L
        return if (dataBytes <= 0 || bytesPerSecond <= 0L) 0L else dataBytes * 1000L / bytesPerSecond
    }

    fun referenceEchoSuspected(
        decoderIterations: Int,
        semanticCount: Int,
        pcmDurationMs: Long,
    ): Boolean = decoderIterations <= 1 && semanticCount <= 1 && pcmDurationMs >= 250L

    private fun wavDataRange(wav: ByteArray): IntRange? {
        if (wav.size < 44 || ascii(wav, 0) != "RIFF" || ascii(wav, 8) != "WAVE") return null
        var offset = 12
        while (offset + 8 <= wav.size) {
            val id = ascii(wav, offset)
            val size = littleEndianInt(wav, offset + 4).coerceAtLeast(0)
            val body = offset + 8
            if (body > wav.size) return null
            if (id == "data") {
                val length = size.coerceAtMost(wav.size - body)
                return if (length <= 0) null else body until body + length
            }
            val next = body.toLong() + size.toLong() + (size and 1)
            if (next <= offset || next > Int.MAX_VALUE) return null
            offset = next.toInt()
        }
        return null
    }

    private fun ascii(bytes: ByteArray, offset: Int): String =
        if (offset < 0 || offset + 4 > bytes.size) ""
        else String(bytes, offset, 4, Charsets.US_ASCII)

    private fun littleEndianInt(bytes: ByteArray, offset: Int): Int =
        if (offset < 0 || offset + 4 > bytes.size) 0
        else ByteBuffer.wrap(bytes, offset, 4).order(ByteOrder.LITTLE_ENDIAN).int

    private fun littleEndianShort(bytes: ByteArray, offset: Int): Int =
        if (offset < 0 || offset + 2 > bytes.size) 0
        else ByteBuffer.wrap(bytes, offset, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt() and 0xffff

    private fun sha256(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { byte -> "%02x".format(byte) }

    private fun isPunctuation(point: Int): Boolean = when (Character.getType(point)) {
        Character.CONNECTOR_PUNCTUATION.toInt(),
        Character.DASH_PUNCTUATION.toInt(),
        Character.START_PUNCTUATION.toInt(),
        Character.END_PUNCTUATION.toInt(),
        Character.INITIAL_QUOTE_PUNCTUATION.toInt(),
        Character.FINAL_QUOTE_PUNCTUATION.toInt(),
        Character.OTHER_PUNCTUATION.toInt()
        -> true
        else -> false
    }
}
