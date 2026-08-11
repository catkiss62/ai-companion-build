package com.aicompanion.localfirst

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Small bounded, redacted native diagnostic ring.
 *
 * This store must never contain relationship/chat/reference plaintext, API
 * secrets, raw notification/accessibility text, full device ids, endpoint ids,
 * snapshot ids, lineages or filesystem paths. It exists only to explain real
 * Android/TTS/Nearby failures during the first device checkpoint.
 */
object RuntimeDiagnosticStore {
    private const val PREFS = "companion_runtime_diagnostics"
    private const val KEY_EVENTS = "events_v1"
    private const val MAX_EVENTS = 160
    private const val MAX_AGE_MS = 30L * 24L * 60L * 60L * 1000L

    @Synchronized
    fun record(
        context: Context,
        category: String,
        phase: String,
        severity: String = "info",
        code: String = "",
        detail: String = "",
        metadata: Map<String, Any?> = emptyMap(),
    ) {
        runCatching {
            val now = System.currentTimeMillis()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val existing = runCatching { JSONArray(prefs.getString(KEY_EVENTS, "[]") ?: "[]") }
                .getOrDefault(JSONArray())
            val kept = JSONArray()
            val minTime = now - MAX_AGE_MS
            val start = (existing.length() - (MAX_EVENTS - 1)).coerceAtLeast(0)
            for (i in start until existing.length()) {
                val item = existing.optJSONObject(i) ?: continue
                if (item.optLong("at", 0L) >= minTime) kept.put(item)
            }
            val safeMetadata = JSONObject()
            metadata.forEach { (key, value) ->
                when (key) {
                    "generation", "sourceGeneration", "targetActivationGeneration",
                    "payloadBytes", "totalBytes", "sdk", "count" -> if (value is Number) safeMetadata.put(key, value)
                    "direction", "operation", "transport", "state" -> safeMetadata.put(key, DiagnosticRedaction.safeToken(value?.toString().orEmpty(), 48))
                    "endpointId", "snapshotId", "lineageId", "sourceDeviceId", "targetDeviceId", "stateSha256" -> {
                        if (!value?.toString().isNullOrBlank()) safeMetadata.put("${key}Fp", DiagnosticRedaction.fingerprint(value.toString()))
                    }
                }
            }
            kept.put(
                JSONObject()
                    .put("at", now)
                    .put("category", DiagnosticRedaction.safeToken(category, 32))
                    .put("phase", DiagnosticRedaction.safeToken(phase, 64))
                    .put("severity", DiagnosticRedaction.safeToken(severity, 16))
                    .put("code", DiagnosticRedaction.safeToken(code, 80))
                    .put("detail", DiagnosticRedaction.sanitizeDetail(detail))
                    .put("metadata", safeMetadata),
            )
            while (kept.length() > MAX_EVENTS) kept.remove(0)
            prefs.edit().putString(KEY_EVENTS, kept.toString()).apply()
        }
    }

    fun recordNearby(context: Context, type: String, extra: Map<String, Any?>) {
        // Discovery can emit dozens of endpoint churn events. Keep the durable
        // ring phase-oriented so one scan cannot evict the failure that matters.
        if (type == "endpointFound" || type == "endpointLost") return
        val severity = when {
            type.contains("failed", true) || type.contains("error", true) -> "error"
            type.contains("rejected", true) || type.contains("lost", true) || type == "disconnected" -> "warn"
            else -> "info"
        }
        val code = when {
            extra["reason"] != null -> extra["reason"].toString()
            extra["operation"] != null -> extra["operation"].toString()
            extra["status"] is Number -> "status_${extra["status"]}"
            extra["status"] in setOf(
                "empty_endpoint", "payload_too_large", "file_not_found",
                "invalid_snapshot_metadata", "invalid_control_size",
            ) -> extra["status"].toString()
            extra.containsKey("status") -> "transport_status_error"
            else -> type
        }
        val safeMeta = HashMap<String, Any?>()
        for (key in listOf(
            "endpointId", "snapshotId", "lineageId", "sourceDeviceId", "targetDeviceId", "stateSha256",
            "sourceGeneration", "targetActivationGeneration", "payloadBytes", "totalBytes", "operation", "direction",
        )) {
            if (extra.containsKey(key)) safeMeta[key] = extra[key]
        }
        record(
            context,
            category = "nearby",
            phase = type,
            severity = severity,
            code = code,
            metadata = safeMeta,
        )
    }

    @Synchronized
    fun snapshot(context: Context, limit: Int = 120): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = runCatching { JSONArray(prefs.getString(KEY_EVENTS, "[]") ?: "[]") }
            .getOrDefault(JSONArray())
        val safeLimit = limit.coerceIn(1, MAX_EVENTS)
        val start = (array.length() - safeLimit).coerceAtLeast(0)
        val minTime = System.currentTimeMillis() - MAX_AGE_MS
        val result = ArrayList<Map<String, Any?>>()
        for (i in start until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            if (obj.optLong("at", 0L) < minTime) continue
            val metaObj = obj.optJSONObject("metadata") ?: JSONObject()
            val meta = HashMap<String, Any?>()
            val keys = metaObj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                meta[key] = metaObj.opt(key)?.takeUnless { it == JSONObject.NULL }
            }
            result += mapOf(
                "at" to obj.optLong("at", 0L),
                "category" to obj.optString("category"),
                "phase" to obj.optString("phase"),
                "severity" to obj.optString("severity"),
                "code" to obj.optString("code"),
                "detail" to obj.optString("detail"),
                "metadata" to meta,
            )
        }
        return result
    }

    @Synchronized
    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_EVENTS).apply()
    }

}
