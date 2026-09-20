package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
import com.catkiss.senlive2dcompanion.SenLive2DPlatformViewFactory
import com.catkiss.senlive2dcompanion.SenLive2DRuntime
import com.catkiss.senlive2dcompanion.SenModelRepository
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** File-picker/import bridge; rendering commands stay scoped to each PlatformView. */
class SenLive2DBridge(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) {
    private val repository = SenModelRepository(activity)
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "sen-model-import").apply { isDaemon = true }
    }
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    private var pendingImport: MethodChannel.Result? = null
    private var disposed = false

    init {
        flutterEngine.platformViewsController.registry.registerViewFactory(
            SenLive2DPlatformViewFactory.VIEW_TYPE,
            SenLive2DPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.error("sen_bridge_disposed", "Sen bridge is detached", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "status" -> result.success(statusMap())
                "pickModelZip" -> pickModelZip(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickModelZip(result: MethodChannel.Result) {
        if (pendingImport != null) {
            result.error("sen_import_busy", "已有 Sen 模型正在选择或导入", null)
            return
        }
        pendingImport = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/zip"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "application/octet-stream"))
        }
        activity.startActivityForResult(intent, REQUEST_IMPORT_ZIP)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_IMPORT_ZIP) return false
        val result = pendingImport ?: return true
        pendingImport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(mapOf("cancelled" to true, "available" to repository.currentModel().available))
            return true
        }
        worker.execute {
            try {
                val info = repository.importZip(uri)
                activity.runOnUiThread {
                    SenLive2DRuntime.reloadModel()
                    result.success(
                        mapOf(
                            "cancelled" to false,
                            "available" to info.available,
                            "detail" to info.detail,
                            "expressionCount" to info.expressions.size,
                        ),
                    )
                }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    result.error("sen_import_failed", error.message ?: error.javaClass.simpleName, null)
                }
            }
        }
        return true
    }

    fun onResume() = SenLive2DRuntime.onHostResume()
    fun onPause() = SenLive2DRuntime.onHostPause()

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        pendingImport?.error("sen_import_cancelled", "Sen bridge was detached", null)
        pendingImport = null
        worker.shutdownNow()
    }

    private fun statusMap(): Map<String, Any> {
        val info = repository.currentModel()
        return mapOf(
            "available" to info.available,
            "detail" to info.detail,
            "expressionCount" to info.expressions.size,
        )
    }

    companion object {
        const val CHANNEL = "ai_companion/sen_live2d"
        private const val REQUEST_IMPORT_ZIP = 29412
    }
}
