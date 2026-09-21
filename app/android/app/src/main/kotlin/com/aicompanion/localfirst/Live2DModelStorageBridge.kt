package com.aicompanion.localfirst

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Small, renderer-independent bridge for removing model data left by an older
 * Live2D integration. Keep this bridge when the renderer itself is replaced so
 * an app update never strands a large imported model in app-private storage.
 */
class Live2DModelStorageBridge(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) {
    private val appContext = activity.applicationContext
    private val storageRoot = File(appContext.filesDir, LEGACY_STORAGE_DIRECTORY).canonicalFile
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "live2d-model-storage").apply { isDaemon = true }
    }
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    @Volatile
    private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.error("live2d_storage_disposed", "Live2D storage bridge is detached", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "status" -> runStorageTask(result) { status() }
                "clearImportedModels" -> runStorageTask(result) { clearImportedModels() }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }

    private fun runStorageTask(
        result: MethodChannel.Result,
        task: () -> Map<String, Any>,
    ) {
        worker.execute {
            try {
                val value = task()
                activity.runOnUiThread {
                    if (!disposed) result.success(value)
                }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    if (!disposed) {
                        result.error(
                            "live2d_storage_failed",
                            error.message ?: error.javaClass.simpleName,
                            null,
                        )
                    }
                }
            }
        }
    }

    private fun status(): Map<String, Any> {
        requireSafeRoot()
        return mapOf(
            "hasData" to storageRoot.exists(),
            "bytes" to storageRoot.totalFileBytes(),
        )
    }

    private fun clearImportedModels(): Map<String, Any> {
        requireSafeRoot()
        val deletedBytes = storageRoot.totalFileBytes()
        deleteTree(storageRoot)
        val preferencesCleared = appContext
            .getSharedPreferences(LEGACY_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        if (!preferencesCleared) throw IOException("无法清除旧 Live2D 模型索引")
        return mapOf(
            "cleared" to true,
            "deletedBytes" to deletedBytes,
        )
    }

    private fun requireSafeRoot() {
        val filesRoot = appContext.filesDir.canonicalFile
        check(storageRoot.parentFile == filesRoot && storageRoot.name == LEGACY_STORAGE_DIRECTORY) {
            "拒绝清理非 Live2D 模型目录"
        }
    }

    private fun File.totalFileBytes(): Long {
        if (!exists()) return 0L
        if (isSymbolicLink()) return length()
        if (isFile) return length()
        return listFiles()?.sumOf { it.totalFileBytes() } ?: 0L
    }

    private fun deleteTree(root: File) {
        if (!root.exists()) return
        if (!root.isSymbolicLink() && root.isDirectory) {
            root.listFiles()?.forEach(::deleteTree)
        }
        if (!root.delete() && root.exists()) {
            throw IOException("无法删除旧 Live2D 模型文件：${root.name}")
        }
    }

    private fun File.isSymbolicLink(): Boolean = absoluteFile.path != canonicalFile.path

    companion object {
        const val CHANNEL = "ai_companion/live2d_model_storage"
        private const val LEGACY_STORAGE_DIRECTORY = "sen-live2d"
        private const val LEGACY_PREFERENCES = "sen_live2d"
    }
}
