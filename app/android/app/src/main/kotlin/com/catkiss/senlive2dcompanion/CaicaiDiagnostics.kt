package com.catkiss.senlive2dcompanion

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Local model import/render milestones, exported with device diagnostics. */
object CaicaiDiagnostics {
    private const val PREFS = "caicai_live2d_diagnostics"
    private const val KEY = "events"

    @Synchronized fun record(context: Context, stage: String, detail: String = "") {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = runCatching { JSONArray(prefs.getString(KEY, "[]").orEmpty()) }.getOrDefault(JSONArray())
        val result = JSONArray()
        for (i in (existing.length() - 39).coerceAtLeast(0) until existing.length()) {
            result.put(existing.get(i))
        }
        result.put(JSONObject().put("at", System.currentTimeMillis())
            .put("stage", stage).put("detail", detail.take(if (stage == "motion_plan_applied" || stage == "render_error") 12000 else 1000)))
        prefs.edit().putString(KEY, result.toString()).apply()
    }

    @Synchronized fun events(context: Context): List<Map<String, Any>> {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val entries = runCatching { JSONArray(prefs.getString(KEY, "[]").orEmpty()) }.getOrDefault(JSONArray())
        return (0 until entries.length()).mapNotNull { i ->
            entries.optJSONObject(i)?.let {
                mapOf("at" to it.optLong("at"), "stage" to it.optString("stage"),
                    "detail" to it.optString("detail"))
            }
        }
    }
}
