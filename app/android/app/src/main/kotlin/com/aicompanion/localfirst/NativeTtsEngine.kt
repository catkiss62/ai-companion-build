package com.aicompanion.localfirst

import android.content.Context
import com.catkiss62.geniettsbenchmark.SystemAudioPolicy
import java.io.File
import java.util.concurrent.locks.ReentrantLock

/** Process-scoped Genie-TTS v0.6.4 binding shared by all Flutter engines. */
class NativeTtsEngine private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val runtime = GenieTtsRuntime(appContext)
    private val player = WavAudioPlayer()
    private val speechLock = ReentrantLock()

    @Volatile private var initialized = false
    @Volatile private var activeLanguage = "zh"
    @Volatile private var speed = 1.0
    @Volatile private var volume = 1.0
    @Volatile private var lastError = ""
    @Volatile private var speechGeneration = 0L
    @Volatile private var verifiedArtifacts = 0

    fun status(): Map<String, Any> = mapOf(
        "available" to runtime.artifactsPresent,
        "initialized" to (initialized && runtime.isReady),
        "engine" to "Genie-TTS v0.6.4 · ONNX Runtime (local)",
        "integrity" to if (verifiedArtifacts > 0) "verified" else "unchecked",
        "artifactCount" to verifiedArtifacts,
        "goldenReference" to "genie-v0.6.4-private-runtime",
        "diagnosticStage" to if (initialized) "frontend_$activeLanguage" else "not_initialized",
        "diagnosticTrace" to listOfNotNull(
            "single_serial_worker",
            if (initialized) "acoustic_models_ready" else null,
            if (initialized) "frontend_$activeLanguage" else null,
        ),
        "detail" to lastError.ifBlank { runtime.statusDetail() },
    )

    fun verifyArtifacts(): Map<String, Any> {
        speechLock.lock()
        try {
            verifiedArtifacts = runtime.verifyPackagedArtifacts()
            lastError = ""
            return status()
        } catch (error: Throwable) {
            verifiedArtifacts = 0
            lastError = error.message ?: error.javaClass.simpleName
            return status().toMutableMap().apply { this["integrity"] = "failed" }
        } finally {
            speechLock.unlock()
        }
    }

    fun initialize(language: String = "zh"): Map<String, Any> {
        speechLock.lock()
        try {
            activeLanguage = normalizeLanguage(language)
            initialized = runtime.initialize(activeLanguage)
            lastError = ""
            return status()
        } catch (error: Throwable) {
            initialized = runtime.isReady
            lastError = error.message ?: error.javaClass.simpleName
            return status()
        } finally {
            speechLock.unlock()
        }
    }

    fun prepareLanguage(language: String): Map<String, Any> {
        speechLock.lock()
        try {
            val next = normalizeLanguage(language)
            if (!initialized) return initialize(next)
            runtime.prepareLanguage(next)
            activeLanguage = next
            lastError = ""
            return status()
        } catch (error: Throwable) {
            initialized = runtime.isReady
            lastError = error.message ?: error.javaClass.simpleName
            return status()
        } finally {
            speechLock.unlock()
        }
    }

    fun importChineseRoberta(path: String): Map<String, Any> {
        speechLock.lock()
        try {
            runtime.importChineseRoberta(File(path))
            lastError = ""
            return status()
        } catch (error: Throwable) {
            initialized = runtime.isReady
            lastError = error.message ?: error.javaClass.simpleName
            throw error
        } finally {
            speechLock.unlock()
        }
    }

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
        if (text.isBlank()) return null
        speechLock.lock()
        try {
            if (generation != generationToken()) return null
            val nextLanguage = normalizeLanguage(language)
            if (!initialized || !runtime.isReady || activeLanguage != nextLanguage) {
                val next = initialize(nextLanguage)
                if (next["initialized"] != true) {
                    error(lastError.ifBlank { "Genie TTS initialization failed" })
                }
            }
            if (generation != generationToken()) return null
            val wav = runtime.generate(
                text = text,
                language = nextLanguage,
                voice = normalizeVoice(voice),
                speed = speed,
                shouldCancel = { generation != generationToken() },
            )
            if (generation != generationToken()) return null
            check(wav.size >= 44) { "Genie TTS returned invalid WAV data" }
            lastError = ""
            return wav
        } catch (error: Throwable) {
            if (generation != generationToken()) return null
            lastError = error.message ?: error.javaClass.simpleName
            RuntimeDiagnosticStore.record(
                appContext,
                "tts",
                "generate",
                "error",
                error.javaClass.simpleName,
                detail = "",
                metadata = mapOf("language" to activeLanguage),
            )
            throw error
        } finally {
            speechLock.unlock()
        }
    }

    fun playAudio(wav: ByteArray, generation: Long = generationToken()) {
        if (wav.isEmpty() || generation != generationToken()) return
        if (SystemAudioPolicy.isSilentOrVibrate(appContext)) return
        player.setVolume(volume.toFloat())
        player.play(wav)
    }

    fun speak(text: String) {
        stop()
        val generation = generationToken()
        val audio = generate(text, generation = generation) ?: return
        playAudio(audio, generation)
    }

    fun stop() {
        synchronized(this) { speechGeneration += 1L }
        player.stop()
    }

    fun pause() = player.pause()
    fun resume() = player.resume()
    fun setSpeed(value: Double) { speed = value.coerceIn(0.5, 2.0) }
    fun setVolume(value: Double) {
        volume = value.coerceIn(0.0, 1.0)
        player.setVolume(volume.toFloat())
    }

    fun release() {
        stop()
        speechLock.lock()
        try {
            runtime.close()
            initialized = false
        } finally {
            speechLock.unlock()
        }
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
