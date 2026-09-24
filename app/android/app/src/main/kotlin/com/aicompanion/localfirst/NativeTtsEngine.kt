package com.aicompanion.localfirst

import android.content.Context
import com.catkiss62.geniettsbenchmark.SystemAudioPolicy
import java.io.File
import java.security.MessageDigest
import android.os.PowerManager

/** Process-scoped bridge to the isolated Genie/Jiuhu runtime plus main-process playback. */
class NativeTtsEngine private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val client = IsolatedGenieTtsClient(appContext)
    private val player = WavAudioPlayer()

    @Volatile private var activeLanguage = "zh"
    @Volatile private var speed = 1.0
    @Volatile private var pitch = 1.0
    @Volatile private var volume = 1.0
    @Volatile private var speechGeneration = 0L
    private val sessionLock = Any()
    private var activeSession: TtsSessionPerformance? = null
    private var activeSessionGeneration = -1L
    private var activePlaybackCompleted = false

    fun status(): Map<String, Any> = try {
        client.status().toMutableMap().apply {
            this["processIsolation"] = "private_process"
            val checkpoint = TtsProcessCheckpoint.read(appContext)
            if (checkpoint.isNotEmpty()) this["lastProcessCheckpoint"] = checkpoint
        }
    } catch (error: Throwable) {
        failureStatus(error)
    }

    /** Fast packaged-resource probe in the main process; never binds the child. */
    fun localStatus(): Map<String, Any> {
        val packaged = runCatching {
            appContext.assets.open("benchmark/manifest.json").use { true }
        }.getOrDefault(false)
        return mapOf(
            "available" to packaged,
            "initialized" to false,
            "engine" to "Genie-TTS v0.7.6 core · 小酒狐 · isolated ONNX Runtime",
            "integrity" to "unchecked",
            "diagnosticStage" to "packaged_asset_check",
            "runtimeProfile" to "not_started",
            "detail" to if (packaged) "本机资源存在，子进程未在快速自检中启动"
                else "APK 中没有 Genie TTS 资源",
        )
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

    fun configureAutoAffinity(enabled: Boolean): Map<String, Any> {
        val current = runCatching { client.status() }.getOrNull()
        if (current != null && current["autoAffinityEnabled"] == enabled &&
            current["runtimeProfile"] != "auto_decoder_fixed_vocoder_v1") return current
        stop()
        return client.configureAutoAffinity(enabled)
    }

    fun configureHybridVocoder(): Map<String, Any> {
        val current = runCatching { client.status() }.getOrNull()
        if (current?.get("runtimeProfile") == "auto_decoder_fixed_vocoder_v1") return current
        stop()
        return client.configureBenchmarkProfile("hybrid")
    }

    /** Explicit, silent benchmark. The production playback path stays untouched. */
    fun benchmark(profile: String, segments: List<Map<String, String>>): Map<String, Any> {
        require(profile == "auto" || profile == "hybrid") { "未知 TTS 对照档" }
        require(segments.isNotEmpty() && segments.size <= 32) { "测试片段数无效" }
        val oldStatus = client.status()
        val oldAffinity = oldStatus["autoAffinityEnabled"] == true
        val oldHybrid = oldStatus["runtimeProfile"] == "auto_decoder_fixed_vocoder_v1"
        stop()
        val items = mutableListOf<Map<String, Any?>>()
        val started = System.nanoTime()
        val thermal = (appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager)
            ?.currentThermalStatus ?: -1
        try {
            val configured = client.configureBenchmarkProfile(profile, diagnostic = true)
            val expectedProfile = if (profile == "hybrid")
                "auto_decoder_fixed_vocoder_v1" else "auto_affinity_v084"
            check(configured["runtimeProfile"] == expectedProfile) {
                "TTS 测试配置没有生效：$profile"
            }
            for ((index, segment) in segments.withIndex()) {
                val text = segment["text"].orEmpty()
                require(text.isNotBlank() && text.length <= 500) { "测试片段为空或过长" }
                val language = normalizeLanguage(segment["language"].orEmpty())
                val voice = normalizeVoice(segment["voice"].orEmpty())
                val segmentStarted = System.nanoTime()
                var failure = ""
                var bytes = 0L
                try {
                    val path = client.generateToFile(text, language, voice, speed)
                    val file = File(path)
                    bytes = file.length()
                    check(bytes >= 44) { "WAV 数据无效" }
                    file.delete()
                } catch (error: Throwable) {
                    failure = error.javaClass.simpleName
                }
                val checkpoint = TtsProcessCheckpoint.read(appContext)
                items += mapOf(
                    "index" to index,
                    "characters" to text.length,
                    "sha256" to sha256(text.trim()),
                    "language" to language,
                    "voice" to voice,
                    "durationMs" to ((System.nanoTime() - segmentStarted) / 1_000_000L),
                    "wavBytes" to bytes,
                    "failure" to failure,
                    "frontendMs" to checkpoint["frontendMs"],
                    "modelLoadMs" to checkpoint["modelLoadMs"],
                    "encoderMs" to checkpoint["encoderMs"],
                    "firstDecoderMs" to checkpoint["firstDecoderMs"],
                    "autoregressiveMs" to checkpoint["autoregressiveMs"],
                    "vocoderMs" to checkpoint["vocoderMs"],
                    "totalInferenceMs" to checkpoint["totalInferenceMs"],
                    "audioSeconds" to checkpoint["audioSeconds"],
                )
            }
            return mapOf(
                "profile" to profile,
                "thermalBefore" to thermal,
                "thermalAfter" to ((appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager)
                    ?.currentThermalStatus ?: -1),
                "elapsedMs" to ((System.nanoTime() - started) / 1_000_000L),
                "segments" to items,
                "complete" to items.all { (it["failure"] as String).isEmpty() },
            )
        } finally {
            if (oldHybrid) client.configureBenchmarkProfile("hybrid")
            else client.configureAutoAffinity(oldAffinity)
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

    fun beginSession(manual: Boolean, generation: Long = generationToken()) {
        if (generation != generationToken()) return
        // Detailed stage timing is collected only by the explicit silent test.
    }

    fun finishSession(generation: Long = generationToken()) {
        synchronized(sessionLock) {
            if (generation != activeSessionGeneration) return
            finalizeSessionLocked(
                stopped = false,
                completedAtEpochMs = System.currentTimeMillis(),
                completedAtNs = System.nanoTime(),
            )
        }
    }

    fun generate(
        text: String,
        language: String = activeLanguage,
        voice: String = "daily",
        segmentIndex: Int = -1,
        generation: Long = generationToken(),
    ): ByteArray? {
        if (text.isBlank() || generation != generationToken()) return null
        val generationStartedNs = System.nanoTime()
        val nextLanguage = normalizeLanguage(language)
        activeLanguage = nextLanguage
        val normalizedVoice = normalizeVoice(voice)
        val textHash = sha256(text.trim())
        val path = try {
            client.generateToFile(
                text = text,
                language = nextLanguage,
                voice = normalizedVoice,
                speed = speed,
            )
        } catch (error: Throwable) {
            val checkpoint = TtsProcessCheckpoint.read(appContext)
            recordSessionSegment(
                generation = generation,
                segmentIndex = segmentIndex,
                inputChars = text.length,
                textHash = textHash,
                language = nextLanguage,
                voice = normalizedVoice,
                checkpoint = checkpoint,
                generationCallMs = elapsedMs(generationStartedNs),
                failureCode = error.javaClass.simpleName,
            )
            RuntimeDiagnosticStore.record(
                appContext,
                category = "tts",
                phase = "generation_failed",
                severity = "error",
                code = error.javaClass.simpleName,
                metadata = mapOf(
                    "language" to nextLanguage,
                    "voice" to normalizedVoice,
                    "segmentIndex" to segmentIndex,
                    "inputChars" to text.length,
                    "textSha256" to textHash,
                    "stage" to checkpoint["stage"],
                    "failureType" to checkpoint["failure"],
                    "runtimeProfile" to checkpoint["runtimeProfile"],
                    "phoneCount" to checkpoint["phoneCount"],
                    "phoneMin" to checkpoint["phoneMin"],
                    "phoneMax" to checkpoint["phoneMax"],
                    "phoneHash" to checkpoint["phoneHash"],
                    "semanticCount" to checkpoint["semanticCount"],
                    "semanticHash" to checkpoint["semanticHash"],
                    "referenceCaseId" to checkpoint["referenceCaseId"],
                    "inputCharacterClasses" to checkpoint["inputCharacterClasses"],
                    "normalizedCharacterClasses" to checkpoint["normalizedCharacterClasses"],
                    "validPhoneCount" to checkpoint["validPhoneCount"],
                    "decoderIterations" to checkpoint["decoderIterations"],
                    "immediateStop" to checkpoint["immediateStop"],
                    "pcmDurationMs" to checkpoint["pcmDurationMs"],
                    "pcmHash" to checkpoint["pcmHash"],
                    "referenceEchoSuspected" to checkpoint["referenceEchoSuspected"],
                    "referenceEchoReason" to checkpoint["referenceEchoReason"],
                    "referenceEchoScore" to checkpoint["referenceEchoScore"],
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
            synchronized(sessionLock) {
                if (generation == activeSessionGeneration) {
                    activeSession?.recordPlaybackStarted(System.nanoTime())
                }
            }
            RuntimeDiagnosticStore.record(
                appContext,
                category = "tts",
                phase = "audio_playback",
                metadata = mapOf("stage" to "audio_playback"),
                durable = true,
            )
        }
    }

    fun enqueueAudio(
        wav: ByteArray,
        speedMultiplier: Double = 1.0,
        segmentIndex: Int = -1,
        generation: Long = generationToken(),
    ) {
        if (wav.isEmpty() || generation != generationToken()) return
        val effectiveSpeed = (speed * speedMultiplier).coerceIn(0.5, 2.0)
        synchronized(sessionLock) {
            if (generation == activeSessionGeneration) {
                activeSession?.recordEnqueued(
                    segmentIndex = segmentIndex,
                    playbackSpeed = effectiveSpeed,
                    atNs = System.nanoTime(),
                )
            }
        }
        player.enqueueStream(
            wav,
            effectiveSpeed.toFloat(),
        )
    }

    fun finishAudioStream(generation: Long = generationToken()) {
        if (generation != generationToken()) return
        val played = player.finishStream()
        if (!played || generation != generationToken()) return
        synchronized(sessionLock) {
            if (generation == activeSessionGeneration) activePlaybackCompleted = true
        }
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
        enqueueAudio(audio, generation = generation)
        finishAudioStream(generation)
    }

    fun stop() {
        synchronized(this) { speechGeneration += 1L }
        synchronized(sessionLock) {
            finalizeSessionLocked(
                stopped = true,
                completedAtEpochMs = System.currentTimeMillis(),
                completedAtNs = System.nanoTime(),
            )
        }
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
        "engine" to "Genie-TTS v0.7.6 core · 小酒狐 · isolated ONNX Runtime",
        "integrity" to "unknown",
        "artifactCount" to 0,
        "goldenReference" to "918a26bf55d7e06dffd08277c6a4bcb703f5b17b",
        "diagnosticStage" to "child_process_unavailable",
        "diagnosticTrace" to listOf("private_process", "child_process_unavailable"),
        "runtimeProfile" to "unknown",
        "autoAffinityEnabled" to false,
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

    private fun sha256(value: String): String = MessageDigest
        .getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { byte -> "%02x".format(byte) }

    private fun recordSessionSegment(
        generation: Long,
        segmentIndex: Int,
        inputChars: Int,
        textHash: String,
        language: String,
        voice: String,
        checkpoint: Map<String, Any>,
        generationCallMs: Long,
        failureCode: String = "",
    ) {
        synchronized(sessionLock) {
            if (generation != activeSessionGeneration) return
            activeSession?.recordSegment(
                segmentIndex = segmentIndex,
                inputChars = inputChars,
                textSha256 = textHash,
                language = language,
                voice = voice,
                checkpoint = checkpoint,
                generationCallMs = generationCallMs,
                failureCode = failureCode,
                readyAtNs = System.nanoTime(),
            )
        }
    }

    private fun finalizeSessionLocked(
        stopped: Boolean,
        completedAtEpochMs: Long,
        completedAtNs: Long,
    ) {
        val session = activeSession ?: return
        val summary = session.finish(
            stopped = stopped,
            playbackCompleted = activePlaybackCompleted,
            completedAtEpochMs = completedAtEpochMs,
            completedAtNs = completedAtNs,
        )
        TtsSessionDiagnosticStore.append(appContext, summary)
        activeSession = null
        activeSessionGeneration = -1L
        activePlaybackCompleted = false
    }

    private fun elapsedMs(startNs: Long): Long =
        (System.nanoTime() - startNs).coerceAtLeast(0L) / 1_000_000L

    companion object {
        @Volatile private var instance: NativeTtsEngine? = null

        fun shared(context: Context): NativeTtsEngine =
            instance ?: synchronized(this) {
                instance ?: NativeTtsEngine(context.applicationContext).also { instance = it }
            }
    }
}
