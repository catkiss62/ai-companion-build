package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
import com.catkiss.senlive2dcompanion.Live2DProfiles
import com.catkiss.senlive2dcompanion.CaicaiModelRepository
import com.catkiss.senlive2dcompanion.CaicaiDiagnostics
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
    private val portable = PortableCompanionState(activity, repository,
        releaseModel = { CaicaiRuntime.releaseModel() },
        refreshPreferences = { CaicaiRuntime.refreshPreferences() })
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    private val worker = Executors.newSingleThreadExecutor { task ->
        Thread(task, "caicai-live2d-import").apply { isDaemon = true }
    }
    private var pending: MethodChannel.Result? = null
    private var disposed = false
    private var mutating = false
    private var pendingProfile = Live2DProfiles.CAICAI

    init {
        flutterEngine.platformViewsController.registry.registerViewFactory(
            CaicaiPlatformViewFactory.VIEW_TYPE,
            CaicaiPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        channel.setMethodCallHandler { call, result ->
            if (disposed) return@setMethodCallHandler result.error("disposed", "Live2D bridge detached", null)
            if (call.method.startsWith("portable")) {
                try {
                    val token = call.argument<String>("token").orEmpty()
                    when (call.method) {
                        "portableBegin" -> {
                            require(pending == null && !mutating) { "模型导入正在进行" }
                            result.success(portable.begin())
                        }
                        "portableValidatePreferences" -> { PortableCompanionState.validatedPreferences(call.argument<Map<*, *>>("preferences") ?: emptyMap<Any, Any>()); result.success(null) }
                        "portableValidate" -> { portable.validate(token, call.argument<String>("directory").orEmpty()); result.success(null) }
                        "portableApply" -> { portable.apply(token, call.argument<Map<*, *>>("preferences") ?: emptyMap<Any, Any>(), call.argument<Boolean>("restoreModels") != false); result.success(null) }
                        "portableFinish" -> { portable.finish(token, call.argument<Boolean>("commit") == true)
                            result.success(mapOf("profile" to Live2DProfiles.selected(activity), "profile_generation" to Live2DProfiles.generation)) }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("portable_state_failed", error.message, null) }
                return@setMethodCallHandler
            }
            when (call.method) {
                "status" -> {
                    val profile=Live2DProfiles.selected(activity)
                    val selected=CaicaiModelRepository(activity,profile)
                    val models = selected.currentModels()
                    val appearance=activity.getSharedPreferences("deepseek_appearance",android.content.Context.MODE_PRIVATE).all
                    val stage=activity.getSharedPreferences("deepseek_stage",android.content.Context.MODE_PRIVATE).all
                    result.success(mapOf(
                        "available" to models.available,
                        "detail" to models.detail,
                        "pending" to selected.isPending(),
                        "profile" to profile,
                        "profile_generation" to Live2DProfiles.generation,
                        "profiles" to mapOf(Live2DProfiles.CAICAI to repository.currentModels().available,
                            Live2DProfiles.DEEPSEEK to CaicaiModelRepository(activity,Live2DProfiles.DEEPSEEK).currentModels().available),
                        "deepseek_appearance" to appearance, "deepseek_stage" to stage,
                        "render" to CaicaiRuntime.state(),
                        "events" to CaicaiDiagnostics.events(activity),
                    ))
                }
                "selectProfile" -> {
                    if(pending!=null || portable.busy || mutating) return@setMethodCallHandler result.error("busy","模型或存档操作正在进行",null)
                    val profile=call.argument<String>("profile").orEmpty()
                    if(!Live2DProfiles.valid(profile)) return@setMethodCallHandler result.error("invalid_profile","不支持的立绘模型",null)
                    CaicaiRuntime.releaseModel()
                    Live2DProfiles.request(activity,profile)
                    result.success(mapOf("profile" to profile,"profile_generation" to Live2DProfiles.generation))
                }
                "control" -> {
                    val args = call.arguments as? Map<*, *>
                    val profile=Live2DProfiles.selected(activity)
                    val method=args?.get("method")?.toString().orEmpty()
                    if((portable.busy || mutating || pending!=null) && method !in setOf("getState","getMotionTuning","parameters","exportLive2DDiagnostics"))
                        return@setMethodCallHandler result.success(false)
                    if ((args?.get("profile") ?: Live2DProfiles.CAICAI) != profile ||
                        (args?.get("profile_generation") as? Number)?.toLong()?.let { it != Live2DProfiles.generation } == true)
                        return@setMethodCallHandler result.success(false)
                    CaicaiRuntime.control(args?.get("method")?.toString() ?: "", args?.get("arguments"), result)
                }
                "setEditorFocused" -> {
                    CaicaiRuntime.setKeyboardVisible(call.arguments == true)
                    result.success(null)
                }
                "clearImportedModels" -> {
                    if (pending != null || portable.busy || mutating) return@setMethodCallHandler result.error("busy", "模型导入正在进行", null)
                    val deletingProfile=Live2DProfiles.selected(activity)
                    if((call.argument<String>("profile") ?: Live2DProfiles.CAICAI) != deletingProfile ||
                        call.argument<Number>("profile_generation")?.toLong()?.let { it != Live2DProfiles.generation } == true)
                        return@setMethodCallHandler result.error("stale_profile","删除目标已变化",null)
                    mutating=true
                    CaicaiRuntime.releaseModel()
                    worker.execute {
                        try {
                            CaicaiModelRepository(activity,deletingProfile).clearImportedModels()
                            activity.runOnUiThread { mutating=false; if (!disposed) result.success(null) }
                        } catch (error: Exception) {
                            activity.runOnUiThread { mutating=false; if (!disposed) result.error("delete_failed", error.message, null) }
                        }
                    }
                }
                "pickModelZip" -> {
                    if (pending != null || portable.busy || mutating) return@setMethodCallHandler result.error("busy", "模型导入正在进行", null)
                    pending = result
                    pendingProfile = Live2DProfiles.selected(activity)
                    CaicaiDiagnostics.record(activity, "picker_opened")
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/zip"
                        putExtra(Intent.EXTRA_MIME_TYPES,
                            arrayOf("application/zip", "application/octet-stream"))
                    }
                    try { activity.startActivityForResult(intent, REQUEST_IMPORT) }
                    catch (error: Exception) {
                        pending = null
                        CaicaiDiagnostics.record(activity, "picker_failed", error.message ?: "无法打开文件选择器")
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
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            CaicaiDiagnostics.record(activity, "picker_cancelled")
            callback.success(mapOf("cancelled" to true))
            return true
        }
        CaicaiDiagnostics.record(activity, "file_selected")
        worker.execute {
            try {
                val selected=CaicaiModelRepository(activity,pendingProfile)
                val imported = selected.importZip(uri)
                val signature=selected.fingerprint()
                activity.getSharedPreferences(Live2DProfiles.REGISTRY,android.content.Context.MODE_PRIVATE).edit()
                    .putString(if(pendingProfile==Live2DProfiles.CAICAI) "caicaiFingerprint" else "deepseekFingerprint",signature).commit()
                activity.runOnUiThread {
                    if (!disposed) {
                        // Dart revision recreates the view once; old callbacks cannot
                        // verify or overwrite the newly imported package.
                        CaicaiRuntime.releaseModel()
                        pending = null
                        callback.success(mapOf("cancelled" to false, "available" to imported.available,
                            "pending" to selected.isPending(), "profile" to pendingProfile)))
                    }
                }
            } catch (error: Throwable) {
                CaicaiDiagnostics.record(activity, "import_failed", error.message ?: error.javaClass.simpleName)
                activity.runOnUiThread {
                    if (!disposed) {
                        pending = null
                        callback.error("import_failed", error.message ?: "模型导入失败", null)
                    }
                }
            }
        }
        return true
    }

    fun onResume() = CaicaiRuntime.onHostResume()
    fun onPause() = CaicaiRuntime.onHostPause()

    fun dispose() {
        portable.dispose()
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
