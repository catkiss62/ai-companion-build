package com.aicompanion.localfirst

import android.annotation.TargetApi
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import java.io.ByteArrayOutputStream

@TargetApi(29)
internal class DownloadWorkspace(private val resolver: ContentResolver, private val owner: String) {
    companion object {
        const val KEY = "workspace:downloads"
        private const val LIMIT = 256 * 1024
    }

    private val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    private val path = Environment.DIRECTORY_DOWNLOADS + "/小鲸鱼工作区/"

    private fun rows(name: String?): Map<String, Uri> {
        val args = mutableListOf(path)
        val clauses = mutableListOf("${MediaStore.MediaColumns.RELATIVE_PATH} = ?", "${MediaStore.MediaColumns.IS_PENDING} = 0")
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            clauses.add("${MediaStore.MediaColumns.OWNER_PACKAGE_NAME} = ?")
            args.add(owner)
        }
        if (name != null) {
            clauses.add("${MediaStore.MediaColumns.DISPLAY_NAME} = ?")
            args.add(name)
        }
        val result = mutableMapOf<String, Uri>()
        val cursor = resolver.query(collection, arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME),
            clauses.joinToString(" AND "), args.toTypedArray(), null) ?: error("无法读取下载工作区")
        cursor.use {
            while (it.moveToNext()) result[it.getString(1)] = ContentUris.withAppendedId(collection, it.getLong(0))
        }
        return result
    }

    private fun read(uri: Uri): ByteArray {
        return resolver.openInputStream(uri)?.use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                require(out.size() + n <= LIMIT) { "工作文件超过 256 KiB" }
                out.write(buffer, 0, n)
            }
            out.toByteArray()
        } ?: error("无法读取工作文件")
    }

    private fun write(uri: Uri, bytes: ByteArray) {
        val stream = resolver.openOutputStream(uri, "wt") ?: error("无法写入工作文件")
        stream.use { it.write(bytes) }
    }

    private fun create(name: String, bytes: ByteArray) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.RELATIVE_PATH, path)
            put(MediaStore.MediaColumns.MIME_TYPE, when {
                name.endsWith(".html") -> "text/html"
                name.endsWith(".json") -> "application/json"
                else -> "text/markdown"
            })
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: error("无法在下载目录创建工作文件")
        try {
            val actual = resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
            check(actual == name) { "下载目录存在同名文件，或系统更改了文件名" }
            write(uri, bytes)
            check(resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null) == 1) { "工作文件未能保存到下载目录" }
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    fun handle(method: String, name: String?, text: String?): Any? {
        if (method == "workTreeList") return rows(null).keys.toList()
        requireNotNull(name)
        val uri = rows(name)[name]
        when (method) {
            "workTreeRead" -> return read(requireNotNull(uri) { "工作文件已移动或删除" }).toString(Charsets.UTF_8)
            "workTreeWrite" -> {
                val bytes = requireNotNull(text).toByteArray(Charsets.UTF_8)
                require(bytes.size <= LIMIT) { "工作文件超过 256 KiB" }
                if (uri == null) create(name, bytes) else {
                    val original = read(uri)
                    if (!original.contentEquals(bytes)) {
                        try { write(uri, bytes) } catch (e: Exception) {
                            write(uri, original)
                            throw e
                        }
                    }
                }
            }
            "workTreeDelete" -> check(uri != null && resolver.delete(uri, null, null) == 1) { "工作文件已移动或无法删除" }
            else -> error("未知的工作区操作")
        }
        return null
    }
}
