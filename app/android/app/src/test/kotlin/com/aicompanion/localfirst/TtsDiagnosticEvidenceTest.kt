package com.aicompanion.localfirst

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TtsDiagnosticEvidenceTest {
    @Test
    fun characterClassesAreCountsOnlyAndCoverMixedInput() {
        val evidence = TtsDiagnosticEvidence.characterClasses("中あアA7， \n🙂")

        assertEquals(
            "total=9;cjk=1;hiragana=1;katakana=1;latin=1;digits=1;punctuation=1;whitespace=2;other=1",
            evidence,
        )
        assertFalse(evidence.contains("中"))
        assertFalse(evidence.contains("A7"))
    }

    @Test
    fun wavEvidenceUsesOnlyPcmPayload() {
        val wav = wav(sampleRate = 1000, samples = shortArrayOf(1, 2, 3, 4, 5, 6))

        assertEquals(6L, TtsDiagnosticEvidence.wavDurationMs(wav))
        assertEquals(64, TtsDiagnosticEvidence.pcmPayloadHash(wav).length)
        assertEquals("", TtsDiagnosticEvidence.pcmPayloadHash(byteArrayOf(1, 2, 3)))
    }

    @Test
    fun echoSuspicionRequiresAllDegenerateInferenceSignals() {
        assertTrue(TtsDiagnosticEvidence.referenceEchoSuspected(1, 1, 500))
        assertFalse(TtsDiagnosticEvidence.referenceEchoSuspected(2, 1, 500))
        assertTrue(TtsDiagnosticEvidence.referenceEchoSuspected(1, 122, 500))
        assertFalse(TtsDiagnosticEvidence.referenceEchoSuspected(1, 1, 100))
    }

    private fun wav(sampleRate: Int, samples: ShortArray): ByteArray {
        val dataBytes = samples.size * 2
        val output = ByteBuffer.allocate(44 + dataBytes).order(ByteOrder.LITTLE_ENDIAN)
        output.put("RIFF".toByteArray(Charsets.US_ASCII))
        output.putInt(36 + dataBytes)
        output.put("WAVEfmt ".toByteArray(Charsets.US_ASCII))
        output.putInt(16)
        output.putShort(1.toShort())
        output.putShort(1.toShort())
        output.putInt(sampleRate)
        output.putInt(sampleRate * 2)
        output.putShort(2.toShort())
        output.putShort(16.toShort())
        output.put("data".toByteArray(Charsets.US_ASCII))
        output.putInt(dataBytes)
        samples.forEach { sample -> output.putShort(sample) }
        return output.array()
    }
}
