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

internal object ChatMemoryExam {
    private val running = AtomicBoolean(false)

    fun bind(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "ai_companion/chat_memory_exam").setMethodCallHandler { call, result ->
            if (call.method !in setOf("inputs", "packet", "score", "summary")) {
                result.notImplemented()
            } else if (!running.compareAndSet(false, true)) {
                result.error("busy", "原版测试正在运行", null)
            } else {
                val main = Handler(Looper.getMainLooper())
                Thread({
                    try {
                        if (!Python.isStarted()) Python.start(AndroidPlatform(context))
                        val archive = File(context.cacheDir, "chat-memory-0d8cde3.zip")
                        if (!archive.exists()) {
                            val temporary = File(context.cacheDir, "chat-memory-0d8cde3.tmp")
                            context.assets.open("chat-memory-v1.zip").use { source ->
                                temporary.outputStream().use { source.copyTo(it) }
                            }
                            check(temporary.renameTo(archive))
                        }
                        val payload = call.arguments as? String ?: error("缺少评测参数")
                        val report = Python.getInstance().getModule("chat_exam_android")
                            .callAttr("dispatch", archive.path, context.cacheDir.path, call.method, payload).toString()
                        main.post { result.success(report) }
                    } catch (error: Exception) {
                        main.post { result.error("benchmark_failed", error.message, null) }
                    } finally {
                        running.set(false)
                    }
                }, "chat-memory-exam").start()
            }
        }
    }
}
