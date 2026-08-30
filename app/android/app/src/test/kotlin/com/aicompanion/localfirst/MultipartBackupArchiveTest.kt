package com.aicompanion.localfirst

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.json.JSONObject

class MultipartBackupArchiveTest {
    @Test
    fun manualTakeoverAesGcmEnvelopeRoundTripsAcrossParts() {
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
    fun plainBackupManifestDeclaresNoProtectionAndRoundTrips() {
        val parts = listOf(
            BackupPartDescriptor(
                name = "part-0001.aibpart",
                bytes = 23L,
                sha256 = "a".repeat(64),
            ),
            BackupPartDescriptor(
                name = "part-0002.aibpart",
                bytes = 19L,
                sha256 = "b".repeat(64),
            ),
        )

        val manifest = MultipartBackupArchive.buildManifest(parts, sourceBytes = 42L)

        assertEquals("ai-companion-backup-parts", manifest.getString("format"))
        assertEquals(2, manifest.getInt("format_version"))
        assertEquals("none", manifest.getString("protection"))
        assertEquals(42L, manifest.getLong("archive_bytes"))
        assertEquals(parts, MultipartBackupArchive.parseManifest(manifest))
    }

    @Test
    fun encryptedOrLegacyManifestIsRejectedByPlainBackupImporter() {
        val parts = listOf(
            BackupPartDescriptor(
                name = "part-0001.aibpart",
                bytes = 1L,
                sha256 = "c".repeat(64),
            ),
        )
        val encrypted = MultipartBackupArchive.buildManifest(parts, sourceBytes = 1L)
            .put("protection", "aes-256-gcm")
        val legacy = JSONObject(MultipartBackupArchive.buildManifest(parts, sourceBytes = 1L).toString())
            .put("format", "ai-companion-encrypted-backup-parts")
            .put("format_version", 1)

        val encryptedError = assertThrows(IllegalArgumentException::class.java) {
            MultipartBackupArchive.parseManifest(encrypted)
        }
        val legacyError = assertThrows(IllegalArgumentException::class.java) {
            MultipartBackupArchive.parseManifest(legacy)
        }
        assertTrue(encryptedError.message.orEmpty().contains("protection"))
        assertTrue(legacyError.message.orEmpty().contains("format"))
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
