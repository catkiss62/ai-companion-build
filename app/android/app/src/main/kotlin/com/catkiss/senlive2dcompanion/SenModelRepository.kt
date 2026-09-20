package com.catkiss.senlive2dcompanion

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.Locale
import java.util.zip.ZipInputStream

/** App-private, transactional storage for the user-owned Sen model ZIP. */
class SenModelRepository(context: Context) {
    private val appContext = context.applicationContext
    private val root = File(appContext.filesDir, "sen-live2d")
    private val current = File(root, "current")
    private val staging = File(root, "staging")
    private val backup = File(root, "backup")
    private val prefs = appContext.getSharedPreferences("sen_live2d", Context.MODE_PRIVATE)

    data class ModelInfo(
        val available: Boolean,
        val modelFile: File? = null,
        val expressions: List<String> = emptyList(),
        val detail: String = "尚未导入 Sen 模型 ZIP",
    )

    @Synchronized
    fun currentModel(): ModelInfo {
        val relative = prefs.getString(KEY_MODEL_PATH, "").orEmpty()
        if (relative.isBlank()) return ModelInfo(false)
        val file = safeResolve(current, relative) ?: return ModelInfo(false)
        if (!file.isFile) return ModelInfo(false)
        val expressions = runCatching {
            val array = JSONArray(prefs.getString(KEY_EXPRESSIONS, "[]"))
            List(array.length()) { array.optString(it) }.filter(String::isNotBlank)
        }.getOrDefault(emptyList())
        return ModelInfo(true, file, expressions, prefs.getString(KEY_DETAIL, "Sen 模型已导入").orEmpty())
    }

    @Synchronized
    fun importZip(uri: Uri): ModelInfo {
        root.mkdirs()
        // A second explicit import accepts the currently selected model as the
        // baseline before creating a new rollback point.
        if (prefs.getBoolean(KEY_PENDING_IMPORT, false)) confirmPendingImport()
        deleteRecursively(staging)
        check(staging.mkdirs()) { "无法创建 Sen 暂存目录" }
        try {
            unzipSecure(uri, staging)
            val model = staging.walkTopDown().firstOrNull {
                it.isFile && it.name.lowercase(Locale.ROOT).endsWith(".model3.json")
            } ?: throw IOException("ZIP 中没有找到 .model3.json")
            removeExcludedExpressions(model.parentFile)
            val expressions = registerExpressions(model)
            val relative = model.relativeTo(staging).invariantSeparatorsPath
            val detail = diagnostics(model, expressions.size)

            deleteRecursively(backup)
            if (current.exists() && !current.renameTo(backup)) {
                throw IOException("无法暂存现有 Sen 模型")
            }
            if (!staging.renameTo(current)) {
                if (backup.exists()) backup.renameTo(current)
                throw IOException("无法启用新 Sen 模型")
            }
            prefs.edit()
                .putString(KEY_OLD_MODEL_PATH, prefs.getString(KEY_MODEL_PATH, ""))
                .putString(KEY_OLD_EXPRESSIONS, prefs.getString(KEY_EXPRESSIONS, "[]"))
                .putString(KEY_OLD_DETAIL, prefs.getString(KEY_DETAIL, ""))
                .putString(KEY_MODEL_PATH, relative)
                .putString(KEY_EXPRESSIONS, JSONArray(expressions).toString())
                .putString(KEY_DETAIL, detail)
                .putBoolean(KEY_PENDING_IMPORT, true)
                .commit()
            return currentModel()
        } catch (error: Throwable) {
            deleteRecursively(staging)
            if (!current.exists() && backup.exists()) backup.renameTo(current)
            throw error
        }
    }

    @Synchronized
    fun confirmPendingImport() {
        if (!prefs.getBoolean(KEY_PENDING_IMPORT, false)) return
        deleteRecursively(backup)
        prefs.edit()
            .remove(KEY_PENDING_IMPORT)
            .remove(KEY_OLD_MODEL_PATH)
            .remove(KEY_OLD_EXPRESSIONS)
            .remove(KEY_OLD_DETAIL)
            .apply()
    }

    /** Restores the last renderer-confirmed model after a newly imported model fails to load. */
    @Synchronized
    fun rollbackPendingImport(): Boolean {
        if (!prefs.getBoolean(KEY_PENDING_IMPORT, false)) return false
        deleteRecursively(current)
        val restored = backup.exists() && backup.renameTo(current)
        val editor = prefs.edit()
            .remove(KEY_PENDING_IMPORT)
            .remove(KEY_OLD_MODEL_PATH)
            .remove(KEY_OLD_EXPRESSIONS)
            .remove(KEY_OLD_DETAIL)
        if (restored) {
            editor
                .putString(KEY_MODEL_PATH, prefs.getString(KEY_OLD_MODEL_PATH, ""))
                .putString(KEY_EXPRESSIONS, prefs.getString(KEY_OLD_EXPRESSIONS, "[]"))
                .putString(KEY_DETAIL, prefs.getString(KEY_OLD_DETAIL, "Sen 模型已恢复"))
        } else {
            editor.remove(KEY_MODEL_PATH).remove(KEY_EXPRESSIONS).remove(KEY_DETAIL)
        }
        editor.commit()
        return restored
    }

