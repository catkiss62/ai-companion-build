package com.aicompanion.localfirst

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/** Independent one-shot expression player with completion fencing for TTS. */
class EmotionSoundBridge(
    context: Context,
    flutterEngine: FlutterEngine,
) {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val ioWorker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "ai-companion-emotion-sound-io").apply { isDaemon = true }
    }
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    private var player: MediaPlayer? = null
    private var pendingResult: MethodChannel.Result? = null
    private var temporaryFile: File? = null
    private var requestToken = 0L
    private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.error("emotion_sound_disposed", "Emotion sound bridge is no longer attached", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "play" -> {
                    val encoded = call.argument<String>("audioData").orEmpty()
                    val volume = (call.argument<Number>("volume")?.toFloat() ?: 1f)
                        .coerceIn(0f, 1f)
                    if (encoded.isBlank()) {
                        result.error("emotion_sound_empty", "Audio payload is empty", null)
                    } else {
                        prepareAndPlay(encoded, volume, result)
                    }
                }
                "stop" -> {
                    requestToken++
                    stopCurrent(completePending = true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun prepareAndPlay(
        encoded: String,
        volume: Float,
        result: MethodChannel.Result,
    ) {
        requestToken++
        val token = requestToken
        stopCurrent(completePending = true)
        pendingResult = result
        try {
            ioWorker.execute {
                val prepared = runCatching {
                    val bytes = Base64.decode(encoded, Base64.DEFAULT)
                    File.createTempFile("emotion-cue-", ".wav", appContext.cacheDir)
                        .also { file ->
                            FileOutputStream(file).use { output -> output.write(bytes) }
                        }
                }
                main.post {
                    if (disposed || token != requestToken) {
                        prepared.getOrNull()?.delete()
                        return@post
                    }
                    prepared.fold(
                        onSuccess = { startPlayer(token, it, volume) },
                        onFailure = {
                            finish(token, "emotion_sound_decode_failed",
                                it.message ?: "Unable to prepare emotion sound")
                        },
                    )
                }
            }
        } catch (_: RejectedExecutionException) {
            finish(token, "emotion_sound_worker_stopped", "Audio worker is unavailable")
        }
    }

    private fun startPlayer(token: Long, file: File, volume: Float) {
        temporaryFile = file
        val next = MediaPlayer()
        player = next
        next.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        next.setVolume(volume, volume)
        next.setOnCompletionListener { finish(token, null, null) }
        next.setOnErrorListener { _, what, extra ->
            finish(token, "emotion_sound_playback_failed",
                "MediaPlayer error what=$what extra=$extra")
            true
        }
        runCatching {
            next.setDataSource(file.absolutePath)
            next.setOnPreparedListener { ready ->
                if (!disposed && token == requestToken) ready.start()
            }
            next.prepareAsync()
        }.onFailure {
            finish(token, "emotion_sound_prepare_failed",
                it.message ?: "Unable to start emotion sound")
        }
    }

    private fun finish(token: Long, code: String?, message: String?) {
        if (token != requestToken) return
        val result = pendingResult
        pendingResult = null
        releasePlayer()
        if (result != null) {
            if (code == null) result.success(null) else result.error(code, message, null)
        }
    }

    private fun stopCurrent(completePending: Boolean) {
        val result = pendingResult
        pendingResult = null
        releasePlayer()
        if (completePending) result?.success(null)
    }

    private fun releasePlayer() {
        val current = player
        player = null
        if (current != null) {
            runCatching { if (current.isPlaying) current.stop() }
            runCatching { current.reset() }
            runCatching { current.release() }
        }
        temporaryFile?.delete()
        temporaryFile = null
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        requestToken++
        stopCurrent(completePending = true)
        channel.setMethodCallHandler(null)
        ioWorker.shutdownNow()
    }

    companion object {
        private const val CHANNEL = "ai_companion/emotion_sound"
    }
}
