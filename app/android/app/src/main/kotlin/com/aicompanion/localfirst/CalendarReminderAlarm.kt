package com.aicompanion.localfirst

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.time.DateTimeException
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/** Local calendar alarm mirror. No model, chat, or private event text in logs. */
object CalendarReminderAlarm {
    private const val PREFS = "calendar_reminders_v1"
    private const val ENTRIES = "entries"
    private const val STOPS = "pending_stops"
    private const val CHANNEL = "companion_calendar_alarm_v1"
    private const val ACTION_FIRE = "com.aicompanion.localfirst.calendar.FIRE"
    private const val ACTION_TIMEOUT = "com.aicompanion.localfirst.calendar.TIMEOUT"
    const val EXTRA_ID = "calendar_id"
    const val EXTRA_TITLE = "calendar_title"
    const val EXTRA_REVISION = "calendar_revision"
    const val EXTRA_OCCURRENCE = "calendar_occurrence"
    const val FIVE_MINUTES = CalendarReminderRuntime.FIVE_MINUTES
    private val listeners = java.util.concurrent.CopyOnWriteArraySet<() -> Unit>()
    fun addListener(listener: () -> Unit) { listeners.add(listener) }
    fun removeListener(listener: () -> Unit) { listeners.remove(listener) }
    private fun changed(context: Context) {
        CalendarReminderRingingService.refreshIfRunning(context)
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            listeners.forEach { runCatching { it() } }
        }
        OverlayBubbleService.requestBrainWake(context, "calendar_reminder_changed")
    }
    fun state(context: Context): Map<String, Any> {
        if(CalendarReminderRuntime.expire(context)) changed(context)
        return CalendarReminderRuntime.snapshot(context)
    }
    fun confirm(context: Context, occurrence: String) {
        if(CalendarReminderRuntime.confirm(context, occurrence)) changed(context)
    }
    fun openCard(context: Context, occurrence: String = "") {
        context.startActivity(Intent(context, CalendarReminderAlertActivity::class.java)
            .putExtra(EXTRA_OCCURRENCE, occurrence).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP))
    }
    fun presentationStatus(context: Context): Map<String,Boolean> = mapOf(
        "overlay" to Settings.canDrawOverlays(context),
        "fullScreen" to (Build.VERSION.SDK_INT < 34 || context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()))
    fun openPresentationSettings(context: Context, kind: String) {
        val action = if(kind == "fullScreen" && Build.VERSION.SDK_INT >= 34)
            "android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT" else Settings.ACTION_MANAGE_OVERLAY_PERMISSION
        context.startActivity(Intent(action, Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun openExactSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !canScheduleExact(context)) {
            context.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:${context.packageName}")
            })
        }
    }

    fun openSoundSettings(context: Context) {
        channel(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL)
            })
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun entries(context: Context): JSONArray = try {
        JSONArray(prefs(context).getString(ENTRIES, "[]"))
    } catch (_: Exception) {
        JSONArray()
    }

    @Synchronized
    fun replaceAll(context: Context, raw: List<Map<String, Any?>>, revision: String = ""): Boolean {
        val old = entries(context)
        val fresh = JSONArray()
        for (item in raw.take(500)) {
            val id = item["id"]?.toString().orEmpty()
            val title = item["title"]?.toString().orEmpty().trim().take(80)
            if (id.isBlank() || title.isBlank()) continue
            val entry = JSONObject().apply {
                put("id", id)
                put("title", title)
                put("year", (item["year"] as? Number)?.toInt() ?: 0)
                put("month", (item["month"] as? Number)?.toInt() ?: 0)
                put("day", (item["day"] as? Number)?.toInt() ?: 0)
                put("yearly", item["yearly"] == true)
                put("repeat", item["repeat"]?.toString() ?: if(item["yearly"] == true) "yearly" else "once")
                put("enabled", item["enabled"] != false)
                put("weekdays", JSONArray((item["weekdays"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt()?.takeIf { it in 1..7 } } ?: emptyList<Int>()))
                if (item["hour"] is Number && item["minute"] is Number) {
                    put("hour", (item["hour"] as Number).toInt())
                    put("minute", (item["minute"] as Number).toInt())
                }
            }
            fresh.put(entry)
        }
        val previousRevision = prefs(context).getString("revision", "").orEmpty()
        if (fresh.toString() == old.toString() && previousRevision == revision &&
            prefs(context).getBoolean("scheduled", false)) return true
        val replacedState = previousRevision.isNotEmpty() && previousRevision != revision
        val validIds = (0 until fresh.length()).mapNotNull(fresh::optJSONObject).associateBy { it.optString("id") }
        CalendarReminderRuntime.reconcile(context, replacedState) { event ->
            val entry = validIds[event.optString("id")]
            entry != null && entry.optString("title") == event.optString("title") &&
                matchesOccurrence(entry,event.optLong("scheduledAt")) &&
                (event.optString("schedule").isEmpty() || event.optString("schedule") == entry.toString())
        }
        val stops = emptyList<Map<String,Any?>>()
        // Commit the new scheduling truth before cancelling/replacing alarms.
        check(prefs(context).edit().putString(ENTRIES, fresh.toString())
            .putString("revision", revision).putBoolean("scheduled", false)
            .putString(STOPS, JSONArray(stops).toString()).commit()) { "无法保存提醒镜像" }
        for (index in 0 until old.length()) {
            val id = old.optJSONObject(index)?.optString("id").orEmpty()
            if (id.isNotEmpty()) cancelFire(context, id)
        }
        var success = true
        for (index in 0 until fresh.length()) {
            val entry = fresh.optJSONObject(index) ?: continue
            if (entry.has("hour") && !schedule(context, entry)) success = false
        }
        prefs(context).edit().putBoolean("scheduled", success).commit()
        changed(context)
        return success
    }

    private fun rule(entry: JSONObject) = CalendarReminderSchedule(
        entry.optInt("year"), entry.optInt("month"), entry.optInt("day"),
        entry.optInt("hour",-1), entry.optInt("minute",-1),
        entry.optString("repeat",if(entry.optBoolean("yearly")) "yearly" else "once"),
        entry.optJSONArray("weekdays")?.let { days -> (0 until days.length()).map { days.optInt(it) }.toSet() } ?: emptySet(),
        entry.optBoolean("enabled",true))
    private fun matchesOccurrence(entry: JSONObject, due: Long) = rule(entry).matches(due)
    private fun dueAt(entry: JSONObject, after: Long) = rule(entry).next(after)

    private fun intent(context: Context, id: String, action: String, due: Long = 0L): PendingIntent {
        val operation = Intent(context, CalendarReminderReceiver::class.java).apply {
            this.action = action
            data = Uri.parse("companion-reminder://$action/${Uri.encode(id)}")
            putExtra(EXTRA_ID, id)
            putExtra("due", due)
        }
        return PendingIntent.getBroadcast(
            context, id.hashCode() xor action.hashCode(), operation,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cancelFire(context: Context, id: String) {
        context.getSystemService(AlarmManager::class.java)
            .cancel(intent(context, id, ACTION_FIRE))
    }

    private fun schedule(context: Context, entry: JSONObject, after: Long = System.currentTimeMillis()): Boolean {
        val due = dueAt(entry, after) ?: return true
        val manager = context.getSystemService(AlarmManager::class.java)
        val operation = intent(context, entry.optString("id"), ACTION_FIRE, due)
        return runCatching {
            if (canScheduleExact(context)) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
            } else {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
            }
            true
        }.getOrDefault(false)
    }

    fun restore(context: Context) {
        val all = entries(context)
        for (index in 0 until all.length()) {
            all.optJSONObject(index)?.let { if (it.has("hour")) schedule(context, it) }
        }
    }

    fun recoverInterruptedRing(context: Context) {
        CalendarReminderRuntime.interrupt(context)
        prefs(context).edit().remove("ringing").remove("ringing_title").remove(STOPS).commit()
        changed(context)
    }

    @Synchronized
    fun fire(context: Context, id: String, due: Long) {
        val all=entries(context)
        val entry=(0 until all.length()).mapNotNull(all::optJSONObject).firstOrNull { it.optString("id")==id } ?: return
        if(!matchesOccurrence(entry,due)) return
        val now=System.currentTimeMillis()
        if(due <= 0 || due > now+60_000L || now-due > 12L*60*60*1000) return
        // Repetition belongs to the system, independently of acknowledgement or AI.
        if(rule(entry).repeat != "once") schedule(context,entry,due+1000L)
        if(!CalendarReminderRuntime.start(context,id,due,entry.optString("title"),now,schedule=entry.toString())) return
        val manager=context.getSystemService(AlarmManager::class.java)
        val timeout=intent(context,id,ACTION_TIMEOUT,due)
        runCatching {
            if(canScheduleExact(context)) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,now+FIVE_MINUTES,timeout)
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,now+FIVE_MINUTES,timeout)
        }
        val alert=Intent(context,CalendarReminderRingingService::class.java).setAction(CalendarReminderRingingService.START)
        runCatching {
            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(alert)
            else context.startService(alert)
        }.onFailure { CalendarReminderRuntime.interrupt(context) }
        changed(context)
    }

    @Synchronized
    fun timeout(context: Context, id: String, due: Long) {
        // Expiration checks each original deadline, never a later occurrence by ID.
        if(CalendarReminderRuntime.records(context).none { it.optString("occurrence")=="$id:$due" }) return
        if(CalendarReminderRuntime.expire(context)) changed(context)
    }

    fun pendingStops(context: Context): List<Map<String,Any?>> = emptyList()
    fun acknowledgeStop(context: Context, occurrence: String) =
        CalendarReminderRuntime.markDelivery(context,occurrence,"delivered")

    fun channel(context: Context): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "代办响铃提醒", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "由你手写的定时事项到点响铃；声音和振动可在系统设置中调整"
                    setSound(null, null) // The ringing service controls the five-minute loop.
                    enableVibration(false)
                },
            )
        }
        return CHANNEL
    }

    fun ringingSound(context: Context): Uri =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java)
                .getNotificationChannel(channel(context))?.sound
                ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
        } else {
            android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
        }
}

class CalendarReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val id = intent?.getStringExtra(CalendarReminderAlarm.EXTRA_ID).orEmpty()
        if (id.isEmpty()) return
        when (intent?.action) {
            "com.aicompanion.localfirst.calendar.FIRE" ->
                CalendarReminderAlarm.fire(context, id, intent.getLongExtra("due", 0L))
            "com.aicompanion.localfirst.calendar.TIMEOUT" ->
                CalendarReminderAlarm.timeout(context, id, intent.getLongExtra("due", 0L))
        }
    }
}
