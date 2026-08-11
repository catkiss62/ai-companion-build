package com.aicompanion.localfirst

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max

/** Minimal PCM-WAV player used by the local TTS adapter. */
class WavAudioPlayer {
    private val lock = Any()

    @Volatile
    private var track: AudioTrack? = null

    @Volatile
    private var stopped = false

    @Volatile
    private var volume = 1.0f

    fun setVolume(value: Float) {
        volume = value.coerceIn(0f, 1f)
        synchronized(lock) {
            runCatching { track?.setVolume(volume) }
        }
    }

    fun play(wavBytes: ByteArray) {
        val wav = parseWav(wavBytes)
        stop()
        stopped = false

        val channelMask = when (wav.channels) {
            1 -> AudioFormat.CHANNEL_OUT_MONO
            2 -> AudioFormat.CHANNEL_OUT_STEREO
            else -> error("Unsupported WAV channel count: ${wav.channels}")
        }
        val encoding = when (wav.bitsPerSample) {
            16 -> AudioFormat.ENCODING_PCM_16BIT
            8 -> AudioFormat.ENCODING_PCM_8BIT
            else -> error("Unsupported WAV bit depth: ${wav.bitsPerSample}")
        }
        if (wav.audioFormat != 1) {
            error("Unsupported WAV format ${wav.audioFormat}; PCM is required")
        }

        val minBuffer = AudioTrack.getMinBufferSize(wav.sampleRate, channelMask, encoding)
        if (minBuffer <= 0) error("AudioTrack rejected WAV format")
        val bufferSize = max(minBuffer, 16 * 1024)
        val next = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(encoding)
                    .setSampleRate(wav.sampleRate)
                    .setChannelMask(channelMask)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(bufferSize)
            .build()

        synchronized(lock) {
            track = next
            next.setVolume(volume)
            next.play()
        }

        var offset = wav.dataOffset
        val end = wav.dataOffset + wav.dataSize
        while (!stopped && offset < end) {
            val size = minOf(16 * 1024, end - offset)
            val written = next.write(wavBytes, offset, size, AudioTrack.WRITE_BLOCKING)
            if (written < 0) error("AudioTrack.write failed: $written")
            offset += written
        }

        // MODE_STREAM write completion can precede the final audible frames.
        val bytesPerFrame = wav.channels * (wav.bitsPerSample / 8)
        val targetFrames = if (bytesPerFrame > 0) wav.dataSize / bytesPerFrame else 0
        while (!stopped && next.playState == AudioTrack.PLAYSTATE_PLAYING &&
            next.playbackHeadPosition < targetFrames
        ) {
            Thread.sleep(12)
        }

        synchronized(lock) {
            if (track === next) track = null
        }
        runCatching { next.stop() }
        next.release()
    }

    fun pause() {
        synchronized(lock) { runCatching { track?.pause() } }
    }

    fun resume() {
        synchronized(lock) { runCatching { track?.play() } }
    }

    fun stop() {
        stopped = true
        val old = synchronized(lock) {
            val value = track
            track = null
            value
        }
        if (old != null) {
            runCatching { old.pause() }
            runCatching { old.flush() }
            runCatching { old.stop() }
            runCatching { old.release() }
        }
    }

    private fun parseWav(bytes: ByteArray): WavInfo {
        if (bytes.size < 44) error("WAV data is too short")
        fun ascii(offset: Int, length: Int) =
            String(bytes, offset, length, Charsets.US_ASCII)
        fun le16(offset: Int) = ByteBuffer.wrap(bytes, offset, 2)
            .order(ByteOrder.LITTLE_ENDIAN).short.toInt() and 0xffff
        fun le32(offset: Int) = ByteBuffer.wrap(bytes, offset, 4)
            .order(ByteOrder.LITTLE_ENDIAN).int

        if (ascii(0, 4) != "RIFF" || ascii(8, 4) != "WAVE") {
            error("TTS output is not a RIFF/WAVE file")
        }

        var audioFormat = 0
        var channels = 0
        var sampleRate = 0
        var bits = 0
        var dataOffset = -1
        var dataSize = -1
        var offset = 12
        while (offset + 8 <= bytes.size) {
            val id = ascii(offset, 4)
            val size = le32(offset + 4)
            if (size < 0) error("Invalid WAV chunk size")
            val body = offset + 8
            if (body + size > bytes.size) error("Truncated WAV chunk: $id")
            when (id) {
                "fmt " -> {
                    if (size < 16) error("Invalid WAV fmt chunk")
                    audioFormat = le16(body)
                    channels = le16(body + 2)
                    sampleRate = le32(body + 4)
                    bits = le16(body + 14)
                }
                "data" -> {
                    dataOffset = body
                    dataSize = size
                    break
                }
            }
            offset = body + size + (size and 1)
        }
        if (dataOffset < 0 || sampleRate <= 0 || channels <= 0 || bits <= 0) {
            error("Incomplete WAV header")
        }
        return WavInfo(audioFormat, channels, sampleRate, bits, dataOffset, dataSize)
    }

    private data class WavInfo(
        val audioFormat: Int,
        val channels: Int,
        val sampleRate: Int,
        val bitsPerSample: Int,
        val dataOffset: Int,
        val dataSize: Int,
    )
}
