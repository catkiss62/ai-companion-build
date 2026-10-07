package com.catkiss.senlive2dcompanion.smoke

import android.app.Activity
import android.os.Bundle
import com.aicompanion.localfirst.CalendarReminderCard
import com.aicompanion.localfirst.CalendarReminderRuntime

/** Test host only; the journal and view are the production implementations. */
class ReminderCardSmokeActivity : Activity() {
    lateinit var card: CalendarReminderCard
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        card=CalendarReminderCard(this) { CalendarReminderRuntime.confirm(this,it) }
        card.show(CalendarReminderRuntime.records(this).first(),2)
        setContentView(card)
    }
}
