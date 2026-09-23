package com.aicompanion.localfirst

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import kotlin.math.round

/** Redacted per-segment timing captured at generation time, never at export time. */
internal data class TtsSegmentPerformance(
    val index: Int,
    val inputChars: Int,
    val textSha256: String,
    val language: String,
    val voice: String,
    val outcome: String,
    val failureCode: String,
    val runtimeProfile: String,
    val modelLoadedThisRun: Boolean,
    val frontendMs: Long,
    val modelLoadMs: Long,
    val fixtureLoadMs: Long,
    val encoderMs: Long,
    val firstDecoderMs: Long,
    val autoregressiveMs: Long,
    val vocoderMs: Long,
    val totalInferenceMs: Long,
    val endToEndMs: Long,
    val generationCallMs: Long,
    val decoderIterations: Int,
    val semanticCount: Int,
    val audioDurationMs: Long,
    val coreRtf: Double,
    val readyAtNs: Long,
    var enqueued: Boolean = false,
    var playbackSpeed: Double = 1.0,
    var readyToEnqueueMs: Long? = null,
) {
    fun diagnostic(): Map<String, Any?> = linkedMapOf(
        "segmentIndex" to index,
        "inputChars" to inputChars,
        "textSha256" to textSha256,
        "language" to language,
        "voice" to voice,
        "outcome" to outcome,
        "failureCode" to failureCode,
        "runtimeProfile" to runtimeProfile,
        "modelState" to if (modelLoadedThisRun) "cold" else "warm",
        "frontendMs" to frontendMs,
        "modelLoadMs" to modelLoadMs,
        "fixtureLoadMs" to fixtureLoadMs,
        "encoderMs" to encoderMs,
        "firstDecoderMs" to firstDecoderMs,
        "autoregressiveMs" to autoregressiveMs,
        "vocoderMs" to vocoderMs,
        "totalInferenceMs" to totalInferenceMs,
        "endToEndMs" to endToEndMs,
        "generationCallMs" to generationCallMs,
        "decoderIterations" to decoderIterations,
        "semanticCount" to semanticCount,
        "audioDurationMs" to audioDurationMs,
        "coreRtf" to rounded(coreRtf),
        "enqueued" to enqueued,
        "playbackSpeed" to rounded(playbackSpeed),
        "readyToEnqueueMs" to readyToEnqueueMs,
    )
}

