package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import android.graphics.Rect
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.aicompanion.localfirst.CalendarReminderRuntime as Runtime
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ReminderCardSmokeTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    @Before fun reset() {
        context.getSharedPreferences("calendar_reminders_v1",Context.MODE_PRIVATE)
            .edit().clear().putString("revision","current").commit()
    }
    @Test fun independentOccurrencesAndPersistentConfirmation() {
        assertTrue(Runtime.start(context,"a",1000,"出发",1000,100))
        assertFalse(Runtime.start(context,"a",1000,"重复",1100,200))
        assertTrue(Runtime.start(context,"b",1000,"喝水",1000,100))
        assertTrue(Runtime.confirm(context,"a:1000",2000,1100))
        val items=Runtime.records(context)
        assertEquals(2,items.size)
        assertEquals("confirmed",items.first().getString("status"))
        assertEquals("ringing",items.last().getString("status"))
        assertEquals(299_000L,Runtime.remaining(items.last(),1100,2000))
        assertFalse(Runtime.confirm(context,"a:1000",2100,1200))
    }
    @Test fun timeoutAndLateConfirmationKeepOriginalDeadline() {
        Runtime.start(context,"a",1000,"出发",1000,100)
        assertFalse(Runtime.expire(context,300999,300099))
        assertTrue(Runtime.expire(context,302000,301100))
        var item=Runtime.records(context).single()
        assertEquals("timed_out",item.getString("status"))
        assertEquals(301000L,item.getLong("stoppedAt"))
        assertTrue(Runtime.confirm(context,"a:1000",360000,359100))
        item=Runtime.records(context).single()
        assertEquals("confirmed",item.getString("status"))
        assertEquals(301000L,item.getLong("timedOutAt"))
        assertEquals(301000L,item.getLong("stoppedAt"))
        assertEquals(360000L,item.getLong("confirmedAt"))
    }
    @Test fun editedAndRestoredOccurrencesCannotBeDeliveredOrConfirmed() {
        Runtime.start(context,"a",1000,"出发",1000,100)
        Runtime.markDelivery(context,"a:1000","delivered","obsolete")
        assertEquals("pending",Runtime.records(context).single().getString("delivery"))
        Runtime.reconcile(context,false) { false }
        assertFalse(Runtime.confirm(context,"a:1000"))
        assertEquals("cancelled",Runtime.records(context).single().getString("delivery"))
        Runtime.reconcile(context,true) { true }
        assertTrue(Runtime.records(context).isEmpty())
    }
    @Test fun productionCardKeepsItsTimeAcrossRecreationAndConfirmsOnlyItsOccurrence() {
        Runtime.start(context,"a",1000,"出发")
        Runtime.start(context,"b",1000,"喝水")
        val deadline=Runtime.records(context).first().getLong("deadlineElapsed")
        ActivityScenario.launch(ReminderCardSmokeActivity::class.java).use { scenario ->
            scenario.recreate()
            scenario.onActivity { activity ->
                assertEquals(deadline,Runtime.records(activity).first().getLong("deadlineElapsed"))
                val button=activity.card.confirmButton
                assertEquals("确认",button.text.toString())
                assertTrue(button.isShown)
                assertTrue(button.getGlobalVisibleRect(Rect()))
                assertTrue(button.performClick())
                assertEquals("confirmed",Runtime.records(activity).first().getString("status"))
                assertEquals("ringing",Runtime.records(activity).last().getString("status"))
            }
        }
    }
}
