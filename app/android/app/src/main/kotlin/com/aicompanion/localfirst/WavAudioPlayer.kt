package com.aicompanion.localfirst

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.PlaybackParams
import android.media.audiofx.LoudnessEnhancer
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import kotlin.math.max
import kotlin.math.min
import kotlin.math.log10
import kotlin.math.roundToInt

/** One utterance = one AudioTrack, matching the verified Genie v0.6.4 player. */
class WavAudioPlayer {
    private sealed interface Command {
        data class Audio(val bytes: ByteArray, val wav: WavInfo) : Command
        data object Finish : Command
        data object Cancel : Command
    }

    private val lock = Any()

    @Volatile
    private var stream: StreamSession? = null

    @Volatile
    private var volume = 1.0f

    @Volatile
    private var speed = 1.0f

    fun setVolume(value: Float) {
        volume = value.coerceIn(0f, 2f)
        stream?.setVolume(volume)
    }

    fun setSpeed(value: Float) {
        speed = value.coerceIn(0.5f, 2f)
        stream?.setSpeed(speed)
    }

    fun beginStream(onStarted: () -> Unit = {}) {
        stop()
        val next = StreamSession(volume, speed, onStarted)
        synchronized(lock) { stream = next }
        next.start()
    }

    fun enqueueStream(wavBytes: ByteArray) {
        val wav = parseWav(wavBytes)
        val current = synchronized(lock) { stream }
            ?: error("TTS audio stream has not started")
        current.enqueue(wavBytes, wav)
    }

    /** Returns true only when AudioTrack actually started and drained. */
    fun finishStream(): Boolean {
        val current = synchronized(lock) { stream } ?: return false
        return try {
            current.finishAndWait()
        } finally {
            synchronized(lock) {
                if (stream === current) stream = null
            }
        }
    }

    fun play(wavBytes: ByteArray) {
        beginStream()
        enqueueStream(wavBytes)
        finishStream()
    }

    fun pause() = stream?.pause()

    fun resume() = stream?.resume()

    fun stop() {
        val old = synchronized(lock) {
            val value = stream
            stream = null
            value
        }
        old?.cancel()
    }

