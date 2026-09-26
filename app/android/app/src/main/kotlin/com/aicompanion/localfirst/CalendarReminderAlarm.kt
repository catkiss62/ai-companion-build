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
    const val EXTRA_OCCURRENCE = "calendar_occurrence"
    const val FIVE_MINUTES = 5L * 60L * 1000L

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

    fun replaceAll(context: Context, raw: List<Map<String, Any?>>): Boolean {
        val old = entries(context)
        for (index in 0 until old.length()) {
            val id = old.optJSONObject(index)?.optString("id").orEmpty()
            if (id.isNotEmpty()) cancelFire(context, id)
        }
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
                if (item["hour"] is Number && item["minute"] is Number) {
                    put("hour", (item["hour"] as Number).toInt())
                    put("minute", (item["minute"] as Number).toInt())
                }
            }
            fresh.put(entry)
        }
        // Commit the full mirror before scheduling. Reboot/update can restore it.
        prefs(context).edit().putString(ENTRIES, fresh.toString()).commit()
        var success = true
        for (index in 0 until fresh.length()) {
            val entry = fresh.optJSONObject(index) ?: continue
            if (entry.has("hour") && !schedule(context, entry)) success = false
        }
        return success
    }

    private fun dueAt(entry: JSONObject, after: Long): Long? {
        val year = entry.optInt("year")
        val month = entry.optInt("month")
        val day = entry.optInt("day")
        val hour = entry.optInt("hour", -1)
        val minute = entry.optInt("minute", -1)
        if (hour !in 0..23 || minute !in 0..59) return null
        val zone = ZoneId.systemDefault()
        val yearly = entry.optBoolean("yearly")
        val initialYear = if (yearly) LocalDate.now(zone).year else year
        for (candidateYear in initialYear..(if (yearly) initialYear + 8 else initialYear)) {
            try {
                val date = LocalDate.of(candidateYear, month, day)
                val local = LocalDateTime.of(date, java.time.LocalTime.of(hour, minute))
                val instant = local.atZone(zone).toInstant().toEpochMilli()
                if (instant > after) return instant
            } catch (_: DateTimeException) {
                // February 29 skips non-leap years without silently moving date.
            }
        }
        return null
    }

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
        val occurrence = prefs(context).getString("ringing", "").orEmpty()
        if (occurrence.isEmpty()) return
        val id = occurrence.substringBeforeLast(':')
        if (id.isNotEmpty()) stop(context, id, "interrupted_by_restart")
    }

    fun fire(context: Context, id: String, due: Long) {
        val all = entries(context)
        val entry = (0 until all.length()).mapNotNull(all::optJSONObject)
            .firstOrNull { it.optString("id") == id } ?: return
        val deliveredAt = System.currentTimeMillis()
        if (due <= 0L || due > deliveredAt + 60_000L ||
            deliveredAt - due > 12L * 60L * 60L * 1000L) return
        val nextDue = dueAt(entry, due + 1000L)
        if (entry.optBoolean("yearly") && nextDue != null) schedule(context, entry, due + 1000L)
        val occurrence = "$id:$due"
        val alert = Intent(context, CalendarReminderRingingService::class.java).apply {
            action = CalendarReminderRingingService.START
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, entry.optString("title"))
            putExtra(EXTRA_OCCURRENCE, occurrence)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(alert)
        } else {
            context.startService(alert)
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        val timeout = intent(context, id, ACTION_TIMEOUT, due)
        runCatching {
            if (canScheduleExact(context)) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deliveredAt + FIVE_MINUTES, timeout)
            } else {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deliveredAt + FIVE_MINUTES, timeout)
            }
        } // The service also has its own five-minute timeout.
    }

    fun timeout(context: Context, id: String) {
        stop(context, id, "timeout")
    }

    fun stop(context: Context, id: String, reason: String, stopService: Boolean = true) {
        val ringing = prefs(context).getString("ringing", "").orEmpty()
        if (!ringing.startsWith("$id:")) return
        // Clear synchronously before any callback to make Stop idempotent.
        val title = prefs(context).getString("ringing_title", "").orEmpty()
        prefs(context).edit().remove("ringing").remove("ringing_title").commit()
        context.getSystemService(AlarmManager::class.java)
            .cancel(intent(context, id, ACTION_TIMEOUT))
        val pending = try { JSONArray(prefs(context).getString(STOPS, "[]")) }
            catch (_: Exception) { JSONArray() }
        pending.put(JSONObject().put("id", id).put("occurrence", ringing)
            .put("reason", reason).put("title", title))
        prefs(context).edit().putString(STOPS, pending.toString()).commit()
        if (stopService) {
            context.stopService(Intent(context, CalendarReminderRingingService::class.java))
        }
        OverlayBubbleService.requestSignalBrainWake(context, "calendar_reminder_stopped")
    }

    fun pendingStops(context: Context): List<Map<String, Any?>> {
        val values = try { JSONArray(prefs(context).getString(STOPS, "[]")) }
            catch (_: Exception) { JSONArray() }
        return (0 until values.length()).mapNotNull { index ->
            values.optJSONObject(index)?.let { item ->
                mapOf(
                    "id" to item.optString("id"),
                    "occurrence" to item.optString("occurrence"),
                    "reason" to item.optString("reason"),
                    "title" to item.optString("title"),
                )
            }
        }
    }

    fun acknowledgeStop(context: Context, occurrence: String) {
        val items = pendingStops(context).filter { it["occurrence"] != occurrence }
        prefs(context).edit().putString(STOPS, JSONArray(items).toString()).apply()
    }

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
                CalendarReminderAlarm.timeout(context, id)
            "com.aicompanion.localfirst.calendar.STOP" ->
                CalendarReminderAlarm.stop(context, id, "dismissed")
        }
    }
}
