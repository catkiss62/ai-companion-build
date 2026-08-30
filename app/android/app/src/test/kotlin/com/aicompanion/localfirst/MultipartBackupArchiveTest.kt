package com.aicompanion.localfirst

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class MultipartBackupArchiveTest {
    @Test
    fun aesGcmEnvelopeRoundTripsAcrossEncryptedParts() {
        val source = ByteArray(257) { index -> (index * 11).toByte() }
        val outputs = linkedMapOf<String, ByteArrayOutputStream>()
        val split = SplitPartOutputStream(48) { name ->
            ByteArrayOutputStream().also { outputs[name] = it }
        }
        ManualSnapshotCrypto.encrypt(
            ByteArrayInputStream(source),
            split,
            "correct horse battery".toCharArray(),
        )
        val verified = VerifiedPartInputStream(
            split.parts.map { descriptor ->
                BackupInputPart(descriptor) {
                    ByteArrayInputStream(outputs.getValue(descriptor.name).toByteArray())
                }
            },
        )
        val restored = ByteArrayOutputStream()

        ManualSnapshotCrypto.decrypt(
            verified,
            restored,
            "correct horse battery".toCharArray(),
        )

        assertArrayEquals(source, restored.toByteArray())
    }

    @Test
    fun splitAndVerifiedStreamsRoundTripAcrossBoundaries() {
        val source = ByteArray(49) { index -> (index * 7).toByte() }
        val outputs = linkedMapOf<String, ByteArrayOutputStream>()
        val split = SplitPartOutputStream(16) { name ->
            ByteArrayOutputStream().also { outputs[name] = it }
        }

        split.use { it.write(source) }

        assertEquals(listOf(16L, 16L, 16L, 1L), split.parts.map { it.bytes })
        val verified = VerifiedPartInputStream(
            split.parts.map { descriptor ->
                BackupInputPart(descriptor) {
                    ByteArrayInputStream(outputs.getValue(descriptor.name).toByteArray())
                }
            },
        )
        assertArrayEquals(source, verified.use { it.readBytes() })
    }

    @Test
    fun exactBoundaryDoesNotCreateEmptyTrailingPart() {
        val outputs = linkedMapOf<String, ByteArrayOutputStream>()
        val split = SplitPartOutputStream(8) { name ->
            ByteArrayOutputStream().also { outputs[name] = it }
        }
        split.use { it.write(ByteArray(16) { 1 }) }
        assertEquals(2, split.parts.size)
        assertEquals(listOf(8L, 8L), split.parts.map { it.bytes })
    }

    @Test
    fun tamperedPartIsRejectedBeforeEndOfStream() {
        val outputs = linkedMapOf<String, ByteArrayOutputStream>()
        val split = SplitPartOutputStream(8) { name ->
            ByteArrayOutputStream().also { outputs[name] = it }
        }
        split.use { it.write(ByteArray(18) { index -> index.toByte() }) }
        val tampered = outputs.mapValues { it.value.toByteArray() }.toMutableMap()
        tampered.getValue(split.parts[1].name)[2] = 99
        val verified = VerifiedPartInputStream(
            split.parts.map { descriptor ->
                BackupInputPart(descriptor) {
                    ByteArrayInputStream(tampered.getValue(descriptor.name))
                }
            },
        )
        assertThrows(IllegalStateException::class.java) { verified.use { it.readBytes() } }
    }
}
