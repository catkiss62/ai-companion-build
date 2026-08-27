package com.aicompanion.localfirst

import android.content.Context
import java.util.concurrent.locks.ReentrantLock

/**
 * Process-scoped local Meju Bert-VITS2/MNN binding.
 *
 * The proven TTS runtime from the supplied APK is isolated behind
 * LegacyTtsRuntime. Chat/UI code never depends on its original package names.
 */
class NativeTtsEngine private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val runtime = LegacyTtsRuntime(appContext)
    private val player = WavAudioPlayer()

    @Volatile
    private var initialized = false

    @Volatile
    private var speed = 1.0

    @Volatile
    private var volume = 1.0

    @Volatile
    private var lastError = ""

    @Volatile
    private var speechGeneration = 0L

    // Multiple FlutterEngines (main, overlay, background) can each own a
    // MethodChannel worker while sharing this process-scoped native runtime.
    // Serialize Bert-VITS/MNN access here, not in any one bridge.
    private val speechLock = ReentrantLock()

    fun status(): Map<String, Any> {
        val integrity = runtime.integrityResult()
        return mapOf(
            "available" to runtime.artifactsPresent,
            "initialized" to (initialized && runtime.isReady()),
            "engine" to "Meju Bert-VITS2 · MNN (local)",
            "integrity" to integrity.state,
            "artifactCount" to integrity.checked,
            "goldenReference" to TtsGoldenBaseline.GOLDEN_REFERENCE,
            "diagnosticStage" to runtime.diagnosticTrace().lastOrNull().orEmpty(),
            "diagnosticTrace" to runtime.diagnosticTrace(),
            "detail" to when {
                !runtime.artifactsPresent -> "TTS runtime/model files are missing"
                integrity.state == "failed" -> integrity.detail
                lastError.isNotBlank() -> lastError
                initialized && runtime.isReady() ->
                    "本地模型已初始化；新版资源已校验；Flutter→Kotlin→Meju runtime→JNI→MNN 链路已绑定"
                integrity.ok -> "新版资源校验通过；模型尚未初始化"
                else -> "TTS 实体已装入；初始化前会先核对新版妹居资源指纹"
            },
        )
    }

    fun verifyArtifacts(): Map<String, Any> {
        speechLock.lock()
        try {
            val result = runtime.verifyArtifacts(force = true)
            if (!result.ok) {
                initialized = false
                lastError = result.detail
                RuntimeDiagnosticStore.record(
                    appContext, "tts", "integrity", "error",
                    "golden_integrity_failed", result.detail,
                    mapOf("count" to result.checked),
                )
            } else {
                if (lastError.startsWith("TTS 资源校验失败")) lastError = ""
                RuntimeDiagnosticStore.record(
                    appContext, "tts", "integrity", "info",
                    "golden_integrity_verified", metadata = mapOf("count" to result.checked),
                )
            }
            return status()
        } finally {
            speechLock.unlock()
        }
    }

    fun initialize(): Map<String, Any> {
        // Explicit initialize() can be invoked from MainActivity, overlay and
        // background FlutterEngines. Serialize it with inference/config calls;
        // LegacyTtsRuntime.initialize() is synchronized internally, but MNN
        // initialization/configuration must also not overlap generateTTS().
        speechLock.lock()
        try {
            val ok = runtime.initialize()
            initialized = ok
            if (ok) {
                RuntimeDiagnosticStore.record(
                    appContext, "tts", "initialize", "info", "jni_mnn_ready",
                )
                // User-facing speed >1 means faster; Bert-VITS length_scale is the
                // inverse concept (larger values make speech longer/slower).
                runtime.setLengthScale((1.0 / speed).toFloat())
                runtime.setSpeakerId(0)
                lastError = ""
            } else {
                lastError = runtime.lastError
                RuntimeDiagnosticStore.record(
                    appContext, "tts", "initialize", "error",
                    "jni_mnn_init_failed", lastError,
                )
            }
            return status()
        } finally {
            speechLock.unlock()
        }
    }


    fun diagnose(): Map<String, Any> {
        speechLock.lock()
        try {
            return try {
                val wav = runtime.diagnoseWavBytes(DIAGNOSTIC_TEXT)
                if (wav.size < 12) error("TTS diagnostic WAV is too short")
                val riff = String(wav, 0, 4, Charsets.US_ASCII)
                val wave = String(wav, 8, 4, Charsets.US_ASCII)
                if (riff != "RIFF" || wave != "WAVE") {
                    error("TTS diagnostic output is not a RIFF/WAVE file")
                }
                runtime.markDiagnosticStage("wav_header")
                initialized = runtime.isReady()
                if (initialized) {
                    runtime.setLengthScale((1.0 / speed).toFloat())
                    runtime.setSpeakerId(0)
                }
                lastError = ""
                RuntimeDiagnosticStore.record(
                    appContext, "tts", "diagnose", "info", "staged_probe_passed",
                    metadata = mapOf("wavBytes" to wav.size),
                )
                status().toMutableMap().apply {
                    this["diagnosticOk"] = true
                    this["wavBytes"] = wav.size
                }
            } catch (t: Throwable) {
                initialized = runtime.isReady()
                lastError = runtime.lastError.ifBlank {
                    "${t.javaClass.simpleName}: ${t.message ?: "TTS diagnostic failed"}"
                }
                RuntimeDiagnosticStore.record(
                    appContext, "tts", "diagnose", "error",
                    "staged_probe_failed",
                    metadata = runtime.failureDiagnosticMetadata(t),
                )
                status().toMutableMap().apply {
                    this["diagnosticOk"] = false
                }
            }
        } finally {
            speechLock.unlock()
        }
    }

    /** Current process-wide speech cancellation epoch. */
    fun generationToken(): Long = synchronized(this) { speechGeneration }

    /**
     * Generate one A2 sentence without touching AudioTrack.
     *
     * Generation remains serialized by speechLock because the legacy MNN
     * runtime is process-scoped. Playback intentionally does not take this lock,
     * allowing sentence N+1 to infer while sentence N is audible.
     */
    fun generate(text: String, generation: Long = generationToken()): ByteArray? {
        if (text.isBlank()) return null
        speechLock.lock()
        try {
            if (generation != generationToken()) return null
            if (!initialized || !runtime.isReady()) {
                val next = initialize()
                if (next["initialized"] != true) {
                    error(lastError.ifBlank { "Local TTS initialization failed" })
                }
            }
            if (generation != generationToken()) return null

            val wav = runtime.generateWavBytes(text)
            if (generation != generationToken()) return null
            if (wav.isEmpty()) error("TTS returned empty WAV data")
            lastError = ""
            return wav
        } catch (t: Throwable) {
            if (generation != generationToken()) return null
            lastError = runtime.lastError.ifBlank {
                "${t.javaClass.simpleName}: ${t.message ?: "TTS failed"}"
            }
            RuntimeDiagnosticStore.record(
                appContext, "tts", "generate", "error",
                t.javaClass.simpleName,
                // Do not persist inference-time text or legacy error bodies.
                detail = "",
                metadata = runtime.failureDiagnosticMetadata(t),
            )
            throw t
        } finally {
            speechLock.unlock()
        }
    }

    /** Play one already-generated WAV; completes after AudioTrack drains. */
    fun playAudio(wav: ByteArray, generation: Long = generationToken()) {
        if (wav.isEmpty() || generation != generationToken()) return
        try {
            if (generation != generationToken()) return
            player.setVolume(volume.toFloat())
            player.play(wav)
            if (generation == generationToken()) lastError = ""
        } catch (t: Throwable) {
            if (generation != generationToken()) return
            lastError = "${t.javaClass.simpleName}: ${t.message ?: "Audio playback failed"}"
            RuntimeDiagnosticStore.record(
                appContext, "tts", "playback", "error",
                t.javaClass.simpleName,
                detail = "",
            )
            throw t
        }
    }

    /** Compatibility one-shot path; normal companion speech uses A2 generate/play. */
    fun speak(text: String) {
        if (text.isBlank()) return
        stop()
        val generation = generationToken()
        val audio = generate(text, generation) ?: return
        if (generation != generationToken()) return
        playAudio(audio, generation)
    }

    fun stop() {
        synchronized(this) { speechGeneration += 1L }
        player.stop()
    }
    fun pause() = player.pause()
    fun resume() = player.resume()

    fun setSpeed(value: Double) {
        val next = value.coerceIn(0.5, 2.0)
        speechLock.lock()
        try {
            speed = next
            if (runtime.isReady()) runtime.setLengthScale((1.0 / speed).toFloat())
        } finally {
            speechLock.unlock()
        }
    }

    fun setVolume(value: Double) {
        volume = value.coerceIn(0.0, 1.0)
        player.setVolume(volume.toFloat())
    }

    fun release() {
        stop()
        speechLock.lock()
        try {
            runtime.release()
            initialized = false
        } finally {
            speechLock.unlock()
        }
    }
    companion object {
        private const val DIAGNOSTIC_TEXT = "你好，我在这里。现在测试本地语音。"

        @Volatile
        private var instance: NativeTtsEngine? = null

        fun shared(context: Context): NativeTtsEngine =
            instance ?: synchronized(this) {
                instance ?: NativeTtsEngine(context.applicationContext).also { instance = it }
            }
    }

}