    private fun unzipSecure(uri: Uri, destination: File) {
        val destinationPath = destination.canonicalPath + File.separator
        var total = 0L
        var entries = 0
        appContext.contentResolver.openInputStream(uri).use { raw ->
            if (raw == null) throw IOException("无法读取 ZIP")
            ZipInputStream(raw.buffered()).use { zip ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (++entries > MAX_ZIP_ENTRIES) throw IOException("ZIP 文件数量异常")
                    val output = File(destination, entry.name)
                    val outputPath = output.canonicalPath
                    if (!outputPath.startsWith(destinationPath)) throw IOException("ZIP 路径不安全")
                    if (entry.isDirectory) {
                        if (!output.exists() && !output.mkdirs()) throw IOException("无法创建 ZIP 目录")
                    } else {
                        output.parentFile?.let {
                            if (!it.exists() && !it.mkdirs()) throw IOException("无法创建 ZIP 目录")
                        }
                        FileOutputStream(output).use { out ->
                            while (true) {
                                val count = zip.read(buffer)
                                if (count < 0) break
                                total += count
                                if (total > MAX_EXTRACTED_BYTES) {
                                    throw IOException("解压体积超过 1.5 GB 安全限制")
                                }
                                out.write(buffer, 0, count)
                            }
                        }
                    }
                    zip.closeEntry()
                }
            }
        }
    }

    private fun registerExpressions(modelFile: File): List<String> {
        val modelDirectory = modelFile.parentFile ?: throw IOException("模型目录无效")
        val files = modelDirectory.walkTopDown()
            .filter { it.isFile && it.name.lowercase(Locale.ROOT).endsWith(".exp3.json") }
            .sortedBy { it.name.lowercase(Locale.ROOT) }
            .toList()
        val expressions = JSONArray()
        val names = mutableListOf<String>()
        for (file in files) {
            if (isExcludedExpression(file)) continue
            val name = file.name.replace(Regex("(?i)\\.exp3\\.json$"), "")
            names += name
            expressions.put(
                JSONObject()
                    .put("Name", name)
                    .put("File", file.relativeTo(modelDirectory).invariantSeparatorsPath),
            )
        }
        val json = JSONObject(modelFile.readText(Charsets.UTF_8))
        val references = json.optJSONObject("FileReferences") ?: JSONObject().also {
            json.put("FileReferences", it)
        }
        references.put("Expressions", expressions)
        modelFile.writeText(json.toString(2), Charsets.UTF_8)
        return names
    }

    private fun removeExcludedExpressions(directory: File?) {
        if (directory == null) return
        directory.walkBottomUp().filter(::isExcludedExpression).forEach {
            if (it.exists() && !it.delete()) throw IOException("无法移除已废弃的原生预设")
        }
    }

    private fun isExcludedExpression(file: File): Boolean =
        file.isFile && file.name.equals(REMOVED_EXPRESSION, ignoreCase = true)

    private fun diagnostics(modelFile: File, expressionCount: Int): String = runCatching {
        val json = JSONObject(modelFile.readText(Charsets.UTF_8))
        val references = json.optJSONObject("FileReferences")
        val textures = references?.optJSONArray("Textures")?.length() ?: 0
        val moc = references?.optString("Moc").orEmpty().let { File(modelFile.parentFile, it) }
        val mocText = if (moc.isFile) "%.1f MiB".format(Locale.ROOT, moc.length() / 1048576.0) else "未知"
        "Cubism model3 v${json.optInt("Version", 0)} · 贴图 $textures 张 · moc3 $mocText · ZIP 原生预设 $expressionCount 个"
    }.getOrDefault("Sen 模型已导入 · ZIP 原生预设 $expressionCount 个")

    private fun safeResolve(parent: File, relative: String): File? = runCatching {
        val file = File(parent, relative).canonicalFile
        if (file.path.startsWith(parent.canonicalPath + File.separator)) file else null
    }.getOrNull()

    private fun deleteRecursively(file: File) {
        if (!file.exists()) return
        file.walkBottomUp().forEach { child ->
            if (!child.delete() && child.exists()) throw IOException("无法清理 Sen 临时文件")
        }
    }

    companion object {
        private const val KEY_MODEL_PATH = "model_path"
        private const val KEY_EXPRESSIONS = "expressions"
        private const val KEY_DETAIL = "detail"
        private const val KEY_PENDING_IMPORT = "pending_import"
        private const val KEY_OLD_MODEL_PATH = "old_model_path"
        private const val KEY_OLD_EXPRESSIONS = "old_expressions"
        private const val KEY_OLD_DETAIL = "old_detail"
        private const val REMOVED_EXPRESSION = "xiao" + "jingyu.exp3.json"
        private const val MAX_EXTRACTED_BYTES = 1_500_000_000L
        private const val MAX_ZIP_ENTRIES = 8_000
    }
}
