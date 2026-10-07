package com.aicompanion.localfirst

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/** Local wall-clock recurrence. Each next occurrence is scheduled separately. */
data class CalendarReminderSchedule(
    val year: Int, val month: Int, val day: Int, val hour: Int, val minute: Int,
    val repeat: String = "once", val weekdays: Set<Int> = emptySet(), val enabled: Boolean = true,
) {
    private fun on(date: LocalDate): Boolean = when(repeat) {
        "daily" -> true
        "weekly" -> date.dayOfWeek.value in weekdays
        "yearly" -> date.monthValue == month && date.dayOfMonth == day
        else -> date.year == year && date.monthValue == month && date.dayOfMonth == day
    }
    fun matches(due: Long, zone: ZoneId = ZoneId.systemDefault()): Boolean {
        if(!enabled || due <= 0 || hour !in 0..23 || minute !in 0..59) return false
        val local = Instant.ofEpochMilli(due).atZone(zone)
        return on(local.toLocalDate()) && local.hour == hour && local.minute == minute
    }
    fun next(after: Long, zone: ZoneId = ZoneId.systemDefault()): Long? {
        if(!enabled || hour !in 0..23 || minute !in 0..59) return null
        val today = Instant.ofEpochMilli(after).atZone(zone).toLocalDate()
        val time = LocalTime.of(hour, minute)
        val dates = when(repeat) {
            "daily", "weekly" -> (0L..7L).map { today.plusDays(it) }
            "yearly" -> (today.year..today.year+8).mapNotNull { runCatching { LocalDate.of(it,month,day) }.getOrNull() }
            else -> listOfNotNull(runCatching { LocalDate.of(year,month,day) }.getOrNull())
        }
        return dates.filter(::on).map { it.atTime(time).atZone(zone).toInstant().toEpochMilli() }
            .firstOrNull { it > after }
    }
}
