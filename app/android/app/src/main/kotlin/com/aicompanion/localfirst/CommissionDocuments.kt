package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
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
    private val namePattern = Regex("""(任务-[a-f0-9-]{36}\.json|(?:报告|技能|停用技能)-[\u3400-\u9fffA-Za-z0-9 _-]{1,75}\.md)""")
    private val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    fun result(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != 4281) return false
        val pending = picker ?: return true
        picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { pending.success(null); return true }
        try {
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
