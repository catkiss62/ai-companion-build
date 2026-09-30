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
    private val root = File(app.filesDir, "caicai-live2d").canonicalFile
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

    fun isPending(): Boolean = synchronized(lock) { prefs.getBoolean("pending", false) }

    fun currentModels(): Models = synchronized(lock) {
        val maidPath = prefs.getString("maid", "").orEmpty()
        val accessoryPath = prefs.getString("accessory", "").orEmpty()
        indexedModels(maidPath, accessoryPath)?.let { return@synchronized it }

        // The ZIP's own manifest is the source of truth. Restore a stale or
        // missing preference index only after both files can be read from the
        // promoted current directory. Never turn a failed read into "no import".
        val manifest = current.walkTopDown().firstOrNull {
            it.isFile && it.name.equals("accessory-lab.json", ignoreCase = true)
        }
        if (manifest != null) {
            try {
                val config = JSONObject(manifest.readText(Charsets.UTF_8))
                val parent = manifest.parentFile ?: throw IOException("模型清单目录无效")
                val maid = safeChild(parent, config.getString("mainModel"))
                val accessory = safeChild(parent, config.getString("accessoryModel"))
                if (maid?.isFile != true || accessory?.isFile != true) {
                    throw IOException("正式目录中的模型文件无法读回")
                }
                val recoveredMaid = CaicaiModelPaths.relative(current, maid)
                val recoveredAccessory = CaicaiModelPaths.relative(current, accessory)
                if (!prefs.edit().putString("maid", recoveredMaid)
                        .putString("accessory", recoveredAccessory).commit()) {
                    throw IOException("无法恢复模型索引")
                }
                CaicaiDiagnostics.record(app, "index_recovered")
                return@synchronized Models(maid, accessory, "菜菜女仆与三配件已导入")
            } catch (error: Exception) {
                val detail = "模型文件读回失败：${error.message ?: error.javaClass.simpleName}"
                return@synchronized Models(detail = detail)
            }
        }
        if (prefs.getBoolean("pending", false) || maidPath.isNotBlank() || accessoryPath.isNotBlank()) {
            Models(detail = "模型索引存在，但正式目录中没有模型清单；请重新导入 ZIP")
        } else Models()
    }

    fun importZip(uri: Uri): Models {
        synchronized(lock) { require(portableLease == null) { "存档操作正在进行" } }
        if (!root.exists() && !root.mkdirs()) throw IOException("无法创建模型目录")
        remove(staging)
        if (!staging.mkdirs()) throw IOException("无法创建模型暂存目录")
        try {
            CaicaiDiagnostics.record(app, "unpacking")
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
            // The lab loads these referenced files immediately. A ZIP with two
            // model3 manifests but missing moc/texture/physics must not be
            // reported as a successful import and replace the working package.
            validateModelFiles(maid, accessoryDonor = false)
            validateModelFiles(accessory, accessoryDonor = true)
            CaicaiDiagnostics.record(app, "manifest_validated")
            val maidPath = CaicaiModelPaths.relative(staging, maid)
            val accessoryPath = CaicaiModelPaths.relative(staging, accessory)
            // Settings can import before the stage exists, so the candidate may
            // remain pending indefinitely. Keep it until the replacement ZIP
            // has passed structural checks, then restore the last verified
            // package (if any) before starting the next transaction.
            return synchronized(lock) {
                require(portableLease == null) { "存档操作正在进行" }
                if (prefs.getBoolean("pending", false)) rollbackPendingImport()
                remove(backup)
                if (current.exists() && !current.renameTo(backup)) throw IOException("无法暂存旧模型")
                if (!staging.renameTo(current)) {
                    if (backup.exists()) backup.renameTo(current)
                    throw IOException("无法启用新模型")
                }
                val promotedMaid = safeChild(current, maidPath)
                val promotedAccessory = safeChild(current, accessoryPath)
                if (promotedMaid?.isFile != true || promotedAccessory?.isFile != true) {
                    remove(current)
                    if (backup.exists()) backup.renameTo(current)
                    throw IOException("模型暂存完成，但正式目录中的主模型或配件模型无法读回")
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
                val readback = currentModels()
                if (!readback.available) {
                    remove(current)
                    if (backup.exists()) backup.renameTo(current)
                    prefs.edit().putString("maid", oldMaid)
                        .putString("accessory", oldAccessory)
                        .remove("pending").remove("old_maid").remove("old_accessory").commit()
                    throw IOException("模型索引读回失败：${readback.detail}")
                }
                CaicaiDiagnostics.record(app, "import_staged", "等待 Live2D 画面渲染确认")
                readback
            }
        } catch (error: Throwable) {
            synchronized(lock) {
                remove(staging)
                if (!current.exists() && backup.exists()) backup.renameTo(current)
            }
            throw error
        }
    }

    fun clearImportedModels() = synchronized(lock) {
        require(portableLease == null) { "存档操作正在进行" }
        remove(root)
        if (!prefs.edit().clear().commit()) throw IOException("无法清除模型索引")
        CaicaiDiagnostics.record(app, "models_deleted")
    }

    fun confirmPendingImport() = synchronized(lock) {
        if (!prefs.getBoolean("pending", false)) return@synchronized
        remove(backup)
        prefs.edit().remove("old_maid").remove("old_accessory")
            .remove("pending").apply()
        CaicaiDiagnostics.record(app, "render_verified")
    }

    fun rollbackPendingImport(): Boolean = synchronized(lock) {
        if (portableLease != null) return@synchronized false
        if (!prefs.getBoolean("pending", false)) return@synchronized false
        remove(current)
        val restored = backup.exists() && backup.renameTo(current)
        val edit = prefs.edit().remove("pending")
        if (restored) {
            edit.putString("maid", prefs.getString("old_maid", ""))
                .putString("accessory", prefs.getString("old_accessory", ""))
        } else edit.remove("maid").remove("accessory")
        edit.remove("old_maid").remove("old_accessory").commit()
        CaicaiDiagnostics.record(app, "render_rollback", if (restored) "已恢复上一模型包" else "未找到已验证的旧模型包")
        return@synchronized restored
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

    private fun safeChild(parent: File, path: String): File? = CaicaiModelPaths.child(parent, path)

    private fun indexedModels(maidPath: String, accessoryPath: String): Models? {
        val maid = safeChild(current, maidPath)
        val accessory = safeChild(current, accessoryPath)
        return if (maid?.isFile == true && accessory?.isFile == true) {
            Models(maid, accessory, "菜菜女仆与三配件已导入")
        } else null
    }

    private fun validateModelFiles(modelFile: File, accessoryDonor: Boolean) {
        val references = JSONObject(modelFile.readText(Charsets.UTF_8)).getJSONObject("FileReferences")
        val modelRoot = modelFile.parentFile ?: throw IOException("模型清单路径无效")
        fun requireFile(path: String) {
            val file = safeChild(modelRoot, path)
            if (file?.isFile != true || file.length() == 0L) {
                throw IOException("模型包缺少引用文件：${modelFile.name} / $path")
            }
        }
        requireFile(references.getString("Moc"))
        val textures = references.getJSONArray("Textures")
        if (accessoryDonor) {
            // The Caicai donor model declares 26 slots, but its three-piece
            // renderer selects only these three atlases. The approved ZIP
            // intentionally omits dormant textures; the original loader also
            // skips unselected slots in requiredTextureIndices().
            for (index in intArrayOf(6, 16, 19)) {
                if (index >= textures.length()) throw IOException("Sen 配件模型缺少所需贴图槽 $index")
                requireFile(textures.getString(index))
            }
        } else for (i in 0 until textures.length()) requireFile(textures.getString(i))
        for (optional in arrayOf("Physics", "Pose", "DisplayInfo", "UserData")) {
            if (references.has(optional)) requireFile(references.getString(optional))
        }
        val expressions = references.optJSONArray("Expressions")
        if (expressions != null) for (i in 0 until expressions.length()) {
            requireFile(expressions.getJSONObject(i).getString("File"))
        }
        val motions = references.optJSONObject("Motions")
        if (motions != null) for (name in motions.keys()) {
            val group = motions.getJSONArray(name)
            for (i in 0 until group.length()) requireFile(group.getJSONObject(i).getString("File"))
        }
    }

    private fun remove(file: File) {
        if (!file.exists()) return
        file.walkBottomUp().forEach {
            if (!it.delete() && it.exists()) throw IOException("无法清理模型暂存文件")
        }
    }

    fun beginPortableSnapshot(): String = synchronized(lock) {
        require(portableLease == null) { "存档操作正在进行" }
        java.util.UUID.randomUUID().toString().also { portableLease = it }
    }
    fun endPortableSnapshot(token: String) = synchronized(lock) {
        require(portableLease == token); portableLease = null
    }
    fun portableDirectory(token: String): File = synchronized(lock) {
        require(portableLease == token)
        // A damaged installed package must not silently become an empty backup.
        if (current.exists() && current.listFiles().orEmpty().isNotEmpty()) validatePortableDirectory(current)
        else require(prefs.getString("maid", "").isNullOrEmpty() && prefs.getString("accessory", "").isNullOrEmpty()) {
            "模型索引存在但文件丢失，无法创建完整存档"
        }
        current
    }
    fun validatePortableDirectory(directory: File): Models {
        if (!directory.exists() || directory.listFiles().orEmpty().isEmpty()) return Models()
        val manifest = directory.walkTopDown().firstOrNull {
            it.isFile && it.name.equals("accessory-lab.json", ignoreCase = true)
        } ?: throw IOException("存档模型缺少 accessory-lab.json")
        val config = JSONObject(manifest.readText(Charsets.UTF_8))
        val parent = manifest.parentFile ?: throw IOException("模型清单路径无效")
        val maid = safeChild(parent, config.getString("mainModel"))
        val accessory = safeChild(parent, config.getString("accessoryModel"))
        require(maid?.isFile == true && accessory?.isFile == true) { "存档模型引用不完整" }
        validateModelFiles(maid!!, false); validateModelFiles(accessory!!, true)
        return Models(maid, accessory)
    }
    fun installPortableIndex(token: String) = synchronized(lock) {
        require(portableLease == token)
        val restored = validatePortableDirectory(current)
        val edit = prefs.edit().remove("maid").remove("accessory").remove("old_maid")
            .remove("old_accessory").remove("pending")
        if (restored.available) edit.putString("maid", CaicaiModelPaths.relative(current, restored.maid!!))
            .putString("accessory", CaicaiModelPaths.relative(current, restored.accessory!!))
        if (!edit.commit()) throw IOException("无法保存存档模型索引")
    }
    fun finishPortableInstall(token: String) = synchronized(lock) {
        require(portableLease == token)
        // Stale import rollback candidates are not part of the restored user state.
        runCatching { remove(backup); remove(staging) }
    }
    companion object { private val lock = Any(); private var portableLease: String? = null }
}
