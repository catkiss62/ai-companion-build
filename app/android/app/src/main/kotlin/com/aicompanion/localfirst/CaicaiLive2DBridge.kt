package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
import com.catkiss.senlive2dcompanion.CaicaiModelRepository
import com.catkiss.senlive2dcompanion.CaicaiPlatformViewFactory
import com.catkiss.senlive2dcompanion.CaicaiRuntime
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Native view registration and SAF import; Caicai retains all rendering ownership. */
class CaicaiLive2DBridge(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) {
    private val repository = CaicaiModelRepository(activity)
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    private val worker = Executors.newSingleThreadExecutor { task ->
        Thread(task, "caicai-live2d-import").apply { isDaemon = true }
    }
    private var pending: MethodChannel.Result? = null
    private var disposed = false

    init {
        flutterEngine.platformViewsController.registry.registerViewFactory(
            CaicaiPlatformViewFactory.VIEW_TYPE,
            CaicaiPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        channel.setMethodCallHandler { call, result ->
            if (disposed) return@setMethodCallHandler result.error("disposed", "Live2D bridge detached", null)
            when (call.method) {
                "status" -> result.success(mapOf("available" to repository.currentModels().available))
                "pickModelZip" -> {
                    if (pending != null) return@setMethodCallHandler result.error("busy", "模型导入正在进行", null)
                    pending = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/zip"
                        putExtra(Intent.EXTRA_MIME_TYPES,
                            arrayOf("application/zip", "application/octet-stream"))
                    }
                    try { activity.startActivityForResult(intent, REQUEST_IMPORT) }
                    catch (error: Exception) {
                        pending = null
                        result.error("picker_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != REQUEST_IMPORT) return false
        val callback = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            callback.success(mapOf("cancelled" to true))
            return true
        }
        worker.execute {
            try {
                val imported = repository.importZip(uri)
                activity.runOnUiThread {
                    if (!disposed) {
                        CaicaiRuntime.reloadModel()
                        callback.success(mapOf("cancelled" to false, "available" to imported.available))
                    }
                }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    if (!disposed) callback.error("import_failed", error.message ?: "模型导入失败", null)
                }
            }
        }
        return true
    }

    fun onResume() = CaicaiRuntime.onHostResume()
    fun onPause() = CaicaiRuntime.onHostPause()

    fun dispose() {
        disposed = true
        pending?.error("cancelled", "模型导入已取消", null)
        pending = null
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }

    companion object {
        const val CHANNEL = "ai_companion/caicai_live2d"
        private const val REQUEST_IMPORT = 0xCA31
    }
}
