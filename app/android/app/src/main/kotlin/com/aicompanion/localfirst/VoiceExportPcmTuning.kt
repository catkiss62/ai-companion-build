package com.aicompanion.localfirst

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs

/** Offline tuning only: no AudioTrack, playback settings, files, or model inference. */
@androidx.annotation.OptIn(UnstableApi::class)
internal object VoiceExportPcmTuning {
    private const val MAX_BYTES = 10 * 1024 * 1024
    private const val CHUNK_BYTES = 16 * 1024

    fun apply(wav: ByteArray, pitch: Double, shouldCancel: () -> Boolean = { false }): ByteArray {
        fun current() = check(!shouldCancel()) { "voice_export_preempted" }
        current()
        require(pitch.isFinite() && pitch in 0.5..2.0) { "voice_export_pitch" }
        require(wav.size in 46..MAX_BYTES) { "voice_export_audio" }
        val header = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
        fun tag(at: Int, value: String) = value.indices.all { wav[at + it].toInt() == value[it].code }
        require(tag(0, "RIFF") && tag(8, "WAVE") && tag(12, "fmt ") && tag(36, "data") &&
            header.getInt(4) == wav.size - 8 && header.getInt(16) == 16 &&
            header.getShort(20).toInt() == 1 && header.getShort(34).toInt() == 16 &&
            header.getInt(40) == wav.size - 44) { "voice_export_audio" }
        val channels = header.getShort(22).toInt()
        val rate = header.getInt(24)
        val frameBytes = channels * 2
        require(channels in 1..2 && rate in 8000..48000 &&
            header.getShort(32).toInt() == frameBytes && header.getInt(28) == rate * frameBytes &&
            (wav.size - 44) % frameBytes == 0 &&
            (wav.size - 44).toLong() <= rate.toLong() * frameBytes * 75) { "voice_export_audio" }
        if (abs(pitch - 1.0) < 0.000001) return wav

        val processor = SonicAudioProcessor()
        try {
            // Pitch and speed are independent. Keep timing and sample-rate metadata.
            processor.setSpeed(1.0f)
            processor.setPitch(pitch.toFloat())
            processor.configure(AudioProcessor.AudioFormat(rate, channels, C.ENCODING_PCM_16BIT))
            processor.flush()
            val pcm = ByteArrayOutputStream(wav.size - 44)
            fun drain() {
                current()
                val output = processor.output
                if (output.hasRemaining()) {
                    require(pcm.size().toLong() + output.remaining() + 44 <= MAX_BYTES) { "voice_export_audio_size" }
                    val block = ByteArray(output.remaining())
                    output.get(block)
                    pcm.write(block)
                }
            }
            var offset = 44
            while (offset < wav.size) {
                current()
                val length = minOf(CHUNK_BYTES, wav.size - offset)
                val input = ByteBuffer.allocateDirect(length).order(ByteOrder.nativeOrder())
                input.put(wav, offset, length).flip()
                while (input.hasRemaining()) {
                    current()
                    val before = input.position()
                    processor.queueInput(input)
                    drain()
                    check(input.position() > before) { "voice_export_audio_stalled" }
                }
                offset += length
            }
            processor.queueEndOfStream()
            while (!processor.isEnded) {
                val before = pcm.size()
                drain()
                check(processor.isEnded || pcm.size() > before) { "voice_export_audio_stalled" }
            }
            current()
            val body = pcm.toByteArray()
            require(body.isNotEmpty() && body.size % frameBytes == 0) { "voice_export_audio" }
            val output = wav.copyOf(44 + body.size)
            body.copyInto(output, 44)
            ByteBuffer.wrap(output).order(ByteOrder.LITTLE_ENDIAN).apply {
                putInt(4, output.size - 8)
                putInt(40, body.size)
            }
            return output
        } finally {
            processor.reset()
        }
    }
}
