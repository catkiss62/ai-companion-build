package com.catkiss62.geniettsbenchmark

import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssetIntegrityPolicyTest {
    @Test
    fun correctLegacyFileIsHashedOnceAndMarkedReusable() {
        val directory = Files.createTempDirectory("genie-integrity").toFile()
        val output = directory.resolve("weight.bin").apply { writeBytes(byteArrayOf(1, 2, 3, 4)) }
        val marker = directory.resolve("weight.bin.sha256")
        val expected = AssetIntegrity(output.length(), AssetIntegrityPolicy.sha256(output))

        assertTrue(AssetIntegrityPolicy.canReuse(output, marker, expected))
        assertTrue(marker.readText() == expected.sha256)
    }

    @Test
    fun truncatedAndSameLengthWrongFilesAreRejected() {
        val directory = Files.createTempDirectory("genie-integrity").toFile()
        val good = directory.resolve("good.bin").apply { writeBytes(byteArrayOf(1, 2, 3, 4)) }
        val expected = AssetIntegrity(good.length(), AssetIntegrityPolicy.sha256(good))
        val marker = directory.resolve("candidate.bin.sha256")
        val candidate = directory.resolve("candidate.bin")

        candidate.writeBytes(byteArrayOf(1, 2))
        assertFalse(AssetIntegrityPolicy.canReuse(candidate, marker, expected))
        candidate.writeBytes(byteArrayOf(4, 3, 2, 1))
        assertFalse(AssetIntegrityPolicy.canReuse(candidate, marker, expected))
    }

    @Test(expected = IllegalStateException::class)
    fun incomingWrongShaFailsBeforeReplacement() {
        val directory = Files.createTempDirectory("genie-integrity").toFile()
        val incoming = directory.resolve("weight.bin.incoming").apply {
            writeBytes(byteArrayOf(4, 3, 2, 1))
        }
        AssetIntegrityPolicy.verifyIncoming(
            incoming,
            "models/weight.bin",
            AssetIntegrity(4, "00".repeat(32)),
        )
    }

    @Test
    fun verifiedIncomingAtomicallyReplacesOldFile() {
        val directory = Files.createTempDirectory("genie-integrity").toFile()
        val output = directory.resolve("weight.bin").apply { writeBytes(byteArrayOf(9)) }
        val replacement = byteArrayOf(1, 2, 3, 4)
        val incoming = directory.resolve("weight.bin.incoming").apply { writeBytes(replacement) }
        val expected = AssetIntegrity(incoming.length(), AssetIntegrityPolicy.sha256(incoming))

        AssetIntegrityPolicy.verifyIncoming(incoming, "models/weight.bin", expected)
        AssetIntegrityPolicy.replaceIncoming(incoming, output)

        assertArrayEquals(replacement, output.readBytes())
        assertFalse(incoming.exists())
    }
}
