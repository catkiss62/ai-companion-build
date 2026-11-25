package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
import android.system.Os
import android.system.OsConstants
import android.net.Uri
import android.provider.DocumentsContract
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** A captured tree URI keeps an in-flight job in its original workspace. */
internal class CommissionDocuments(private val activity: Activity) {
    private val prefs = activity.getSharedPreferences("commission_documents", 0)
    private val resolver = activity.contentResolver
    private val executor = Executors.newSingleThreadExecutor()
    private var picker: MethodChannel.Result? = null
    // A grant is scoped to the current UI session. Never accept an arbitrary URI from a task file.
    @Volatile private var reference: Pair<String, Uri>? = null
    private fun displayName(uri: Uri): String =
        resolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }?.take(180) ?: "文本文件"

    private fun readReference(uri: Uri): Map<String, String> {
        val bytes = resolver.openInputStream(uri)?.use { input ->
            val out = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                require(out.size() + n <= 65536) { "文件超过 64 KiB，请选择较小的文本文件" }
                out.write(buffer, 0, n)
            }
            out.toByteArray()
        } ?: error("无法打开所选文件")
        val text = Charsets.UTF_8.newDecoder().decode(java.nio.ByteBuffer.wrap(bytes)).toString().removePrefix("\uFEFF")
        require(text.none { it < ' ' && it !in "\t\r\n" }) { "请选择 UTF-8 文本文件" }
        return mapOf("name" to displayName(uri), "text" to text)
    }
    // Require a seekable regular descriptor before touching bytes. Some SAF
    // providers only support a destructive "wt" stream; keep those read-only.
    private fun applyReference(selected: Pair<String, Uri>, expected: String, text: String) {
        val replacement = text.toByteArray(Charsets.UTF_8)
        require(replacement.size <= 65536 && text.none { it < ' ' && it !in "\t\r\n" }) { "修改稿不符合文本要求" }
        val doc = resolver.openFileDescriptor(selected.second, "rw") ?: error("文件不支持写回")
        doc.use {
            val fd = it.fileDescriptor
            fun readBytes(): ByteArray {
                val stat = Os.fstat(fd)
                require(OsConstants.S_ISREG(stat.st_mode) && stat.st_size in 0L..65536L) { "仅支持可定位且不超过 64 KiB 的文本文件" }
                val bytes = ByteArray(stat.st_size.toInt())
                var offset = 0
                while (offset < bytes.size) {
                    val count = Os.pread(fd, bytes, offset, bytes.size - offset, offset.toLong())
                    check(count > 0) { "读取期间文件已变化" }
                    offset += count
                }
                return bytes
            }
            fun writeBytes(bytes: ByteArray) {
                var offset = 0
                while (offset < bytes.size) {
                    val count = Os.pwrite(fd, bytes, offset, bytes.size - offset, offset.toLong())
                    check(count > 0) { "文件写入中断" }
                    offset += count
                }
                Os.ftruncate(fd, bytes.size.toLong())
                Os.fsync(fd)
            }
            val original = readBytes()
            val bom = byteArrayOf(0xef.toByte(), 0xbb.toByte(), 0xbf.toByte())
            val hasBom = original.size >= 3 && bom.indices.all { i -> original[i] == bom[i] }
            val payload = if (hasBom) original.copyOfRange(3, original.size) else original
            val digest = java.security.MessageDigest.getInstance("SHA-256").digest(payload)
                .joinToString("") { byte -> "%02x".format(byte) }
            require(digest == expected && reference == selected) { "文件或引用已变化，请重新读取后生成修改稿" }
            val output = if (hasBom) bom + replacement else replacement
            require(output.size <= 65536) { "文件超过 64 KiB" }
            if (output.contentEquals(original)) return
            try {
                writeBytes(output)
                check(readBytes().contentEquals(output))
            } catch (e: Exception) {
                try {
                    writeBytes(original)
                    check(readBytes().contentEquals(original))
                } catch (rollback: Exception) {
                    throw IllegalStateException("写回中断，无法核实原文已恢复，请检查文件", rollback)
                }
                throw IllegalStateException("写回失败，已恢复并核对原文", e)
            }
        }
        check(readReference(selected.second)["text"] == text) { "无法核实提供方保存的最终内容，请检查文件" }
    }

    private val namePattern = Regex("""(任务-[a-f0-9-]{36}\.json|(?:报告|技能|停用技能)-[\u3400-\u9fffA-Za-z0-9 _-]{1,75}\.md)""")
    private val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    fun result(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != 4281 && code != 4282) return false
        val pending = picker ?: return true
        picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { pending.success(null); return true }
        try {
            if (code == 4282) {
                require(uri.scheme == "content")
                val key = java.util.UUID.randomUUID().toString()
                val name = displayName(uri)
                reference = key to uri
                pending.success(mapOf("key" to key, "name" to name))
                return true
            }
            resolver.takePersistableUriPermission(uri, flags)
            prefs.edit().putString("tree", uri.toString()).apply()
            pending.success(null)
        } catch (e: Exception) { pending.error("tree_access", e.message, null) }
        return true
    }

    private fun files(tree: Uri): Map<String,Uri> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val rows = mutableMapOf<String,Uri>()
        val cursor = resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE), null,null,null)
            ?: error("无法读取工作目录")
        cursor.use {
            while (it.moveToNext()) {
                val name = it.getString(1) ?: continue
                if (namePattern.matches(name) && it.getString(2) != DocumentsContract.Document.MIME_TYPE_DIR)
                    rows[name] = DocumentsContract.buildDocumentUriUsingTree(tree,it.getString(0))
            }
        }
        return rows
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "workTreeCurrent" -> result.success(prefs.getString("tree",null))
            "workTreeDefault" -> { prefs.edit().remove("tree").apply(); result.success(null) }
            "workReferenceForget" -> {
                if (reference?.first == call.argument<String>("key")) reference = null
                result.success(null)
            }
            "workReferenceApply" -> {
                val selected = reference
                val expected = call.argument<String>("expected")
                val text = call.argument<String>("text")
                if (selected == null || selected.first != call.argument<String>("key") || expected == null || text == null) {
                    result.error("unavailable", "修改稿或文件引用已失效", null)
                    return
                }
                executor.execute {
                    try {
                        applyReference(selected, expected, text)
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    } catch (e: Exception) {
                        val message = when (e) {
                            is SecurityException, is java.io.FileNotFoundException -> "文件只读、已删除或写入授权已撤销"
                            is IllegalArgumentException, is IllegalStateException -> e.message ?: "文件写回失败"
                            else -> "文件提供方不支持本次写回，请检查文件"
                        }
                        Handler(Looper.getMainLooper()).post { result.error("reference_write", message, null) }
                    }
                }
            }
            "workReferenceRead" -> {
                val selected = reference
                if (selected == null || selected.first != call.argument<String>("key")) {
                    result.error("unavailable", "文件引用已失效，请重新选择", null)
                    return
                }
                executor.execute {
                    try {
                        val value = readReference(selected.second)
                        Handler(Looper.getMainLooper()).post { result.success(value) }
                    } catch (e: Exception) {
                        val message = when (e) {
                            is java.nio.charset.CharacterCodingException -> "请选择 UTF-8 文本文件"
                            is IllegalArgumentException -> e.message ?: "不支持此文件"
                            else -> "无法读取引用，文件可能已删除或授权已撤销"
                        }
                        Handler(Looper.getMainLooper()).post { result.error("reference_read", message, null) }
                    }
                }
            }
            "workReferenceChoose" -> {
                if (picker != null) { result.error("busy", "文件选择器已打开", null); return }
                picker = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*").putExtra(Intent.EXTRA_MIME_TYPES,
                        arrayOf("text/*", "application/json", "application/octet-stream"))
                    .addFlags(flags)
                try { activity.startActivityForResult(intent, 4282) }
                catch (e: Exception) { picker = null; result.error("picker", "无法打开文件选择器", null) }
            }
            "workTreeChoose" -> {
                if (picker != null) { result.error("busy","目录选择器已打开",null); return }
                picker = result
                try { activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(flags or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION),4281) }
                catch (e: Exception) { picker=null; result.error("picker",e.message,null) }
            }
            else -> executor.execute {
                try {
                    val tree = Uri.parse(requireNotNull(call.argument<String>("tree")))
                    val rows = files(tree)
                    val value: Any? = if (call.method == "workTreeList") rows.keys.toList() else {
                        val name = requireNotNull(call.argument<String>("name"))
                        require(namePattern.matches(name))
                        val uri = rows[name]
                        when (call.method) {
                            "workTreeRead" -> resolver.openInputStream(requireNotNull(uri))!!.use { input ->
                                val out = java.io.ByteArrayOutputStream()
                                val b = ByteArray(8192)
                                while (true) { val n=input.read(b); if(n<0)break; require(out.size()+n<=262144); out.write(b,0,n) }
                                out.toString("UTF-8")
                            }
                            "workTreeWrite" -> {
                                val bytes=requireNotNull(call.argument<String>("text")).toByteArray(Charsets.UTF_8)
                                require(bytes.size<=262144)
                                val dest=uri ?: DocumentsContract.createDocument(resolver,DocumentsContract.buildDocumentUriUsingTree(tree,DocumentsContract.getTreeDocumentId(tree)),
                                    if(name.endsWith(".md")) "text/markdown" else "application/json",name) ?: error("创建失败")
                                resolver.openOutputStream(dest,"wt")!!.use { it.write(bytes) }
                                null
                            }
                            "workTreeDelete" -> { check(DocumentsContract.deleteDocument(resolver,requireNotNull(uri))); null }
                            else -> error("unknown workspace operation")
                        }
                    }
                    Handler(Looper.getMainLooper()).post { result.success(value) }
                } catch(e: Exception) { Handler(Looper.getMainLooper()).post { result.error("workspace_io",e.message,null) } }
            }
        }
    }
}
