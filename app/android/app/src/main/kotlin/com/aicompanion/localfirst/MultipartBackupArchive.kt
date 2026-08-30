package com.aicompanion.localfirst

import android.content.ContentResolver
import android.net.Uri
import android.os.StatFs
import android.provider.DocumentsContract
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

data class BackupPartDescriptor(
    val name: String,
    val bytes: Long,
    val sha256: String,
)

internal class SplitPartOutputStream(
    private val partBytes: Long,
    private val openPart: (String) -> OutputStream,
) : OutputStream() {
    init {
        require(partBytes > 0L) { "backup_part_size_invalid" }
    }

    private var current: OutputStream? = null
    private var currentName = ""
    private var currentBytes = 0L
    private var digest = MessageDigest.getInstance("SHA-256")
    private var closed = false
    private var partIndex = 0
    val parts = mutableListOf<BackupPartDescriptor>()

    override fun write(value: Int) {
        val one = byteArrayOf(value.toByte())
        write(one, 0, 1)
    }

    override fun write(buffer: ByteArray, offset: Int, length: Int) {
        check(!closed) { "backup_split_stream_closed" }
        require(offset >= 0 && length >= 0 && offset + length <= buffer.size)
        var cursor = offset
        var remaining = length
        while (remaining > 0) {
            ensurePart()
            val writable = minOf(remaining.toLong(), partBytes - currentBytes).toInt()
            current!!.write(buffer, cursor, writable)
            digest.update(buffer, cursor, writable)
            currentBytes += writable
            cursor += writable
            remaining -= writable
            if (currentBytes == partBytes) closeCurrentPart()
        }
    }

    override fun flush() {
        current?.flush()
    }

    override fun close() {
        if (closed) return
        closed = true
        closeCurrentPart()
    }

    private fun ensurePart() {
        if (current != null) return
        partIndex += 1
        require(partIndex <= MultipartBackupArchive.MAX_PARTS) { "backup_too_many_parts" }
        currentName = String.format(Locale.US, "part-%04d.aibpart", partIndex)
        current = openPart(currentName)
        currentBytes = 0L
        digest = MessageDigest.getInstance("SHA-256")
    }

    private fun closeCurrentPart() {
        val output = current ?: return
        output.flush()
        output.close()
        parts += BackupPartDescriptor(
            name = currentName,
            bytes = currentBytes,
            sha256 = digest.digest().joinToString("") { "%02x".format(it) },
        )
        current = null
        currentName = ""
        currentBytes = 0L
    }
}

internal data class BackupInputPart(
    val descriptor: BackupPartDescriptor,
    val open: () -> InputStream,
)

