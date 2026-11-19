package com.aicompanion.localfirst

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

internal object SeekMemoryBenchmark {
    private val running = AtomicBoolean(false)

    fun bind(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "ai_companion/seekmemory").setMethodCallHandler { call, result ->
            if (call.method != "runOriginal") {
                result.notImplemented()
            } else if (!running.compareAndSet(false, true)) {
                result.error("busy", "原版测试正在运行", null)
            } else {
                val main = Handler(Looper.getMainLooper())
                Thread({
                    try {
                        if (!Python.isStarted()) Python.start(AndroidPlatform(context))
                        val archive = File(context.cacheDir, "seekmemory-original.zip")
                        context.assets.open(archive.name).use { source ->
                            archive.outputStream().use { source.copyTo(it) }
                        }
                        val report = Python.getInstance().getModule("seekmemory_android")
                            .callAttr("run", archive.path, context.cacheDir.path).toString()
                        main.post { result.success(report) }
                    } catch (error: Exception) {
                        main.post { result.error("benchmark_failed", error.message, null) }
                    } finally {
                        running.set(false)
                    }
                }, "seekmemory-offline").start()
            }
        }
    }
}
