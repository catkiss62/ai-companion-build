package com.aicompanion.localfirst

import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import com.catkiss.senlive2dcompanion.CaicaiRuntime
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

/** Envelope indexed by the actual AudioTrack playback head, including speed changes.
 * No second player, resampling, or changes to the PCM sent to the speaker. */
internal class CaicaiPcmLipSync {
    private data class Block(val start: Long, val end: Long, val value: Float)
    private val blocks = ArrayDeque<Block>()
    private val handler = Handler(Looper.getMainLooper())
    @Volatile private var stopped = false
    private var target: AudioTrack? = null
    private val tick = object : Runnable {
        override fun run() {
            if (stopped) return
            val track = target ?: return
            val playing = runCatching { track.playState == AudioTrack.PLAYSTATE_PLAYING }.getOrDefault(false)
            val head = runCatching { track.playbackHeadPosition.toLong() and 0xffff_ffffL }.getOrDefault(0L)
            val value = synchronized(blocks) {
                while (blocks.isNotEmpty() && blocks.first().end <= head) blocks.removeFirst()
                blocks.firstOrNull()?.takeIf { head >= it.start && playing }?.value ?: 0f
            }
            CaicaiRuntime.speechAmplitude(value)
            handler.postDelayed(this, 40L)
        }
    }
    fun append(bytes: ByteArray, offset: Int, count: Int, sampleRate: Int, channels: Int, bits: Int, format: Int, startFrame: Long) {
        if (!CaicaiRuntime.hasActiveView() || stopped) return
        val bytesPerSample = bits / 8
        if (!(format == 1 && bits == 16 || format == 3 && bits == 32)) return
        val frameBytes = channels * bytesPerSample
        val step = (sampleRate / 25).coerceAtLeast(1)
        val frames = count / frameBytes
        val pcm = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val pending = ArrayList<Block>()
        var frame = 0
        while (frame < frames) {
            val end = (frame + step).coerceAtMost(frames)
            var sum = 0.0
            var n = 0
            // Sample every fourth PCM frame; envelope analysis is display-only.
            var at = frame
            while (at < end) {
                val index = offset + at * frameBytes
                val value = if (format == 3) pcm.getFloat(index).toDouble() else pcm.getShort(index) / 32768.0
                if (value.isFinite()) { sum += value * value; n++ }
                at += 4
            }
            val rms = if (n == 0) 0f else sqrt(sum / n).toFloat()
            pending.add(Block(startFrame + frame, startFrame + end, (rms * 6f).coerceIn(0f, 1f)))
            frame = end
        }
        synchronized(blocks) { blocks.addAll(pending) }
    }
    fun start(track: AudioTrack) {
        if (stopped || !CaicaiRuntime.hasActiveView()) return
        target = track
        handler.post(tick)
    }
    fun stop() {
        stopped = true
        handler.removeCallbacks(tick)
        synchronized(blocks) { blocks.clear() }
        handler.post { CaicaiRuntime.speechAmplitude(0f) }
    }
}