/** Aggregates one whole scheduler utterance, including partial and stopped runs. */
internal class TtsSessionPerformance(
    private val generation: Long,
    private val manual: Boolean,
    private val requestedRuntimeProfile: String,
    private val startedAtEpochMs: Long,
    private val startedAtNs: Long,
) {
    private val segments = linkedMapOf<Int, TtsSegmentPerformance>()
    private var firstReadyAtNs: Long? = null
    private var playbackStartedAtNs: Long? = null
    private var cumulativeQueuedPlaybackMs = 0.0
    private var minimumEstimatedBufferMs: Double? = null
    private var lateSegments = 0

    fun recordSegment(
        segmentIndex: Int,
        inputChars: Int,
        textSha256: String,
        language: String,
        voice: String,
        checkpoint: Map<String, Any>,
        generationCallMs: Long,
        failureCode: String = "",
        readyAtNs: Long,
    ) {
        val rejectedNoSemantics = checkpoint.boolean("immediateStop") &&
            checkpoint.int("semanticCount") == 0
        val outcome = when {
            rejectedNoSemantics -> "rejected_no_generated_semantics"
            failureCode.isNotBlank() -> "failed"
            else -> "ready"
        }
        segments[segmentIndex] = TtsSegmentPerformance(
            index = segmentIndex,
            inputChars = inputChars.coerceAtLeast(0),
            textSha256 = textSha256,
            language = language,
            voice = voice,
            outcome = outcome,
            failureCode = failureCode,
            runtimeProfile = checkpoint.string("runtimeProfile").ifBlank {
                requestedRuntimeProfile
            },
            modelLoadedThisRun = checkpoint.boolean("modelLoadedThisRun"),
            frontendMs = checkpoint.long("frontendMs"),
            modelLoadMs = checkpoint.long("modelLoadMs"),
            fixtureLoadMs = checkpoint.long("fixtureLoadMs"),
            encoderMs = checkpoint.long("encoderMs"),
            firstDecoderMs = checkpoint.long("firstDecoderMs"),
            autoregressiveMs = checkpoint.long("autoregressiveMs"),
            vocoderMs = checkpoint.long("vocoderMs"),
            totalInferenceMs = checkpoint.long("totalInferenceMs"),
            endToEndMs = checkpoint.long("endToEndMs"),
            generationCallMs = generationCallMs.coerceAtLeast(0L),
            decoderIterations = checkpoint.int("decoderIterations"),
            semanticCount = checkpoint.int("semanticCount"),
            audioDurationMs = checkpoint.long("pcmDurationMs"),
            coreRtf = checkpoint.double("coreRtf"),
            readyAtNs = readyAtNs,
        )
        if (outcome == "ready" && firstReadyAtNs == null) firstReadyAtNs = readyAtNs
    }

    fun recordPlaybackStarted(atNs: Long) {
        if (playbackStartedAtNs == null) playbackStartedAtNs = atNs
    }

    fun recordEnqueued(segmentIndex: Int, playbackSpeed: Double, atNs: Long) {
        val segment = segments[segmentIndex] ?: return
        segment.enqueued = true
        segment.playbackSpeed = playbackSpeed.coerceIn(0.5, 2.0)
        segment.readyToEnqueueMs = elapsedMs(segment.readyAtNs, atNs)
        val playbackStart = playbackStartedAtNs
        if (playbackStart != null) {
            val elapsedPlaybackMs = (atNs - playbackStart).coerceAtLeast(0L) / 1_000_000.0
            val bufferBeforeMs = cumulativeQueuedPlaybackMs - elapsedPlaybackMs
            minimumEstimatedBufferMs = minimumEstimatedBufferMs?.coerceAtMost(bufferBeforeMs)
                ?: bufferBeforeMs
            if (bufferBeforeMs < 0.0) lateSegments += 1
        }
        cumulativeQueuedPlaybackMs += segment.audioDurationMs / segment.playbackSpeed
    }

    fun finish(
        stopped: Boolean,
        playbackCompleted: Boolean,
        completedAtEpochMs: Long,
        completedAtNs: Long,
    ): Map<String, Any?> {
        val ordered = segments.values.sortedBy { it.index }
        val ready = ordered.count { it.outcome == "ready" }
        val failed = ordered.size - ready
        val outcome = when {
            stopped -> "stopped"
            ready == 0 && failed > 0 -> "failed"
            ready > 0 && failed > 0 -> "partial"
            ready > 0 -> "completed"
            else -> "empty"
        }
        val profiles = ordered.map { it.runtimeProfile }.filter { it.isNotBlank() }.distinct()
        val runtimeProfile = when {
            profiles.size == 1 -> profiles.single()
            profiles.isEmpty() -> requestedRuntimeProfile.ifBlank { "unknown" }
            else -> "mixed"
        }
        val totalInferenceMs = ordered.sumOf { it.totalInferenceMs }
        val audioDurationMs = ordered.sumOf { it.audioDurationMs }
        val utteranceFingerprint = sha256(
            ordered.joinToString("|") { "${it.index}:${it.textSha256}" },
        )
        val workloadFingerprint = sha256(
            ordered.joinToString("|") {
                "${it.index}:${it.textSha256}:${it.language}:${it.voice}"
            },
        )
        return linkedMapOf(
            "schema" to 1,
            "sessionId" to "$startedAtEpochMs-$generation",
            "generation" to generation,
            "startedAt" to startedAtEpochMs,
            "completedAt" to completedAtEpochMs,
            "manual" to manual,
            "outcome" to outcome,
            "playbackCompleted" to playbackCompleted,
            "runtimeProfile" to runtimeProfile,
            "runtimeConfig" to runtimeConfig(runtimeProfile),
            "utteranceSha256" to utteranceFingerprint,
            "workloadSha256" to workloadFingerprint,
            "totalInputChars" to ordered.sumOf { it.inputChars },
            "segmentsAttempted" to ordered.size,
            "segmentsReady" to ready,
            "segmentsFailed" to failed,
            "segmentsEnqueued" to ordered.count { it.enqueued },
            "coldSegments" to ordered.count { it.modelLoadedThisRun },
            "modelLoadMs" to ordered.sumOf { it.modelLoadMs },
            "frontendMs" to ordered.sumOf { it.frontendMs },
            "fixtureLoadMs" to ordered.sumOf { it.fixtureLoadMs },
            "encoderMs" to ordered.sumOf { it.encoderMs },
            "firstDecoderMs" to ordered.sumOf { it.firstDecoderMs },
            "autoregressiveMs" to ordered.sumOf { it.autoregressiveMs },
            "vocoderMs" to ordered.sumOf { it.vocoderMs },
            "totalInferenceMs" to totalInferenceMs,
            "generationCallMs" to ordered.sumOf { it.generationCallMs },
            "audioDurationMs" to audioDurationMs,
            "aggregateRtf" to rounded(
                if (audioDurationMs > 0L) totalInferenceMs.toDouble() / audioDurationMs else 0.0,
            ),
            "firstSegmentReadyMs" to firstReadyAtNs?.let { elapsedMs(startedAtNs, it) },
            "firstPlaybackStartMs" to playbackStartedAtNs?.let { elapsedMs(startedAtNs, it) },
            "sessionElapsedMs" to elapsedMs(startedAtNs, completedAtNs),
            "minimumEstimatedBufferMs" to minimumEstimatedBufferMs?.let(::rounded),
            "lateSegmentCount" to lateSegments,
            "segments" to ordered.map { it.diagnostic() },
        )
    }

    private fun elapsedMs(startNs: Long, endNs: Long): Long =
        (endNs - startNs).coerceAtLeast(0L) / 1_000_000L
}

