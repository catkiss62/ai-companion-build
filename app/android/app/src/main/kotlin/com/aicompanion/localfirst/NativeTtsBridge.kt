package com.aicompanion.localfirst

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Flutter -> Kotlin boundary for the local Bert-VITS2/MNN engine. */
class NativeTtsBridge(
    context: Context,
    flutterEngine: FlutterEngine,
) {
    private val engine = NativeTtsEngine.shared(context.applicationContext)

    // Meju A2 submits all sentence generation requests immediately, but the
    // legacy MNN engine itself must remain serialized. This FIFO worker gives us
    // the same generation-ahead behavior without overlapping unsafe inference.
    private val generationWorker = singleWorker("ai-companion-local-tts-generate")

    // AudioTrack must not occupy the generation worker. While this worker drains
    // sentence N, generationWorker can prepare N+1/N+2 in the background.
    private val playbackWorker = singleWorker("ai-companion-local-tts-playback")

    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    @Volatile
    private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.error("tts_bridge_disposed", "TTS bridge is no longer attached to this FlutterEngine", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "status" -> result.success(engine.status())
                "verifyArtifacts" -> submit(generationWorker, result, "tts_verify_failed") {
                    engine.verifyArtifacts()
                }
                "initialize" -> submit(generationWorker, result, "tts_init_failed") {
                    engine.initialize()
                }
                "diagnose" -> submit(generationWorker, result, "tts_diagnose_failed") {
                    engine.diagnose()
                }
                "generate" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val generation = engine.generationToken()
                    submit(generationWorker, result, "tts_generate_failed") {
                        engine.generate(text, generation)
                    }
                }
                "playAudio" -> {
                    val audio = call.argument<ByteArray>("audioData") ?: byteArrayOf()
                    val generation = engine.generationToken()
                    submit(playbackWorker, result, "tts_playback_failed") {
                        engine.playAudio(audio, generation)
                        null
                    }
                }
                // Backwards-compatible one-shot path. Normal app speech uses
                // generate + playAudio through the A2 scheduler above.
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    submit(playbackWorker, result, "tts_speak_failed") {
                        engine.speak(text)
                        null
                    }
                }
                "stop" -> {
                    engine.stop()
                    result.success(null)
                }
                "pause" -> {
                    engine.pause()
                    result.success(null)
                }
                "resume" -> {
                    engine.resume()
                    result.success(null)
                }
                "setSpeed" -> submit(generationWorker, result, "tts_speed_failed") {
                    engine.setSpeed(call.argument<Double>("speed") ?: 1.0)
                    null
                }
                "setVolume" -> {
                    engine.setVolume(call.argument<Double>("volume") ?: 1.0)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun singleWorker(name: String) = ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        LinkedBlockingQueue(),
    ) { runnable ->
        Thread(runnable, name).apply { isDaemon = true }
    }

    private fun <T> submit(
        worker: ThreadPoolExecutor,
        result: MethodChannel.Result,
        errorCode: String,
        block: () -> T,
    ) {
        try {
            worker.execute {
                val response = runCatching(block)
                main.post {
                    if (disposed) return@post
                    response.fold(
                        onSuccess = result::success,
                        onFailure = { result.error(errorCode, it.message, null) },
                    )
                }
            }
        } catch (_: RejectedExecutionException) {
            if (!disposed) {
                result.error("tts_worker_stopped", "TTS worker is no longer available", null)
            }
        }
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        // The native model/runtime is process-scoped and shared by MainActivity,
        // overlay and background FlutterEngines. Do not release it when only one
        // host dies. Running JNI work is allowed to finish under NativeTtsEngine
        // cancellation fencing; late MethodChannel results are discarded.
        generationWorker.queue.clear()
        generationWorker.shutdown()
        playbackWorker.queue.clear()
        playbackWorker.shutdown()
    }

    companion object {
        private const val CHANNEL = "ai_companion/tts"
    }
}
