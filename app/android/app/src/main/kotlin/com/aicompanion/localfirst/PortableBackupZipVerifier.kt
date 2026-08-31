package com.aicompanion.localfirst

import java.io.File
import java.util.zip.CRC32
import java.util.zip.ZipFile

/**
 * Independent portability check for newly exported plaintext backup ZIPs.
 *
 * SnapshotService performs the semantic manifest/state/file validation in
 * Dart. This verifier deliberately uses the JDK ZIP implementation so a ZIP
 * cannot be declared healthy only because the encoder and decoder share the
 * same tolerance for malformed entries.
 */
object PortableBackupZipVerifier {
    data class Summary(
        val entryCount: Int,
        val expandedBytes: Long,
    )

    private const val MAX_ARCHIVE_BYTES = 8L * 1024L * 1024L * 1024L
    private const val MAX_STATE_BYTES = 480L * 1024L * 1024L
    private const val MAX_MANIFEST_BYTES = 1L * 1024L * 1024L
    private const val MAX_EXPANDED_BYTES = 9L * 1024L * 1024L * 1024L
    private const val MAX_ENTRY_COUNT = 200_000

    fun verify(file: File): Summary {
        require(file.isFile && file.length() in 1..MAX_ARCHIVE_BYTES) {
            "portable_backup_source_invalid"
        }
        val seen = hashSetOf<String>()
        var entryCount = 0
        var expandedBytes = 0L
        var stateBytes = -1L
        var manifestBytes = -1L

        ZipFile(file).use { zip ->
            val entries = zip.entries()
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                entryCount += 1
                require(entryCount <= MAX_ENTRY_COUNT) {
                    "portable_backup_too_many_entries"
                }
                val name = entry.name
                require(!entry.isDirectory && !name.endsWith('/')) {
                    "portable_backup_directory_entry:$name"
                }
                require(isSafeFileName(name)) { "portable_backup_unsafe_entry:$name" }
                require(isAllowedFileName(name)) {
                    "portable_backup_unexpected_entry:$name"
                }
                require(seen.add(name)) { "portable_backup_duplicate_entry:$name" }

                val declaredSize = entry.size
                val declaredCrc = entry.crc
                require(declaredSize >= 0L && declaredCrc >= 0L) {
                    "portable_backup_entry_metadata_invalid:$name"
                }
                require(declaredSize <= MAX_ARCHIVE_BYTES) {
                    "portable_backup_entry_too_large:$name"
                }
                expandedBytes = safeAdd(expandedBytes, declaredSize)
                require(expandedBytes <= MAX_EXPANDED_BYTES) {
                    "portable_backup_expanded_too_large"
                }

                val crc = CRC32()
                var actualSize = 0L
                zip.getInputStream(entry).use { input ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        actualSize = safeAdd(actualSize, count.toLong())
                        require(actualSize <= declaredSize && actualSize <= MAX_ARCHIVE_BYTES) {
                            "portable_backup_entry_size_overflow:$name"
                        }
                        crc.update(buffer, 0, count)
                    }
                }
                require(actualSize == declaredSize) {
                    "portable_backup_entry_size_mismatch:$name"
                }
                require(crc.value == declaredCrc) {
                    "portable_backup_entry_crc_mismatch:$name"
                }
                when (name) {
                    "state.json" -> stateBytes = actualSize
                    "manifest.json" -> manifestBytes = actualSize
                }
            }
        }

        require(stateBytes in 1..MAX_STATE_BYTES) { "portable_backup_state_missing_or_invalid" }
        require(manifestBytes in 1..MAX_MANIFEST_BYTES) {
            "portable_backup_manifest_missing_or_invalid"
        }
        return Summary(entryCount = entryCount, expandedBytes = expandedBytes)
    }

    private fun isAllowedFileName(name: String): Boolean =
        name == "state.json" ||
            name == "manifest.json" ||
            name.startsWith("attachments/") ||
            name.startsWith("album/")

    private fun isSafeFileName(name: String): Boolean {
        if (name.isEmpty() || name.startsWith('/') || '\\' in name) return false
        val segments = name.split('/')
        return segments.none { it.isEmpty() || it == "." || it == ".." }
    }

    private fun safeAdd(left: Long, right: Long): Long {
        require(right >= 0L && left <= Long.MAX_VALUE - right) {
            "portable_backup_size_overflow"
        }
        return left + right
    }
}