internal object TtsPerformanceComparison {
    fun compare(sessions: List<Map<String, Any?>>): Map<String, Any?> {
        if (sessions.size < 2) return mapOf("comparable" to false, "reason" to "need_two_sessions")
        val older = sessions[sessions.size - 2]
        val newer = sessions.last()
        if (older["utteranceSha256"] != newer["utteranceSha256"]) {
            return mapOf("comparable" to false, "reason" to "different_utterance")
        }
        if (older["workloadSha256"] != newer["workloadSha256"]) {
            return mapOf("comparable" to false, "reason" to "different_voice_or_language")
        }
        if (older["outcome"] != "completed" || newer["outcome"] != "completed" ||
            older["playbackCompleted"] != true || newer["playbackCompleted"] != true
        ) {
            return mapOf("comparable" to false, "reason" to "incomplete_session")
        }
        val olderProfile = older["runtimeProfile"]?.toString().orEmpty()
        val newerProfile = newer["runtimeProfile"]?.toString().orEmpty()
        if (olderProfile == newerProfile || "mixed" in setOf(olderProfile, newerProfile)) {
            return mapOf("comparable" to false, "reason" to "profiles_not_distinct")
        }
        val legacy = listOf(older, newer).firstOrNull {
            it["runtimeProfile"] == "legacy_fixed_8"
        }
        val affinity = listOf(older, newer).firstOrNull {
            it["runtimeProfile"] == "auto_affinity_v084"
        }
        if (legacy == null || affinity == null) {
            return mapOf("comparable" to false, "reason" to "expected_profiles_missing")
        }
        val legacyMs = (legacy["totalInferenceMs"] as? Number)?.toDouble() ?: 0.0
        val affinityMs = (affinity["totalInferenceMs"] as? Number)?.toDouble() ?: 0.0
        if (legacyMs <= 0.0 || affinityMs <= 0.0) {
            return mapOf("comparable" to false, "reason" to "incomplete_inference")
        }
        return linkedMapOf(
            "comparable" to true,
            "utteranceSha256" to older["utteranceSha256"],
            "legacyTotalInferenceMs" to legacyMs.toLong(),
            "autoAffinityTotalInferenceMs" to affinityMs.toLong(),
            "autoAffinitySpeedupPercent" to rounded((legacyMs - affinityMs) / legacyMs * 100.0),
            "legacyAggregateRtf" to legacy["aggregateRtf"],
            "autoAffinityAggregateRtf" to affinity["aggregateRtf"],
        )
    }
}

