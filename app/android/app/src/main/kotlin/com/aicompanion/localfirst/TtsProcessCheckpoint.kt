package com.aicompanion.localfirst

import android.content.Context
import android.os.Debug
import android.os.Process
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File

/** A tiny cross-process crash breadcrumb. It never stores input text or filesystem paths. */
object TtsProcessCheckpoint {
    private const val FILE_NAME = "genie_tts_process_checkpoint.json"

    @Synchronized
    fun write(
        context: Context,
        stage: String,
        failure: String = "",
        language: String = "",
        modelsReady: Boolean = false,
        inputChars: Int = 0,
    ) {
        runCatching {
            val payload = JSONObject()
                .put("at", System.currentTimeMillis())
                .put("stage", DiagnosticRedaction.safeToken(stage, 96))
                .put("failure", DiagnosticRedaction.safeToken(failure, 96))
                .put("processId", Process.myPid())
                .put("language", DiagnosticRedaction.safeToken(language, 8))
                .put("modelsReady", modelsReady)
                .put("inputChars", inputChars.coerceAtLeast(0))
                .put("pssKb", Debug.getPss())
                .put("rssKb", currentRssKb())
                .put("threads", currentThreadCount())
                .toString()
                .toByteArray(Charsets.UTF_8)
            val atomic = AtomicFile(File(context.noBackupFilesDir, FILE_NAME))
            val output = atomic.startWrite()
            try {
                output.write(payload)
                atomic.finishWrite(output)
            } catch (error: Throwable) {
                atomic.failWrite(output)
                throw error
            }
        }
    }

    fun read(context: Context): Map<String, Any> = runCatching {
        val file = File(context.noBackupFilesDir, FILE_NAME)
        if (!file.isFile) return@runCatching emptyMap()
        val value = JSONObject(file.readText())
        mapOf(
            "at" to value.optLong("at", 0L),
            "stage" to value.optString("stage", "unknown"),
            "failure" to value.optString("failure", ""),
            "processId" to value.optInt("processId", 0),
            "language" to value.optString("language", ""),
            "modelsReady" to value.optBoolean("modelsReady", false),
            "inputChars" to value.optInt("inputChars", 0),
            "pssKb" to value.optInt("pssKb", 0),
            "rssKb" to value.optInt("rssKb", 0),
            "threads" to value.optInt("threads", 0),
        )
    }.getOrDefault(emptyMap())

    private fun currentRssKb(): Int = runCatching {
        File("/proc/self/status").useLines { lines ->
            lines.firstOrNull { it.startsWith("VmRSS:") }
                ?.split(Regex("\\s+"))
                ?.getOrNull(1)
                ?.toIntOrNull()
                ?: 0
        }
    }.getOrDefault(0)

    private fun currentThreadCount(): Int = runCatching {
        File("/proc/self/status").useLines { lines ->
            lines.firstOrNull { it.startsWith("Threads:") }
                ?.substringAfter(':')
                ?.trim()
                ?.toIntOrNull()
                ?: 0
        }
    }.getOrDefault(0)
}
