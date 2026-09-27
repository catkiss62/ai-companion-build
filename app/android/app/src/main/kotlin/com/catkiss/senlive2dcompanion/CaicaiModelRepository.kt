package com.catkiss.senlive2dcompanion

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipInputStream

/** Transactional, private import of the two-model ZIP consumed by the Caicai lab. */
class CaicaiModelRepository(context: Context) {
    private val app = context.applicationContext
    private val root = File(app.filesDir, "caicai-live2d")
    private val current = File(root, "current")
    private val staging = File(root, "staging")
    private val backup = File(root, "backup")
    private val prefs = app.getSharedPreferences("caicai_live2d", Context.MODE_PRIVATE)

    data class Models(
        val maid: File? = null,
        val accessory: File? = null,
        val detail: String = "请导入菜菜女仆三配件 ZIP",
    ) {
        val available: Boolean get() = maid?.isFile == true && accessory?.isFile == true
    }

    @Synchronized
    fun currentModels(): Models {
        val maid = safeChild(current, prefs.getString("maid", "").orEmpty())
        val accessory = safeChild(current, prefs.getString("accessory", "").orEmpty())
        return if (maid?.isFile == true && accessory?.isFile == true) {
            Models(maid, accessory, "菜菜女仆与三配件已导入")
        } else Models()
    }

    @Synchronized
    fun importZip(uri: Uri): Models {
        if (!root.exists() && !root.mkdirs()) throw IOException("无法创建模型目录")
        if (prefs.getBoolean("pending", false)) {
            throw IOException("上一模型包尚未在 Live2D 画面完成验证，请先打开画面")
        }
        remove(staging)
        if (!staging.mkdirs()) throw IOException("无法创建模型暂存目录")
        try {
            unzip(uri)
            // Preserve the standalone app's accessory-lab.json contract and model paths.
            val manifest = staging.walkTopDown().firstOrNull {
                it.isFile && it.name.equals("accessory-lab.json", ignoreCase = true)
            } ?: throw IOException("模型包缺少 accessory-lab.json")
            val config = JSONObject(manifest.readText(Charsets.UTF_8))
            val manifestDir = manifest.parentFile ?: throw IOException("模型清单路径无效")
            val maid = safeChild(manifestDir, config.getString("mainModel"))
            val accessory = safeChild(manifestDir, config.getString("accessoryModel"))
            if (maid?.isFile != true || accessory?.isFile != true) {
                throw IOException("模型包缺少菜菜主模型或 Sen 配件模型")
            }
            val maidPath = maid.relativeTo(staging).invariantSeparatorsPath
            val accessoryPath = accessory.relativeTo(staging).invariantSeparatorsPath
            remove(backup)
            if (current.exists() && !current.renameTo(backup)) throw IOException("无法暂存旧模型")
            if (!staging.renameTo(current)) {
                if (backup.exists()) backup.renameTo(current)
                throw IOException("无法启用新模型")
            }
            val oldMaid = prefs.getString("maid", "").orEmpty()
            val oldAccessory = prefs.getString("accessory", "").orEmpty()
            if (!prefs.edit().putString("old_maid", oldMaid)
                    .putString("old_accessory", oldAccessory)
                    .putString("maid", maidPath).putString("accessory", accessoryPath)
                    .putBoolean("pending", true).commit()) {
                remove(current)
                if (backup.exists()) backup.renameTo(current)
                throw IOException("无法保存模型索引")
            }
            return currentModels()
        } catch (error: Throwable) {
            remove(staging)
            if (!current.exists() && backup.exists()) backup.renameTo(current)
            throw error
        }
    }

    @Synchronized
    fun confirmPendingImport() {
        if (!prefs.getBoolean("pending", false)) return
        remove(backup)
        prefs.edit().remove("old_maid").remove("old_accessory")
            .remove("pending").apply()
    }

    @Synchronized
    fun rollbackPendingImport(): Boolean {
        if (!prefs.getBoolean("pending", false)) return false
        remove(current)
        val restored = backup.exists() && backup.renameTo(current)
        val edit = prefs.edit().remove("pending")
        if (restored) {
            edit.putString("maid", prefs.getString("old_maid", ""))
                .putString("accessory", prefs.getString("old_accessory", ""))
        } else edit.remove("maid").remove("accessory")
        edit.remove("old_maid").remove("old_accessory").commit()
        return restored
    }

    private fun unzip(uri: Uri) {
        val prefix = staging.canonicalPath + File.separator
        var entries = 0
        var total = 0L
        val input = app.contentResolver.openInputStream(uri) ?: throw IOException("无法读取 ZIP")
        input.use { raw ->
            ZipInputStream(raw.buffered()).use { zip ->
                val bytes = ByteArray(64 * 1024)
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (++entries > 8_000) throw IOException("模型包文件过多")
                    val target = File(staging, entry.name)
                    if (!target.canonicalPath.startsWith(prefix)) throw IOException("ZIP 路径不安全")
                    if (entry.isDirectory) {
                        if (!target.isDirectory && !target.mkdirs()) throw IOException("无法创建模型目录")
                    } else {
                        val parent = target.parentFile ?: throw IOException("模型路径无效")
                        if (!parent.isDirectory && !parent.mkdirs()) throw IOException("无法创建模型目录")
                        FileOutputStream(target).use { output ->
                            while (true) {
                                val count = zip.read(bytes)
                                if (count < 0) break
                                total += count
                                if (total > 1_500_000_000L) throw IOException("模型包解压超过 1.5 GB")
                                output.write(bytes, 0, count)
                            }
                        }
                    }
                    zip.closeEntry()
                }
            }
        }
    }

    private fun safeChild(parent: File, path: String): File? = runCatching {
        if (path.isBlank()) return null
        File(parent, path).canonicalFile.takeIf {
            it.path.startsWith(parent.canonicalPath + File.separator)
        }
    }.getOrNull()

    private fun remove(file: File) {
        if (!file.exists()) return
        file.walkBottomUp().forEach {
            if (!it.delete() && it.exists()) throw IOException("无法清理模型暂存文件")
        }
    }
}
