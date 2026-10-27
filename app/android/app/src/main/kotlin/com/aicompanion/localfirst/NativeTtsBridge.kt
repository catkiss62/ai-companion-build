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

/** Flutter -> Kotlin boundary for the local Genie-TTS ONNX engine. */
class NativeTtsBridge(
    context: Context,
    flutterEngine: FlutterEngine,
    private val exportOnly: Boolean = false,
) {
    private val hostId = java.util.UUID.randomUUID().toString()
    private val engine = NativeTtsEngine.shared(context.applicationContext)

    // Dart submits all sentence generation requests immediately, but the
    // shared Genie ONNX sessions must remain serialized. This FIFO worker gives us
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
            if (exportOnly && call.method !in setOf("claimVoiceExport", "generateVoiceExport", "endVoiceExport")) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val lease = call.argument<Number>("lease")?.toLong()
            try {
            when (call.method) {
                "claimPlayback" -> result.success(engine.claimPlayback(hostId, call.argument<String>("message_id").orEmpty()))
                "playbackSnapshot" -> result.success(engine.playbackSnapshot())
                "claimVoiceExport" -> result.success(engine.claimVoiceExport(hostId))
                "generateVoiceExport" -> {
                    val id = call.argument<Number>("export_id")?.toLong() ?: error("voice_export_owner")
                    submit(generationWorker, result, "tts_voice_export_failed") {
                        engine.generateVoiceExport(hostId, id, call.argument<String>("text").orEmpty(),
                            call.argument<String>("language").orEmpty(), call.argument<String>("voice").orEmpty())
                    }
                }
                "endVoiceExport" -> {
                    val id = call.argument<Number>("export_id")?.toLong() ?: error("voice_export_owner")
                    engine.endVoiceExport(hostId, id, call.argument<Boolean>("cancel") == true)
                    result.success(null)
                }
                "localStatus" -> result.success(engine.localStatus())
                "status" -> submit(generationWorker, result, "tts_status_failed", lease) {
                    engine.status()
                }
                "verifyArtifacts" -> submit(generationWorker, result, "tts_verify_failed", lease) {
                    engine.verifyArtifacts()
                }
                "initialize" -> submit(generationWorker, result, "tts_init_failed", lease) {
                    engine.initialize(call.argument<String>("language").orEmpty())
                }
                "prepareLanguage" -> submit(generationWorker, result, "tts_frontend_failed", lease) {
                    engine.prepareLanguage(call.argument<String>("language").orEmpty())
                }
                "configureAutoAffinity" -> submit(generationWorker, result, "tts_runtime_config_failed", lease) {
                    engine.configureAutoAffinity(
                        call.argument<Boolean>("enabled") == true,
                        lease,
                    )
                }
                "diagnose" -> submit(generationWorker, result, "tts_diagnose_failed", lease) {
                    engine.diagnose(call.argument<String>("language").orEmpty())
                }
                "importChineseRoberta" -> submit(generationWorker, result, "tts_import_failed", lease) {
                    engine.importChineseRoberta(call.argument<String>("path").orEmpty())
                }
                "generate" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val language = call.argument<String>("language").orEmpty()
                    val voice = call.argument<String>("voice").orEmpty()
                    val segmentIndex = call.argument<Int>("segmentIndex") ?: -1
                    val generation = lease ?: engine.generationToken()
                    submit(generationWorker, result, "tts_generate_failed", lease) {
                        engine.generate(text, language, voice, segmentIndex, generation)
                    }
                }
                "beginAudioStream" -> {
                    val generation = lease ?: engine.generationToken()
                    submit(playbackWorker, result, "tts_playback_begin_failed", lease) {
                        engine.beginAudioStream(generation)
                    }
                }
                "enqueueAudio" -> {
                    val audio = call.argument<ByteArray>("audioData") ?: byteArrayOf()
                    val speedMultiplier =
                        call.argument<Double>("speedMultiplier") ?: 1.0
                    val generation = lease ?: engine.generationToken()
                    submit(playbackWorker, result, "tts_playback_enqueue_failed", lease) {
                        engine.enqueueAudio(audio, speedMultiplier, generation,
                            call.argument<Map<String, Any>>("presentation"))
                    }
                }
                "finishAudioStream" -> {
                    val generation = lease ?: engine.generationToken()
                    submit(playbackWorker, result, "tts_playback_finish_failed", lease) {
                        engine.finishAudioStream(generation)
                    }
                }
                // Backwards-compatible one-shot path. Normal app speech uses
                // generate + one continuous AudioTrack stream through the
                // scheduler above.
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    submit(playbackWorker, result, "tts_speak_failed", lease) {
                        engine.speak(text)
                        null
                    }
                }
                "stop" -> {
                    engine.stopPlayback(lease)
                    result.success(null)
                }
                "pause" -> {
                    engine.controlPlayback(lease) { engine.pause() }
                    result.success(null)
                }
                "resume" -> {
                    engine.controlPlayback(lease) { engine.resume() }
                    result.success(null)
                }
                "setSpeed" -> submit(generationWorker, result, "tts_speed_failed", lease) {
                    engine.controlPlayback(lease) { engine.setSpeed(call.argument<Double>("speed") ?: 1.0) }
                    null
                }
                "setPitch" -> {
                    engine.controlPlayback(lease) { engine.setPitch(call.argument<Double>("pitch") ?: 1.0) }
                    result.success(null)
                }
                "setVolume" -> {
                    engine.controlPlayback(lease) { engine.setVolume(call.argument<Double>("volume") ?: 1.0) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
            } catch (error: Throwable) { result.error("tts_owner_rejected", error.message, null) }
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
        lease: Long? = null,
        block: () -> T,
    ) {
        try {
            worker.execute {
                val response = runCatching {
                    engine.requirePlaybackOwner(lease)
                    val value = block()
                    engine.requirePlaybackOwner(lease)
                    value
                }
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
        engine.cancelVoiceExports(hostId)
        PlaybackSessionRegistry.ownsHost(hostId)?.let { engine.stopPlayback(it) }
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