    private inner class StreamSession(
        initialVolume: Float,
        initialSpeed: Float,
        private val onStarted: () -> Unit,
    ) {
        private val queue = LinkedBlockingQueue<Command>()
        private val started = CountDownLatch(1)
        private val completed = CountDownLatch(1)
        private val thread = Thread(::runWriter, "Genie-TTS-stream-player").apply {
            isDaemon = true
        }

        @Volatile private var cancelled = false
        @Volatile private var failure: Throwable? = null
        @Volatile private var track: AudioTrack? = null
        @Volatile private var enhancer: LoudnessEnhancer? = null
        @Volatile private var playbackStarted = false
        @Volatile private var currentVolume = initialVolume
        @Volatile private var currentSpeed = initialSpeed
        private var firstEnqueued = false

        fun start() = thread.start()

        fun setVolume(value: Float) {
            currentVolume = value.coerceIn(0f, 2f)
            val currentTrack = track ?: return
            applyVolume(currentTrack, enhancer)
        }

        fun setSpeed(value: Float) {
            currentSpeed = value.coerceIn(0.5f, 2f)
            track?.let(::applySpeed)
        }

        fun enqueue(bytes: ByteArray, wav: WavInfo) {
            check(!cancelled) { "TTS audio stream has stopped" }
            val isFirst = synchronized(this) {
                (!firstEnqueued).also { firstEnqueued = true }
            }
            queue.put(Command.Audio(bytes, wav))
            if (isFirst) {
                started.await()
                failure?.let { throw it }
                check(playbackStarted) { "AudioTrack did not start" }
            }
        }

        fun finishAndWait(): Boolean {
            if (!cancelled) queue.put(Command.Finish)
            completed.await()
            failure?.let { throw it }
            return playbackStarted && !cancelled
        }

        fun cancel() {
            cancelled = true
            queue.offer(Command.Cancel)
            runCatching { track?.pause() }
            runCatching { track?.flush() }
            started.countDown()
        }

        fun pause() {
            runCatching { track?.pause() }
        }

        fun resume() {
            runCatching { track?.play() }
        }

        private fun runWriter() {
            var localTrack: AudioTrack? = null
            var format: WavInfo? = null
            var framesWritten = 0L
            try {
                while (!cancelled) {
                    when (val command = queue.take()) {
                        Command.Cancel -> break
                        Command.Finish -> break
                        is Command.Audio -> {
                            val wav = command.wav
                            if (format == null) {
                                format = wav
                                val created = createTrack(wav)
                                localTrack = created
                                track = created
                                enhancer = runCatching {
                                    LoudnessEnhancer(created.audioSessionId)
                                }.getOrNull()
                                // Genie leaves the default 1.0x track untouched.
                                // Only opt into Android time-stretch when the
                                // user explicitly selects a different speed.
                                if (currentSpeed != 1.0f) applySpeed(created)
                                applyVolume(created, enhancer)
                            } else {
                                check(checkNotNull(format).samePcmFormat(wav)) {
                                    "TTS stream WAV format changed between segments"
                                }
                            }
                            val writer = checkNotNull(localTrack)
                            val bytesPerFrame = wav.bytesPerFrame
                            var offset = wav.dataOffset
                            if (!playbackStarted) {
                                // Exact v0.6.4 policy: write up to one second of
                                // PCM first, then start playback. This is buffer
                                // prefill, not a one-second wall-clock delay.
                                val prefillBytes = min(
                                    wav.dataSize,
                                    wav.sampleRate * bytesPerFrame,
                                )
                                offset += writeFully(
                                    writer,
                                    command.bytes,
                                    offset,
                                    prefillBytes,
                                )
                                if (cancelled) break
                                writer.play()
                                playbackStarted = true
                                onStarted()
                                started.countDown()
                            }
                            val remaining = wav.dataOffset + wav.dataSize - offset
                            if (remaining > 0) {
                                writeFully(writer, command.bytes, offset, remaining)
                            }
                            framesWritten += wav.dataSize / bytesPerFrame
                        }
                    }
                }

                val drainingTrack = localTrack
                if (!cancelled && playbackStarted && drainingTrack != null) {
                    while (!cancelled && playbackHeadFrames(drainingTrack) < framesWritten) {
                        Thread.sleep(12L)
                    }
                    if (!cancelled) runCatching { drainingTrack.stop() }
                }
            } catch (error: Throwable) {
                failure = error
                started.countDown()
            } finally {
                runCatching { enhancer?.release() }
                enhancer = null
                runCatching { localTrack?.release() }
                track = null
                completed.countDown()
            }
        }

        private fun createTrack(wav: WavInfo): AudioTrack {
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
            check(wav.audioFormat == 1) {
                "Unsupported WAV format ${wav.audioFormat}; PCM is required"
            }
            val minBuffer = AudioTrack.getMinBufferSize(wav.sampleRate, channelMask, encoding)
            check(minBuffer > 0) { "AudioTrack rejected WAV format" }
            return AudioTrack.Builder()
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
                .setBufferSizeInBytes(max(minBuffer, wav.sampleRate * wav.bytesPerFrame * 2))
                .build()
        }

        private fun applySpeed(target: AudioTrack) {
            target.playbackParams = PlaybackParams()
                .setAudioFallbackMode(PlaybackParams.AUDIO_FALLBACK_MODE_DEFAULT)
                .setPitch(1.0f)
                .setSpeed(currentSpeed)
        }

        private fun applyVolume(
            target: AudioTrack,
            loudnessEnhancer: LoudnessEnhancer?,
        ) {
            val requested = currentVolume.coerceIn(0f, 2f)
            target.setVolume(requested.coerceAtMost(1f))
            if (requested <= 1f) {
                loudnessEnhancer?.enabled = false
                return
            }
            checkNotNull(loudnessEnhancer) {
                "Android LoudnessEnhancer is unavailable for TTS boost"
            }
            loudnessEnhancer.setTargetGain(
                (2000.0 * log10(requested.toDouble())).roundToInt(),
            )
            loudnessEnhancer.enabled = true
        }

        private fun writeFully(
            target: AudioTrack,
            bytes: ByteArray,
            start: Int,
            count: Int,
        ): Int {
            var offset = start
            val end = start + count
            while (!cancelled && offset < end) {
                val written = target.write(bytes, offset, end - offset, AudioTrack.WRITE_BLOCKING)
                check(written > 0) { "AudioTrack.write failed: $written" }
                offset += written
            }
            return offset - start
        }
    }

    private fun playbackHeadFrames(target: AudioTrack): Long =
        target.playbackHeadPosition.toLong() and 0xffff_ffffL

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
    ) {
        val bytesPerFrame: Int
            get() = channels * (bitsPerSample / 8)

        fun samePcmFormat(other: WavInfo): Boolean =
            audioFormat == other.audioFormat &&
                channels == other.channels &&
                sampleRate == other.sampleRate &&
                bitsPerSample == other.bitsPerSample
    }
}
