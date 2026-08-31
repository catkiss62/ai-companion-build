package com.aicompanion.localfirst

import java.io.File
import java.io.FileOutputStream
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PortableBackupZipVerifierTest {
    @Test
    fun filesOnlyBackupIsReadAndCrcChecked() = withTempDirectory { directory ->
        val archive = File(directory, "valid.aibackup")
        writeZip(
            archive,
            listOf(
                Entry("state.json", "{\"tables\":{}}".toByteArray()),
                Entry("manifest.json", "{\"format\":\"test\"}".toByteArray()),
                Entry("attachments/originals/example.jpg", byteArrayOf(1, 2, 3, 4)),
            ),
        )

        val summary = PortableBackupZipVerifier.verify(archive)

        assertEquals(3, summary.entryCount)
        assertEquals(34L, summary.expandedBytes)
    }

    @Test
    fun directoryEntriesAreRejectedEvenWhenTheirZipEncodingIsValid() =
        withTempDirectory { directory ->
            val archive = File(directory, "directory.aibackup")
            writeZip(
                archive,
                listOf(
                    Entry("state.json", "{}".toByteArray()),
                    Entry("manifest.json", "{}".toByteArray()),
                    Entry("attachments/originals/", byteArrayOf(), directory = true),
                ),
            )

            assertThrows(IllegalArgumentException::class.java) {
                PortableBackupZipVerifier.verify(archive)
            }
        }

    @Test
    fun unsafeUnexpectedAndMissingEntriesAreRejected() = withTempDirectory { directory ->
        val unsafe = File(directory, "unsafe.aibackup")
        writeZip(
            unsafe,
            listOf(
                Entry("state.json", "{}".toByteArray()),
                Entry("manifest.json", "{}".toByteArray()),
                Entry("attachments/../escape.jpg", byteArrayOf(1)),
            ),
        )
        assertThrows(IllegalArgumentException::class.java) {
            PortableBackupZipVerifier.verify(unsafe)
        }

        val unexpected = File(directory, "unexpected.aibackup")
        writeZip(
            unexpected,
            listOf(
                Entry("state.json", "{}".toByteArray()),
                Entry("manifest.json", "{}".toByteArray()),
                Entry("notes.txt", byteArrayOf(1)),
            ),
        )
        assertThrows(IllegalArgumentException::class.java) {
            PortableBackupZipVerifier.verify(unexpected)
        }

        val missing = File(directory, "missing.aibackup")
        writeZip(missing, listOf(Entry("manifest.json", "{}".toByteArray())))
        assertThrows(IllegalArgumentException::class.java) {
            PortableBackupZipVerifier.verify(missing)
        }
    }

    @Test
    fun storedEntryCrcTamperingIsRejected() = withTempDirectory { directory ->
        val archive = File(directory, "tampered.aibackup")
        val state = "unique-state-payload-0413".toByteArray()
        writeZip(
            archive,
            listOf(
                Entry("state.json", state, stored = true),
                Entry("manifest.json", "{}".toByteArray()),
            ),
        )
        val bytes = archive.readBytes()
        val index = bytes.indexOfSlice(state)
        check(index >= 0)
        bytes[index + 7] = (bytes[index + 7].toInt() xor 0x5a).toByte()
        archive.writeBytes(bytes)

        assertThrows(Throwable::class.java) {
            PortableBackupZipVerifier.verify(archive)
        }
    }

    private data class Entry(
        val name: String,
        val bytes: ByteArray,
        val directory: Boolean = false,
        val stored: Boolean = false,
    )

    private fun writeZip(file: File, entries: List<Entry>) {
        ZipOutputStream(FileOutputStream(file)).use { output ->
            for (item in entries) {
                val entry = ZipEntry(item.name)
                if (item.stored) {
                    val crc = CRC32().apply { update(item.bytes) }
                    entry.method = ZipEntry.STORED
                    entry.size = item.bytes.size.toLong()
                    entry.compressedSize = item.bytes.size.toLong()
                    entry.crc = crc.value
                }
                output.putNextEntry(entry)
                if (!item.directory) output.write(item.bytes)
                output.closeEntry()
            }
        }
    }

    private fun ByteArray.indexOfSlice(needle: ByteArray): Int {
        if (needle.isEmpty() || needle.size > size) return -1
        for (start in 0..size - needle.size) {
            var matches = true
            for (offset in needle.indices) {
                if (this[start + offset] != needle[offset]) {
                    matches = false
                    break
                }
            }
            if (matches) return start
        }
        return -1
    }

    private fun withTempDirectory(block: (File) -> Unit) {
        val directory = kotlin.io.path.createTempDirectory("backup_zip_test_").toFile()
        try {
            block(directory)
        } finally {
            directory.deleteRecursively()
        }
    }
}
