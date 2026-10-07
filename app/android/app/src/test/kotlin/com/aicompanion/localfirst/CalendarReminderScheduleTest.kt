package com.aicompanion.localfirst

import org.junit.Assert.*
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class CalendarReminderScheduleTest {
    private val zone=ZoneId.of("Asia/Shanghai")
    private fun at(value:String)=ZonedDateTime.parse(value+"+08:00[Asia/Shanghai]").toInstant().toEpochMilli()
    @Test fun dailyRollsAtExactMinuteAndYearBoundary() {
        val daily=CalendarReminderSchedule(2026,10,8,9,15,"daily")
        assertEquals(at("2026-10-08T09:15:00"),daily.next(at("2026-10-08T09:14:00"),zone))
        assertEquals(at("2026-10-09T09:15:00"),daily.next(at("2026-10-08T09:15:00"),zone))
        assertEquals(at("2027-01-01T09:15:00"),daily.next(at("2026-12-31T12:00:00"),zone))
    }
    @Test fun selectedDaysAndDisabledAlarmDoNotSlipToTomorrow() {
        val weekly=CalendarReminderSchedule(2026,10,8,8,0,"weekly",setOf(1,5))
        assertEquals(at("2026-10-09T08:00:00"),weekly.next(at("2026-10-08T20:00:00"),zone))
        assertEquals(at("2026-10-12T08:00:00"),weekly.next(at("2026-10-09T08:00:00"),zone))
        assertFalse(weekly.matches(at("2026-10-10T08:00:00"),zone))
        assertNull(weekly.copy(enabled=false).next(at("2026-10-08T00:00:00"),zone))
        assertNull(weekly.copy(weekdays=emptySet()).next(at("2026-10-08T00:00:00"),zone))
    }
    @Test fun annualLeapAndOnceRemainCompatible() {
        val annual=CalendarReminderSchedule(2024,2,29,9,0,"yearly")
        assertEquals(at("2028-02-29T09:00:00"),annual.next(at("2026-10-08T00:00:00"),zone))
        assertNull(annual.copy(repeat="once").next(at("2026-10-08T00:00:00"),zone))
    }
    @Test fun localTimeIsRecomputedAcrossDaylightSaving() {
        val ny=ZoneId.of("America/New_York")
        val daily=CalendarReminderSchedule(2026,3,7,9,0,"daily")
        val before=ZonedDateTime.of(2026,3,7,10,0,0,0,ny).toInstant().toEpochMilli()
        val expected=ZonedDateTime.of(2026,3,8,9,0,0,0,ny).toInstant().toEpochMilli()
        assertEquals(expected,daily.next(before,ny))
    }
}
