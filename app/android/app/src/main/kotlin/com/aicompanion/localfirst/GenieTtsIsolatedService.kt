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
            val requestGeneration = generation.get()
            try {
                val next = normalizeLanguage(language)
                if (!initialized || !runtime.isReady || activeLanguage != next) {
                    initializeLocked(next)
                }
                val wav = runtime.generate(
                    text = text,
                    language = next,
                    voice = normalizeVoice(voice),
                    shouldCancel = { requestGeneration != generation.get() },
                    onStage = { nextStage ->
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
        .put("engine", "Genie-TTS v0.6.4 · isolated ONNX Runtime")
        .put("integrity", if (verifiedArtifacts > 0) "verified" else "unchecked")
        .put("artifactCount", verifiedArtifacts)
        .put("goldenReference", "5380a536f83aeaec540a9aaa7982149969c73e26")
        .put("diagnosticStage", stage)
        .put("diagnosticCode", lastErrorType)
        .put("diagnosticTrace", JSONArray(listOf("private_process", "single_serial_owner", stage)))
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
            inputChars = activeInputChars,
        )
    }

    private fun normalizeLanguage(value: String) =
        value.takeIf { it == "zh" || it == "ja" || it == "en" } ?: "zh"

    private fun normalizeVoice(value: String) =
        value.takeIf { it == "daily" || it == "gentle" || it == "lively" || it == "cute" }
            ?: "daily"
}
