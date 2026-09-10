package com.aicompanion.localfirst

import android.content.Context
import com.catkiss62.geniettsbenchmark.SystemAudioPolicy
import java.io.File

/** Process-scoped bridge to the isolated Genie/Tiandou runtime plus main-process playback. */
class NativeTtsEngine private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val client = IsolatedGenieTtsClient(appContext)
    private val player = WavAudioPlayer()

    @Volatile private var activeLanguage = "zh"
    @Volatile private var speed = 1.0
    @Volatile private var pitch = 1.0
    @Volatile private var volume = 1.0
    @Volatile private var speechGeneration = 0L

    fun status(): Map<String, Any> = try {
        client.status().toMutableMap().apply {
            this["processIsolation"] = "private_process"
            val checkpoint = TtsProcessCheckpoint.read(appContext)
            if (checkpoint.isNotEmpty()) this["lastProcessCheckpoint"] = checkpoint
        }
    } catch (error: Throwable) {
        failureStatus(error)
    }

    fun verifyArtifacts(): Map<String, Any> = client.verifyArtifacts()

    fun initialize(language: String = "zh"): Map<String, Any> {
        activeLanguage = normalizeLanguage(language)
        return client.initialize(activeLanguage).also {
            recordUnreadyStatus(it, "initialize_failed", activeLanguage)
        }
    }

    fun prepareLanguage(language: String): Map<String, Any> {
        activeLanguage = normalizeLanguage(language)
        return client.prepareLanguage(activeLanguage).also {
            recordUnreadyStatus(it, "frontend_switch_failed", activeLanguage)
        }
    }

    fun importChineseRoberta(path: String): Map<String, Any> = client.importChineseRoberta(path)

    fun diagnose(language: String = "zh"): Map<String, Any> {
        val normalized = normalizeLanguage(language)
        val text = when (normalized) {
            "en" -> "I am right here with you."
            "ja" -> "ここにいるよ。"
            else -> "你好，我在这里。"
        }
        return try {
            val wav = generate(text, normalized, "daily")
            status().toMutableMap().apply {
                this["diagnosticOk"] = wav != null && wav.size >= 44
                this["wavBytes"] = wav?.size ?: 0
            }
        } catch (_: Throwable) {
            status().toMutableMap().apply { this["diagnosticOk"] = false }
        }
    }

    fun generationToken(): Long = synchronized(this) { speechGeneration }

    fun generate(
        text: String,
        language: String = activeLanguage,
        voice: String = "daily",
        generation: Long = generationToken(),
    ): ByteArray? {
        if (text.isBlank() || generation != generationToken()) return null
        val nextLanguage = normalizeLanguage(language)
        activeLanguage = nextLanguage
        val path = try {
            client.generateToFile(
                text = text,
                language = nextLanguage,
                voice = normalizeVoice(voice),
                speed = speed,
            )
        } catch (error: Throwable) {
            val checkpoint = TtsProcessCheckpoint.read(appContext)
            RuntimeDiagnosticStore.record(
                appContext,
                category = "tts",
                phase = "generation_failed",
                severity = "error",
                code = error.javaClass.simpleName,
                metadata = mapOf(
                    "language" to nextLanguage,
                    "stage" to checkpoint["stage"],
                ),
                durable = true,
            )
            throw error
        }
        if (path.isBlank() || generation != generationToken()) {
            if (path.isNotBlank()) File(path).delete()
            return null
        }
        val output = File(path)
        return try {
            check(output.isFile) { "Genie TTS 子进程未返回音频文件" }
            output.readBytes().also {
                check(it.size >= 44) { "Genie TTS returned invalid WAV data" }
            }
        } finally {
            output.delete()
        }
    }

    fun beginAudioStream(generation: Long = generationToken()) {
        if (generation != generationToken()) return
        if (SystemAudioPolicy.isSilentOrVibrate(appContext)) {
            player.stop()
            return
        }
        player.setSpeed(speed.toFloat())
        player.setPitch(pitch.toFloat())
        player.setVolume(volume.toFloat())
        player.beginStream {
            RuntimeDiagnosticStore.record(
                appContext,
                category = "tts",
                phase = "audio_playback",
                metadata = mapOf("stage" to "audio_playback"),
                durable = true,
            )
        }
    }

    fun enqueueAudio(wav: ByteArray, generation: Long = generationToken()) {
        if (wav.isEmpty() || generation != generationToken()) return
        player.enqueueStream(wav)
    }

    fun finishAudioStream(generation: Long = generationToken()) {
        if (generation != generationToken()) return
        val played = player.finishStream()
        if (!played || generation != generationToken()) return
        RuntimeDiagnosticStore.record(
            appContext,
            category = "tts",
            phase = "audio_complete",
            metadata = mapOf("stage" to "audio_complete"),
        )
    }

    fun speak(text: String) {
        stop()
        val generation = generationToken()
        val audio = generate(text, generation = generation) ?: return
        beginAudioStream(generation)
        enqueueAudio(audio, generation)
        finishAudioStream(generation)
    }

    fun stop() {
        synchronized(this) { speechGeneration += 1L }
        client.stop()
        player.stop()
    }

    fun pause() = player.pause()
    fun resume() = player.resume()
    fun setSpeed(value: Double) {
        speed = value.coerceIn(0.5, 2.0)
        player.setSpeed(speed.toFloat())
    }
    fun setPitch(value: Double) {
        pitch = value.coerceIn(0.5, 2.0)
        player.setPitch(pitch.toFloat())
    }
    fun setVolume(value: Double) {
        volume = value.coerceIn(0.0, 2.0)
        player.setVolume(volume.toFloat())
    }

    fun release() {
        stop()
        client.releaseRuntime()
    }

    private fun failureStatus(error: Throwable): Map<String, Any> = mapOf(
        "available" to false,
        "initialized" to false,
        "engine" to "Genie-TTS v0.6.4 core · 恬豆 · isolated ONNX Runtime",
        "integrity" to "unknown",
        "artifactCount" to 0,
        "goldenReference" to "918a26bf55d7e06dffd08277c6a4bcb703f5b17b",
        "diagnosticStage" to "child_process_unavailable",
        "diagnosticTrace" to listOf("private_process", "child_process_unavailable"),
        "detail" to (error.message ?: error.javaClass.simpleName),
        "processIsolation" to "private_process",
        "lastProcessCheckpoint" to TtsProcessCheckpoint.read(appContext),
    )

    private fun recordUnreadyStatus(
        status: Map<String, Any>,
        phase: String,
        language: String,
    ) {
        if (status["initialized"] == true) return
        RuntimeDiagnosticStore.record(
            appContext,
            category = "tts",
            phase = phase,
            severity = "error",
            code = status["diagnosticCode"]?.toString()?.ifBlank {
                "not_initialized"
            } ?: "not_initialized",
            metadata = mapOf(
                "language" to language,
                "stage" to status["diagnosticStage"],
            ),
            durable = true,
        )
    }

    private fun normalizeLanguage(value: String) =
        value.takeIf { it == "zh" || it == "ja" || it == "en" } ?: "zh"

    private fun normalizeVoice(value: String) =
        value.takeIf { it == "daily" || it == "gentle" || it == "lively" || it == "cute" }
            ?: "daily"

    companion object {
        @Volatile private var instance: NativeTtsEngine? = null

        fun shared(context: Context): NativeTtsEngine =
            instance ?: synchronized(this) {
                instance ?: NativeTtsEngine(context.applicationContext).also { instance = it }
            }
    }
}
