package com.aicompanion.localfirst

import android.app.Service
import android.content.Intent
import android.os.IBinder
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/** Owns all Genie/ORT objects in the private :genie_tts process. */
class GenieTtsIsolatedService : Service() {
    private lateinit var runtime: GenieTtsRuntime
    // The verified standalone v0.6.4 app owns Genie from one ordinary Java
    // worker. AIDL arrives on Binder-pool threads, so marshal every engine call
    // onto the same execution shape instead of running ORT on Binder threads.
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "Genie-TTS-worker")
    }
    private val lock = ReentrantLock(true)
    private val generation = AtomicLong(0L)
    private var initialized = false
    private var activeLanguage = "zh"
    private var verifiedArtifacts = 0
    private var stage = "not_initialized"
    private var lastError = ""
    private var lastErrorType = ""
    private var activeInputChars = 0
    private var phoneCount = 0
    private var phoneMin = 0L
    private var phoneMax = 0L
    private var phoneHash = ""
    private var semanticCount = 0
    private var semanticHash = ""
    private var activeVoice = ""
    private var referenceCaseId = ""
    private var inputCharacterClasses = ""
    private var normalizedCharacterClasses = ""
    private var validPhoneCount = 0
    private var decoderIterations = 0
    private var immediateStop = false
    private var pcmDurationMs = 0L
    private var pcmHash = ""
    private var referenceEchoSuspected = false
    private var referenceEchoReason = ""
    private var referenceEchoScore = 0.0
    private var frontendMs = 0L
    private var modelLoadedThisRun = false
    private var modelLoadMs = 0L
    private var fixtureLoadMs = 0L
    private var encoderMs = 0L
    private var firstDecoderMs = 0L
    private var autoregressiveMs = 0L
    private var vocoderMs = 0L
    private var totalInferenceMs = 0L
    private var endToEndMs = 0L
    private var audioSeconds = 0.0
    private var coreRtf = 0.0

    override fun onCreate() {
        super.onCreate()
        runtime = GenieTtsRuntime(applicationContext)
        markStage("service_created", durable = true)
    }

    private val binder = object : IGenieTtsIsolatedService.Stub() {
        override fun statusJson(): String = serialized { statusJsonLocked() }

        override fun verifyArtifactsJson(): String = serialized {
            guardedStatus {
                verifiedArtifacts = runtime.verifyPackagedArtifacts()
                markStage("artifacts_verified")
            }
        }

        override fun initializeJson(language: String): String = serialized {
            guardedStatus { initializeLocked(normalizeLanguage(language)) }
        }

        override fun prepareLanguageJson(language: String): String = serialized {
            guardedStatus {
                val next = normalizeLanguage(language)
                markStage("switch_frontend_$next", durable = true)
                runtime.prepareLanguage(next)
                activeLanguage = next
                initialized = runtime.isReady
                markStage("frontend_ready_$next")
            }
        }

        override fun configureAutoAffinityJson(enabled: Boolean): String = serialized {
            guardedStatus {
                generation.incrementAndGet()
                markStage("configure_runtime", durable = true)
                runtime.configureAutoAffinity(enabled)
                initialized = runtime.isReady
                markStage("runtime_configured", durable = true)
            }
        }

        override fun configureBenchmarkProfileJson(profile: String): String = serialized {
            guardedStatus {
                generation.incrementAndGet()
                runtime.configureBenchmarkProfile(profile)
                initialized = runtime.isReady
                markStage("benchmark_profile_configured")
            }
        }

        override fun importChineseRobertaJson(path: String): String = serialized {
            guardedStatus {
                runtime.importChineseRoberta(File(path))
                markStage("roberta_imported")
            }
        }

        override fun generateToFile(
            text: String,
            language: String,
            voice: String,
            speed: Double,
        ): String = serialized {
            if (text.isBlank()) return@serialized ""
            activeInputChars = text.length
            phoneCount = 0
            phoneMin = 0L
            phoneMax = 0L
            phoneHash = ""
            semanticCount = 0
            semanticHash = ""
            activeVoice = normalizeVoice(voice)
            referenceCaseId = ""
            inputCharacterClasses = TtsDiagnosticEvidence.characterClasses(text)
            normalizedCharacterClasses = ""
            validPhoneCount = 0
            decoderIterations = 0
            immediateStop = false
            pcmDurationMs = 0L
            pcmHash = ""
            referenceEchoSuspected = false
            referenceEchoReason = ""
            referenceEchoScore = 0.0
            frontendMs = 0L
            modelLoadedThisRun = false
            modelLoadMs = 0L
            fixtureLoadMs = 0L
            encoderMs = 0L
            firstDecoderMs = 0L
            autoregressiveMs = 0L
            vocoderMs = 0L
            totalInferenceMs = 0L
            endToEndMs = 0L
            audioSeconds = 0.0
            coreRtf = 0.0
            val requestGeneration = generation.get()
            try {
                val next = normalizeLanguage(language)
                if (!initialized || !runtime.isReady || activeLanguage != next) {
                    initializeLocked(next)
                }
                val wav = runtime.generate(
                    text = text,
                    language = next,
                    voice = activeVoice,
                    shouldCancel = { requestGeneration != generation.get() },
                    onStage = { nextStage, metadata ->
                        phoneCount = (metadata["phoneCount"] as? Number)?.toInt()
                            ?: phoneCount
                        phoneMin = (metadata["phoneMin"] as? Number)?.toLong()
                            ?: phoneMin
                        phoneMax = (metadata["phoneMax"] as? Number)?.toLong()
                            ?: phoneMax
                        phoneHash = metadata["phoneHash"]?.toString() ?: phoneHash
                        semanticCount =
                            (metadata["semanticCount"] as? Number)?.toInt()
                                ?: semanticCount
                        semanticHash =
                            metadata["semanticHash"]?.toString() ?: semanticHash
                        activeVoice = metadata["voice"]?.toString() ?: activeVoice
                        referenceCaseId = metadata["referenceCaseId"]?.toString()
                            ?: referenceCaseId
                        inputCharacterClasses = metadata["inputCharacterClasses"]?.toString()
                            ?: inputCharacterClasses
                        normalizedCharacterClasses = metadata["normalizedCharacterClasses"]?.toString()
                            ?: normalizedCharacterClasses
                        validPhoneCount = (metadata["validPhoneCount"] as? Number)?.toInt()
                            ?: validPhoneCount
                        decoderIterations = (metadata["decoderIterations"] as? Number)?.toInt()
                            ?: decoderIterations
                        immediateStop = metadata["immediateStop"] as? Boolean
                            ?: immediateStop
                        pcmDurationMs = (metadata["pcmDurationMs"] as? Number)?.toLong()
                            ?: pcmDurationMs
                        pcmHash = metadata["pcmHash"]?.toString() ?: pcmHash
                        referenceEchoSuspected = metadata["referenceEchoSuspected"] as? Boolean
                            ?: referenceEchoSuspected
                        referenceEchoReason = metadata["referenceEchoReason"]?.toString()
                            ?: referenceEchoReason
                        referenceEchoScore = (metadata["referenceEchoScore"] as? Number)?.toDouble()
                            ?: referenceEchoScore
                        frontendMs = (metadata["frontendMs"] as? Number)?.toLong() ?: frontendMs
                        modelLoadedThisRun = metadata["modelLoadedThisRun"] as? Boolean
                            ?: modelLoadedThisRun
                        modelLoadMs = (metadata["modelLoadMs"] as? Number)?.toLong() ?: modelLoadMs
                        fixtureLoadMs = (metadata["fixtureLoadMs"] as? Number)?.toLong() ?: fixtureLoadMs
                        encoderMs = (metadata["encoderMs"] as? Number)?.toLong() ?: encoderMs
                        firstDecoderMs = (metadata["firstDecoderMs"] as? Number)?.toLong()
                            ?: firstDecoderMs
                        autoregressiveMs = (metadata["autoregressiveMs"] as? Number)?.toLong()
                            ?: autoregressiveMs
                        vocoderMs = (metadata["vocoderMs"] as? Number)?.toLong() ?: vocoderMs
                        totalInferenceMs = (metadata["totalInferenceMs"] as? Number)?.toLong()
                            ?: totalInferenceMs
                        endToEndMs = (metadata["endToEndMs"] as? Number)?.toLong() ?: endToEndMs
                        audioSeconds = (metadata["audioSeconds"] as? Number)?.toDouble()
                            ?: audioSeconds
                        coreRtf = (metadata["coreRtf"] as? Number)?.toDouble() ?: coreRtf
                        markStage(
                            nextStage,
                            durable = nextStage.startsWith("prepare_frontend_") ||
                                nextStage == "load_acoustic_models" ||
                                nextStage.startsWith("infer_"),
                        )
                    },
                )
                if (requestGeneration != generation.get()) return@serialized ""
                check(wav.size >= 44) { "Genie TTS returned invalid WAV data" }
                val directory = File(cacheDir, "genie-tts-ipc").apply { mkdirs() }
                directory.listFiles()?.filter { it.isFile && it.lastModified() < System.currentTimeMillis() - 3_600_000L }
                    ?.forEach { it.delete() }
                val output = File(directory, "${UUID.randomUUID()}.wav")
                output.outputStream().use { it.write(wav) }
                markStage("wav_ready", durable = true)
                lastError = ""
                lastErrorType = ""
                output.absolutePath
            } catch (error: Throwable) {
                lastError = error.message ?: error.javaClass.simpleName
                lastErrorType = error.javaClass.simpleName
                markStage("generate_failed", error.javaClass.simpleName, durable = true)
                throw error
            }
        }

        override fun stop() {
            generation.incrementAndGet()
            markStage("generation_cancelled")
        }

        override fun releaseRuntime() = serialized {
            generation.incrementAndGet()
            runtime.close()
            runtime = GenieTtsRuntime(applicationContext)
            initialized = false
            stage = "not_initialized"
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onDestroy() {
        generation.incrementAndGet()
        runCatching { serialized { runtime.close() } }
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun <T> serialized(block: () -> T): T =
        worker.submit(Callable { lock.withLock(block) }).get()

    private fun initializeLocked(language: String) {
        activeLanguage = language
        markStage("initialize_frontend_$language", durable = true)
        initialized = runtime.initialize(language)
        check(initialized) { "Genie TTS initialization failed" }
        markStage("frontend_ready_$language")
    }

    private inline fun guardedStatus(block: () -> Unit): String {
        return try {
            block()
            lastError = ""
            lastErrorType = ""
            statusJsonLocked()
        } catch (error: Throwable) {
            initialized = runtime.isReady
            lastError = error.message ?: error.javaClass.simpleName
            lastErrorType = error.javaClass.simpleName
            markStage("operation_failed", error.javaClass.simpleName, durable = true)
            statusJsonLocked()
        }
    }

    private fun statusJsonLocked(): String = JSONObject()
        .put("available", runtime.artifactsPresent)
        .put("initialized", initialized && runtime.isReady)
        .put("engine", "Genie-TTS v0.7.6 core · 小酒狐 · isolated ONNX Runtime")
        .put("integrity", if (verifiedArtifacts > 0) "verified" else "unchecked")
        .put("artifactCount", verifiedArtifacts)
        .put("goldenReference", "918a26bf55d7e06dffd08277c6a4bcb703f5b17b")
        .put("diagnosticStage", stage)
        .put("diagnosticCode", lastErrorType)
        .put("diagnosticTrace", JSONArray(listOf("private_process", "single_serial_owner", stage)))
        .put("runtimeProfile", runtime.runtimeProfileId)
        .put("autoAffinityEnabled", runtime.runtimeProfileId == "auto_affinity_v084" ||
            runtime.runtimeProfileId == "auto_decoder_fixed_vocoder_v1")
        .put("detail", lastError.ifBlank { runtime.statusDetail() })
        .toString()

    private fun markStage(next: String, failure: String = "", durable: Boolean = false) {
        stage = next
        TtsProcessCheckpoint.write(
            applicationContext,
            stage = next,
            failure = failure,
            language = activeLanguage,
            modelsReady = runtime.acousticModelsReady,
            runtimeProfile = runtime.runtimeProfileId,
            inputChars = activeInputChars,
            phoneCount = phoneCount,
            phoneMin = phoneMin,
            phoneMax = phoneMax,
            phoneHash = phoneHash,
            semanticCount = semanticCount,
            semanticHash = semanticHash,
            voice = activeVoice,
            referenceCaseId = referenceCaseId,
            inputCharacterClasses = inputCharacterClasses,
            normalizedCharacterClasses = normalizedCharacterClasses,
            validPhoneCount = validPhoneCount,
            decoderIterations = decoderIterations,
            immediateStop = immediateStop,
            pcmDurationMs = pcmDurationMs,
            pcmHash = pcmHash,
            referenceEchoSuspected = referenceEchoSuspected,
            referenceEchoReason = referenceEchoReason,
            referenceEchoScore = referenceEchoScore,
            frontendMs = frontendMs,
            modelLoadedThisRun = modelLoadedThisRun,
            modelLoadMs = modelLoadMs,
            fixtureLoadMs = fixtureLoadMs,
            encoderMs = encoderMs,
            firstDecoderMs = firstDecoderMs,
            autoregressiveMs = autoregressiveMs,
            vocoderMs = vocoderMs,
            totalInferenceMs = totalInferenceMs,
            endToEndMs = endToEndMs,
            audioSeconds = audioSeconds,
            coreRtf = coreRtf,
        )
    }

    private fun normalizeLanguage(value: String) =
        value.takeIf { it == "zh" || it == "ja" || it == "en" } ?: "zh"

    private fun normalizeVoice(value: String) =
        value.takeIf { it == "daily" || it == "gentle" || it == "lively" || it == "cute" }
            ?: "daily"
}