/** Persistent ring of exactly the last two complete TTS session attempts. */
object TtsSessionDiagnosticStore {
    private const val PREFS = "tts_session_diagnostics"
    private const val KEY_SESSIONS = "sessions_v1"
    private const val MAX_SESSIONS = 2

    @Synchronized
    fun append(context: Context, summary: Map<String, Any?>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = runCatching {
            JSONArray(prefs.getString(KEY_SESSIONS, "[]") ?: "[]")
        }
            .getOrDefault(JSONArray())
        val kept = JSONArray()
        val start = (existing.length() - (MAX_SESSIONS - 1)).coerceAtLeast(0)
        for (index in start until existing.length()) {
            existing.optJSONObject(index)?.let { kept.put(it) }
        }
        kept.put(JSONObject(summary))
        prefs.edit().putString(KEY_SESSIONS, kept.toString()).commit()
    }

    @Synchronized
    fun snapshot(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val stored = runCatching {
            JSONArray(prefs.getString(KEY_SESSIONS, "[]") ?: "[]")
        }
            .getOrDefault(JSONArray())
        val sessions = buildList {
            for (index in 0 until stored.length()) {
                stored.optJSONObject(index)?.let { add(it.toMap()) }
            }
        }
        return linkedMapOf(
            "schema" to 1,
            "retainedSessions" to sessions.size,
            "sessions" to sessions,
            "comparison" to TtsPerformanceComparison.compare(sessions),
        )
    }

    @Synchronized
    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_SESSIONS)
            .apply()
    }

    private fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
        when (val value = opt(key)) {
            JSONObject.NULL -> null
            is JSONObject -> value.toMap()
            is JSONArray -> value.toList()
            else -> value
        }
    }

    private fun JSONArray.toList(): List<Any?> = buildList {
        for (index in 0 until length()) {
            add(
                when (val value = opt(index)) {
                    JSONObject.NULL -> null
                    is JSONObject -> value.toMap()
                    is JSONArray -> value.toList()
                    else -> value
                },
            )
        }
    }
}

private fun Map<String, Any>.string(key: String): String = get(key)?.toString().orEmpty()
private fun Map<String, Any>.long(key: String): Long = (get(key) as? Number)?.toLong() ?: 0L
private fun Map<String, Any>.int(key: String): Int = (get(key) as? Number)?.toInt() ?: 0
private fun Map<String, Any>.double(key: String): Double = (get(key) as? Number)?.toDouble() ?: 0.0
private fun Map<String, Any>.boolean(key: String): Boolean = get(key) as? Boolean ?: false
private fun rounded(value: Double): Double = round(value * 1000.0) / 1000.0
private fun runtimeConfig(profile: String): Map<String, Any?> = when (profile) {
    "auto_affinity_v084" -> linkedMapOf(
        "backend" to "CPU_EP",
        "acousticSessionCount" to 4,
        "chineseRobertaSessionCount" to 1,
        "intraOpThreads" to 0,
        "interOpThreads" to 1,
        "executionMode" to "SEQUENTIAL",
        "graphOptimization" to "ALL_OPT",
        "intraOpSpinning" to true,
        "interOpSpinning" to true,
        "memoryPattern" to "ORT_DEFAULT",
    )
    "legacy_fixed_8" -> linkedMapOf(
        "backend" to "CPU_EP",
        "acousticSessionCount" to 4,
        "chineseRobertaSessionCount" to 1,
        "acousticIntraOpThreads" to 8,
        "chineseRobertaIntraOpThreads" to Runtime.getRuntime()
            .availableProcessors()
            .coerceAtLeast(1),
        "interOpThreads" to 1,
        "executionMode" to "DEFAULT",
        "graphOptimization" to "ALL_OPT",
        "intraOpSpinning" to "ORT_DEFAULT",
        "interOpSpinning" to "ORT_DEFAULT",
        "memoryPattern" to "ORT_DEFAULT",
    )
    else -> mapOf("profile" to profile.ifBlank { "unknown" })
}
private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
    .digest(value.toByteArray(Charsets.UTF_8))
    .joinToString("") { byte -> "%02x".format(byte) }