internal class VerifiedPartInputStream(
    private val parts: List<BackupInputPart>,
) : InputStream() {
    private var index = -1
    private var current: InputStream? = null
    private var currentBytes = 0L
    private var digest = MessageDigest.getInstance("SHA-256")
    private var closed = false

    override fun read(): Int {
        val one = ByteArray(1)
        val count = read(one, 0, 1)
        return if (count < 0) -1 else one[0].toInt() and 0xff
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        check(!closed) { "backup_part_stream_closed" }
        if (length == 0) return 0
        while (true) {
            ensureCurrent() ?: return -1
            val count = current!!.read(buffer, offset, length)
            if (count > 0) {
                currentBytes += count
                if (currentBytes > parts[index].descriptor.bytes) {
                    throw IllegalStateException("backup_part_size_mismatch")
                }
                digest.update(buffer, offset, count)
                return count
            }
            finishCurrent()
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        current?.close()
        current = null
    }

    private fun ensureCurrent(): InputStream? {
        if (current != null) return current
        index += 1
        if (index >= parts.size) return null
        currentBytes = 0L
        digest = MessageDigest.getInstance("SHA-256")
        current = parts[index].open()
        return current
    }

    private fun finishCurrent() {
        current?.close()
        current = null
        val expected = parts[index].descriptor
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        if (currentBytes != expected.bytes || actual != expected.sha256) {
            throw IllegalStateException("backup_part_hash_mismatch")
        }
    }
}

object MultipartBackupArchive {
    const val DEFAULT_PART_BYTES = 192L * 1024L * 1024L
    const val MAX_PARTS = 256
    private const val MANIFEST_NAME = "backup_manifest.json"
    private const val FORMAT = "ai-companion-encrypted-backup-parts"
    private const val FORMAT_VERSION = 1
    private const val MAX_MANIFEST_BYTES = 1024 * 1024
    private const val MAX_SOURCE_ZIP_BYTES = 8L * 1024L * 1024L * 1024L
    private const val RESTORE_SPACE_RESERVE_BYTES = 256L * 1024L * 1024L

    fun export(
        resolver: ContentResolver,
        parentTreeUri: Uri,
        sourceZip: File,
        passphrase: CharArray,
        suggestedStem: String,
        partBytes: Long = DEFAULT_PART_BYTES,
    ): Map<String, Any?> {
        require(sourceZip.isFile) { "backup_source_missing" }
        require(partBytes in 1024L..DEFAULT_PART_BYTES) { "backup_part_size_invalid" }
        val parent = documentUri(parentTreeUri)
        val safeStem = suggestedStem
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(80)
            .ifBlank { "ai_companion_backup" }
        val directoryName = if (safeStem.endsWith(".aibackup")) safeStem else "$safeStem.aibackup"
        val directory = requireNotNull(
            DocumentsContract.createDocument(
                resolver,
                parent,
                DocumentsContract.Document.MIME_TYPE_DIR,
                directoryName,
            ),
        ) { "backup_directory_create_failed" }
        try {
            val split = SplitPartOutputStream(partBytes) { name ->
                val uri = requireNotNull(
                    DocumentsContract.createDocument(
                        resolver,
                        directory,
                        "application/octet-stream",
                        name,
                    ),
                ) { "backup_part_create_failed" }
                requireNotNull(resolver.openOutputStream(uri, "w")) { "backup_part_open_failed" }
            }
            ManualSnapshotCrypto.encrypt(sourceZip.inputStream(), split, passphrase)
            require(split.parts.isNotEmpty()) { "backup_parts_empty" }
            val manifest = buildManifest(split.parts, sourceZip.length())
            val manifestUri = requireNotNull(
                DocumentsContract.createDocument(
                    resolver,
                    directory,
                    "application/json",
                    MANIFEST_NAME,
                ),
            ) { "backup_manifest_create_failed" }
            resolver.openOutputStream(manifestUri, "w").use { output ->
                requireNotNull(output) { "backup_manifest_open_failed" }
                output.write(manifest.toString(2).toByteArray(Charsets.UTF_8))
            }
            return mapOf(
                "saved" to true,
                "directoryUri" to directory.toString(),
                "partCount" to split.parts.size,
                "encryptedBytes" to split.parts.sumOf { it.bytes },
                "sourceBytes" to sourceZip.length(),
            )
        } catch (error: Throwable) {
            runCatching { DocumentsContract.deleteDocument(resolver, directory) }
            throw error
        }
    }

    fun restore(
        resolver: ContentResolver,
        backupTreeUri: Uri,
        destinationZip: File,
        passphrase: CharArray,
    ): Map<String, Any?> {
        val directory = documentUri(backupTreeUri)
        val children = listChildren(resolver, backupTreeUri, directory)
        val manifestRef = children[MANIFEST_NAME] ?: error("backup_manifest_missing")
        val manifestBytes = resolver.openInputStream(manifestRef.uri).use { input ->
            requireNotNull(input) { "backup_manifest_open_failed" }
            readBounded(input, MAX_MANIFEST_BYTES)
        }
        val manifest = JSONObject(String(manifestBytes, Charsets.UTF_8))
        val descriptors = parseManifest(manifest)
        val sourceZipBytes = manifest.optLong("source_zip_bytes", -1L)
        require(sourceZipBytes in 1..MAX_SOURCE_ZIP_BYTES) { "backup_source_size_invalid" }
        destinationZip.parentFile?.mkdirs()
        val available = StatFs(destinationZip.parentFile!!.absolutePath).availableBytes
        val required = sourceZipBytes * 3L + RESTORE_SPACE_RESERVE_BYTES
        require(available >= required) {
            "backup_restore_space_insufficient:required=$required,available=$available"
        }
        val inputs = descriptors.map { descriptor ->
            val child = children[descriptor.name] ?: error("backup_part_missing")
            if (child.size >= 0L && child.size != descriptor.bytes) {
                error("backup_part_size_mismatch")
            }
            BackupInputPart(descriptor) {
                requireNotNull(resolver.openInputStream(child.uri)) { "backup_part_open_failed" }
            }
        }
        try {
            VerifiedPartInputStream(inputs).use { encrypted ->
                ManualSnapshotCrypto.decrypt(
                    encrypted,
                    FileOutputStream(destinationZip),
                    passphrase,
                )
            }
            require(destinationZip.length() == sourceZipBytes) {
                "backup_source_size_mismatch"
            }
            return mapOf(
                "filePath" to destinationZip.absolutePath,
                "partCount" to descriptors.size,
                "encryptedBytes" to descriptors.sumOf { it.bytes },
            )
        } catch (error: Throwable) {
            runCatching { destinationZip.delete() }
            throw error
        }
    }

    internal fun buildManifest(
        parts: List<BackupPartDescriptor>,
        sourceBytes: Long,
    ): JSONObject {
        require(parts.isNotEmpty() && parts.size <= MAX_PARTS) { "backup_part_count_invalid" }
        val array = JSONArray()
        parts.forEachIndexed { index, part ->
            require(part.name == String.format(Locale.US, "part-%04d.aibpart", index + 1)) {
                "backup_part_order_invalid"
            }
            require(part.bytes > 0L && part.bytes <= DEFAULT_PART_BYTES) { "backup_part_size_invalid" }
            require(part.sha256.matches(Regex("^[0-9a-f]{64}$"))) { "backup_part_hash_invalid" }
            array.put(
                JSONObject()
                    .put("index", index + 1)
                    .put("name", part.name)
                    .put("bytes", part.bytes)
                    .put("sha256", part.sha256),
            )
        }
        return JSONObject()
            .put("format", FORMAT)
            .put("format_version", FORMAT_VERSION)
            .put("archive_kind", "backup")
            .put("created_at", System.currentTimeMillis())
            .put("source_zip_bytes", sourceBytes)
            .put("encrypted_bytes", parts.sumOf { it.bytes })
            .put("part_bytes", DEFAULT_PART_BYTES)
            .put("parts", array)
    }

    internal fun parseManifest(manifest: JSONObject): List<BackupPartDescriptor> {
        require(manifest.optString("format") == FORMAT) { "backup_manifest_format_invalid" }
        require(manifest.optInt("format_version", 0) == FORMAT_VERSION) { "backup_manifest_version_invalid" }
        require(manifest.optString("archive_kind") == "backup") { "backup_manifest_kind_invalid" }
        val array = manifest.optJSONArray("parts") ?: error("backup_manifest_parts_missing")
        require(array.length() in 1..MAX_PARTS) { "backup_part_count_invalid" }
        val names = mutableSetOf<String>()
        val parts = ArrayList<BackupPartDescriptor>(array.length())
        for (index in 0 until array.length()) {
            val raw = array.getJSONObject(index)
            val expectedIndex = index + 1
            require(raw.optInt("index", 0) == expectedIndex) { "backup_part_order_invalid" }
            val expectedName = String.format(Locale.US, "part-%04d.aibpart", expectedIndex)
            val name = raw.optString("name")
            val bytes = raw.optLong("bytes", -1L)
            val sha256 = raw.optString("sha256")
            require(name == expectedName && names.add(name)) { "backup_part_name_invalid" }
            require(bytes > 0L && bytes <= DEFAULT_PART_BYTES) { "backup_part_size_invalid" }
            require(sha256.matches(Regex("^[0-9a-f]{64}$"))) { "backup_part_hash_invalid" }
            parts += BackupPartDescriptor(name, bytes, sha256)
        }
        require(manifest.optLong("encrypted_bytes", -1L) == parts.sumOf { it.bytes }) {
            "backup_encrypted_size_mismatch"
        }
        return parts
    }

    private data class ChildDocument(val uri: Uri, val size: Long)

    private fun documentUri(treeUri: Uri): Uri = DocumentsContract.buildDocumentUriUsingTree(
        treeUri,
        DocumentsContract.getTreeDocumentId(treeUri),
    )

    private fun listChildren(
        resolver: ContentResolver,
        treeUri: Uri,
        directory: Uri,
    ): Map<String, ChildDocument> {
        val directoryId = DocumentsContract.getDocumentId(directory)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, directoryId)
        val result = linkedMapOf<String, ChildDocument>()
        resolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE,
            ),
            null,
            null,
            null,
        ).use { cursor ->
            requireNotNull(cursor) { "backup_directory_query_failed" }
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val name = cursor.getString(1) ?: continue
                val size = if (cursor.isNull(2)) -1L else cursor.getLong(2)
                require(result.put(name, ChildDocument(
                    DocumentsContract.buildDocumentUriUsingTree(treeUri, id),
                    size,
                )) == null) { "backup_duplicate_child_name" }
            }
        }
        return result
    }

    private fun readBounded(input: InputStream, limit: Int): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            require(output.size() + count <= limit) { "backup_manifest_too_large" }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }
}
