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
import kotlin.math.sqrt
import com.catkiss.senlive2dcompanion.SenLive2DRuntime

/** One utterance = one AudioTrack, matching the verified Genie v0.6.4 player. */
class WavAudioPlayer {
    private sealed interface Command {
        data class Audio(
            val bytes: ByteArray,
            val wav: WavInfo,
            val speed: Float,
        ) : Command
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

    @Volatile
    private var pitch = 1.0f

    fun setVolume(value: Float) {
        volume = value.coerceIn(0f, 2f)
        stream?.setVolume(volume)
    }

    fun setSpeed(value: Float) {
        speed = value.coerceIn(0.5f, 2f)
        stream?.setSpeed(speed)
    }

    fun setPitch(value: Float) {
        pitch = value.coerceIn(0.5f, 2f)
        stream?.setPitch(pitch)
    }

    fun beginStream(onStarted: () -> Unit = {}) {
        stop()
        val next = StreamSession(volume, speed, pitch, onStarted)
        synchronized(lock) { stream = next }
        next.start()
    }

    fun enqueueStream(wavBytes: ByteArray, segmentSpeed: Float = speed) {
        val wav = parseWav(wavBytes)
        val current = synchronized(lock) { stream }
            ?: error("TTS audio stream has not started")
        current.enqueue(wavBytes, wav, segmentSpeed.coerceIn(0.5f, 2f))
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
        initialPitch: Float,
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
        @Volatile private var currentPitch = initialPitch
        private var firstEnqueued = false
        private val envelopeLock = Any()
        private val envelopes = mutableListOf<PcmEnvelope>()
        @Volatile private var envelopeMonitor: Thread? = null

        fun start() = thread.start()

        fun setVolume(value: Float) {
            currentVolume = value.coerceIn(0f, 2f)
            val currentTrack = track ?: return
            applyVolume(currentTrack, enhancer)
        }

        fun setSpeed(value: Float) {
            currentSpeed = value.coerceIn(0.5f, 2f)
            track?.let(::applyPlaybackParams)
        }

        fun setPitch(value: Float) {
            currentPitch = value.coerceIn(0.5f, 2f)
            track?.let(::applyPlaybackParams)
        }

        fun enqueue(bytes: ByteArray, wav: WavInfo, speed: Float) {
            check(!cancelled) { "TTS audio stream has stopped" }
            val isFirst = synchronized(this) {
                (!firstEnqueued).also { firstEnqueued = true }
            }
            queue.put(Command.Audio(bytes, wav, speed))
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
                                currentSpeed = command.speed
                                format = wav
                                val created = createTrack(wav)
                                localTrack = created
                                track = created
                                enhancer = runCatching {
                                    LoudnessEnhancer(created.audioSessionId)
                                }.getOrNull()
                                // Leave exact 1.0x speed / 1.0x pitch PCM
                                // untouched. PlaybackParams is opt-in for an
                                // explicit speed or independent pitch change.
                                if (currentSpeed != 1.0f || currentPitch != 1.0f) {
                                    applyPlaybackParams(created)
                                }
                                applyVolume(created, enhancer)
                            } else {
                                check(checkNotNull(format).samePcmFormat(wav)) {
                                    "TTS stream WAV format changed between segments"
                                }
                            }
                            val writer = checkNotNull(localTrack)
                            if (playbackStarted && command.speed != currentSpeed) {
                                // PlaybackParams affects the whole AudioTrack,
                                // including PCM already buffered. Drain the
                                // preceding semantic unit before changing it.
                                while (!cancelled &&
                                    playbackHeadFrames(writer) < framesWritten
                                ) {
                                    Thread.sleep(8L)
                                }
                                currentSpeed = command.speed
                                if (!cancelled) applyPlaybackParams(writer)
                            }
                            val bytesPerFrame = wav.bytesPerFrame
                            captureEnvelope(command.bytes, wav, framesWritten)
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
                                startEnvelopeMonitor()
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
                SenLive2DRuntime.setSpeechAmplitude(0f)
                envelopeMonitor?.interrupt()
                envelopeMonitor = null
                runCatching { enhancer?.release() }
                enhancer = null
                runCatching { localTrack?.release() }
                track = null
                completed.countDown()
            }
        }

        private fun startEnvelopeMonitor() {
            if (envelopeMonitor != null) return
            envelopeMonitor = Thread({
                var smoothed = 0f
                while (!cancelled && playbackStarted) {
                    val activeTrack = track ?: break
                    val frame = playbackHeadFrames(activeTrack)
                    val target = envelopeAt(frame)
                    smoothed = smoothed * .58f + target * .42f
                    SenLive2DRuntime.setSpeechAmplitude(smoothed)
                    try {
                        Thread.sleep(33L)
                    } catch (_: InterruptedException) {
                        break
                    }
                }
                SenLive2DRuntime.setSpeechAmplitude(0f)
            }, "Sen-Live2D-lip-envelope").apply {
                isDaemon = true
                start()
            }
        }

        private fun captureEnvelope(bytes: ByteArray, wav: WavInfo, startFrame: Long) {
            val frameCount = wav.dataSize / wav.bytesPerFrame
            if (frameCount <= 0) return
            val binCount = (frameCount + ENVELOPE_BIN_FRAMES - 1) / ENVELOPE_BIN_FRAMES
            val values = FloatArray(binCount)
            for (bin in 0 until binCount) {
                val first = bin * ENVELOPE_BIN_FRAMES
                val last = min(frameCount, first + ENVELOPE_BIN_FRAMES)
                var sumSquares = 0.0
                var samples = 0
                for (frame in first until last) {
                    for (channel in 0 until wav.channels) {
                        val offset = wav.dataOffset + frame * wav.bytesPerFrame +
                            channel * (wav.bitsPerSample / 8)
                        val normalized = if (wav.bitsPerSample == 16) {
                            val sample = (bytes[offset].toInt() and 0xff) or
                                (bytes[offset + 1].toInt() shl 8)
                            sample.toShort().toDouble() / 32768.0
                        } else {
                            ((bytes[offset].toInt() and 0xff) - 128).toDouble() / 128.0
                        }
                        sumSquares += normalized * normalized
                        samples++
                    }
                }
                val rms = if (samples == 0) 0.0 else sqrt(sumSquares / samples)
                values[bin] = (rms * 3.2).coerceIn(0.0, 1.0).toFloat()
            }
            synchronized(envelopeLock) {
                envelopes += PcmEnvelope(startFrame, frameCount, values)
                while (envelopes.size > 48) envelopes.removeAt(0)
            }
        }

        private fun envelopeAt(frame: Long): Float = synchronized(envelopeLock) {
            val envelope = envelopes.firstOrNull {
                frame >= it.startFrame && frame < it.startFrame + it.frameCount
            } ?: return@synchronized 0f
            val relative = (frame - envelope.startFrame).toInt()
            envelope.values[(relative / ENVELOPE_BIN_FRAMES).coerceIn(0, envelope.values.lastIndex)]
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

        private fun applyPlaybackParams(target: AudioTrack) {
            target.playbackParams = PlaybackParams()
                .setAudioFallbackMode(PlaybackParams.AUDIO_FALLBACK_MODE_DEFAULT)
                .setPitch(currentPitch)
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

    private data class PcmEnvelope(
        val startFrame: Long,
        val frameCount: Int,
        val values: FloatArray,
    )

    companion object {
        private const val ENVELOPE_BIN_FRAMES = 256
    }
}
