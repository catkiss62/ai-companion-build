package com.aicompanion.localfirst

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class VoiceExportPcmTuningTest {
    private fun wav(rate: Int = 24000, frequencies: List<Double> = listOf(600.0), seconds: Double = 2.0): ByteArray {
        val channels = frequencies.size
        val frames = (rate * seconds).roundToInt()
        val out = ByteBuffer.allocate(44 + frames * channels * 2).order(ByteOrder.LITTLE_ENDIAN)
        out.put("RIFF".toByteArray()).putInt(out.capacity() - 8).put("WAVEfmt ".toByteArray()).putInt(16)
        out.putShort(1).putShort(channels.toShort()).putInt(rate).putInt(rate * channels * 2)
        out.putShort((channels * 2).toShort()).putShort(16).put("data".toByteArray()).putInt(frames * channels * 2)
        repeat(frames) { frame ->
            frequencies.forEach { frequency ->
                out.putShort((sin(2 * PI * frequency * frame / rate) * 12000).roundToInt().toShort())
            }
        }
        return out.array()
    }

    private fun frequency(wav: ByteArray, channel: Int = 0): Double {
        val data = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
        val channels = data.getShort(22).toInt()
        val rate = data.getInt(24)
        val frames = (wav.size - 44) / (channels * 2)
        val first = rate / 3
        val last = frames - rate / 3
        var crossings = 0
        for (frame in first + 1 until last) {
            val previous = data.getShort(44 + ((frame - 1) * channels + channel) * 2).toInt()
            val sample = data.getShort(44 + (frame * channels + channel) * 2).toInt()
            if (previous <= 0 && sample > 0) crossings++
        }
        return crossings.toDouble() * rate / (last - first - 1)
    }

    @Test fun lowersOneSemitoneWithoutChangingTempoOrSampleRate() {
        val input = wav()
        val ratio = 2.0.pow(-1.0 / 12.0)
        val output = VoiceExportPcmTuning.apply(input, ratio)
        assertEquals(600 * ratio, frequency(output), 2.0)
        assertTrue(abs(output.size - input.size) < 24000 * 2 * 0.04)
        val header = ByteBuffer.wrap(output).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(24000, header.getInt(24))
        assertEquals(output.size - 8, header.getInt(4))
        assertEquals(output.size - 44, header.getInt(40))
        assertArrayEquals(input.copyOfRange(8, 40), output.copyOfRange(8, 40))
    }

    @Test fun preservesBothStereoChannelsAtFortyEightKhz() {
        val ratio = 2.0.pow(-1.0 / 12.0)
        val input = wav(48000, listOf(440.0, 880.0))
        val output = VoiceExportPcmTuning.apply(input, ratio)
        assertEquals(440 * ratio, frequency(output, 0), 3.0)
        assertEquals(880 * ratio, frequency(output, 1), 3.0)
        assertTrue(abs(output.size - input.size) < 48000 * 4 * 0.04)
    }

    @Test fun supportsSavedSliderExtremesAndBothPitchDirections() {
        for (semitones in listOf(-5.0, 3.0)) {
            val ratio = 2.0.pow(semitones / 12.0)
            val output = VoiceExportPcmTuning.apply(wav(), ratio)
            assertEquals(600 * ratio, frequency(output), 3.0)
        }
    }

    @Test fun unityPitchIsAnExactPcmPassThrough() {
        val input = wav()
        assertSame(input, VoiceExportPcmTuning.apply(input, 1.0))
    }

    @Test fun silenceAndVeryShortSpeechStayValidPcm() {
        for (seconds in listOf(0.001, 0.05, 0.25)) {
            val input = wav(seconds = seconds).also { it.fill(0, 44) }
            val output = VoiceExportPcmTuning.apply(input, 2.0.pow(-1.0 / 12.0))
            assertTrue(output.size > 44)
            assertEquals(0, (output.size - 44) % 2)
            assertTrue(output.drop(44).all { it == 0.toByte() })
        }
    }

    @Test fun rejectsMalformedHeadersUnsupportedPcmAndNonFinitePitch() {
        val bad = listOf(
            ByteArray(1), wav().copyOf(47),
            wav().also { ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putShort(20, 3) },
            wav().also { ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putInt(24, -1) },
            wav().also { it[36] = 0 }
        )
        bad.forEach { assertThrows(IllegalArgumentException::class.java) { VoiceExportPcmTuning.apply(it, 0.94) } }
        for (pitch in listOf(Double.NaN, Double.POSITIVE_INFINITY, 0.0, 3.0)) {
            assertThrows(IllegalArgumentException::class.java) { VoiceExportPcmTuning.apply(wav(), pitch) }
        }
    }

    @Test fun cancellationInterruptsProcessingBeforePublication() {
        var checks = 0
        val error = assertThrows(IllegalStateException::class.java) {
            VoiceExportPcmTuning.apply(wav(seconds = 5.0), 0.94) { ++checks >= 4 }
        }
        assertEquals("voice_export_preempted", error.message)
        assertTrue(checks >= 4)
    }
}
