package com.aicompanion.localfirst

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject

/** Durable occurrence journal. UI/notifications never own or reset an alarm's time. */
object CalendarReminderRuntime {
    const val FIVE_MINUTES = 300_000L
    const val QUIET_AFTER = 600_000L
    private const val KEY = "occurrences_v2"
    private fun prefs(context: Context) = context.getSharedPreferences("calendar_reminders_v1", Context.MODE_PRIVATE)
    private fun load(context: Context): MutableList<JSONObject> {
        val json = runCatching { JSONArray(prefs(context).getString(KEY,"[]")) }.getOrElse { JSONArray() }
        return (0 until json.length()).mapNotNull(json::optJSONObject).toMutableList()
    }
    private fun save(context: Context, items: List<JSONObject>) {
        // Never evict a ringing occurrence. Terminal history is bounded.
        val keep = items.filter { it.optString("status") == "ringing" } +
            items.filter { it.optString("status") != "ringing" }.takeLast(100)
        check(prefs(context).edit().putString(KEY,JSONArray(keep).toString())
            .putLong("runtime_sequence",prefs(context).getLong("runtime_sequence",0)+1).commit())
    }
    @Synchronized fun start(context: Context, id: String, due: Long, title: String,
        now: Long = System.currentTimeMillis(), elapsed: Long = SystemClock.elapsedRealtime(), schedule: String = ""): Boolean {
        val items = load(context)
        val occurrence = "$id:$due"
        if(items.any { it.optString("occurrence") == occurrence }) return false
        items.add(JSONObject().put("id",id).put("occurrence",occurrence).put("title",title)
            .put("scheduledAt",due).put("startedAt",now).put("deadlineAt",now+FIVE_MINUTES)
            .put("deadlineElapsed",elapsed+FIVE_MINUTES).put("startedElapsed",elapsed)
            .put("status","ringing").put("delivery","pending").put("schedule",schedule))
        save(context,items); return true
    }
    @Synchronized fun expire(context: Context, now: Long = System.currentTimeMillis(),
        elapsed: Long = SystemClock.elapsedRealtime()): Boolean {
        val items = load(context); var changed = false
        for(item in items) if(item.optString("status") == "ringing") {
            val sameBoot = elapsed >= item.optLong("startedElapsed")
            val expired = if(sameBoot) elapsed >= item.optLong("deadlineElapsed") else now >= item.optLong("deadlineAt")
            if(expired) {
                val stopped = if(sameBoot) now-(elapsed-item.optLong("deadlineElapsed")) else item.optLong("deadlineAt")
                item.put("status","timed_out").put("stoppedAt",stopped).put("timedOutAt",stopped)
                changed = true
            }
        }
        if(changed) save(context,items)
        return changed
    }
    @Synchronized fun confirm(context: Context, occurrence: String,
        now: Long = System.currentTimeMillis(), elapsed: Long = SystemClock.elapsedRealtime()): Boolean {
        expire(context,now,elapsed)
        val items=load(context); val item=items.firstOrNull { it.optString("occurrence")==occurrence } ?: return false
        if(item.optBoolean("retired") || item.optString("status") !in setOf("ringing","timed_out","interrupted")) return false
        if(item.optString("status")=="ringing") item.put("stoppedAt",now)
        item.put("status","confirmed").put("confirmedAt",now)
        save(context,items);return true
    }
    @Synchronized fun interrupt(context: Context, now: Long = System.currentTimeMillis()) {
        val items=load(context)
        for(item in items) if(item.optString("status")=="ringing")
            item.put("status","interrupted").put("stoppedAt",now)
        save(context,items)
    }
    @Synchronized fun reconcile(context: Context, reset: Boolean, valid: (JSONObject)->Boolean) {
        val items=if(reset) mutableListOf() else load(context)
        val now=System.currentTimeMillis()
        for(item in items) if(!valid(item)) {
            if(item.optString("status")=="ringing") item.put("stoppedAt",now).put("status","cancelled")
            item.put("retired",true).put("delivery","cancelled")
        }
        save(context,items)
    }
    @Synchronized fun markDelivery(context: Context, occurrence: String, outcome: String, revision: String? = null) {
        if(revision != null && revision != prefs(context).getString("revision", "")) return
        if(outcome !in setOf("delivered","cancelled")) return
        val items=load(context)
        items.firstOrNull { it.optString("occurrence")==occurrence }?.let {
            if(it.optString("delivery")=="pending") it.put("delivery",outcome)
        }
        save(context,items)
    }
    @Synchronized fun records(context: Context): List<JSONObject> = load(context)
    @Synchronized fun snapshot(context: Context): Map<String,Any> = mapOf(
        "revision" to prefs(context).getString("revision","").orEmpty(),
        "sequence" to prefs(context).getLong("runtime_sequence",0),
        "records" to records(context).map { item -> item.keys().asSequence().associateWith { item.get(it) } },
    )
    fun remaining(item: JSONObject, elapsed: Long = SystemClock.elapsedRealtime(), now: Long = System.currentTimeMillis()): Long =
        (if(elapsed >= item.optLong("startedElapsed")) item.optLong("deadlineElapsed")-elapsed
        else item.optLong("deadlineAt")-now).coerceIn(0,FIVE_MINUTES)
}
