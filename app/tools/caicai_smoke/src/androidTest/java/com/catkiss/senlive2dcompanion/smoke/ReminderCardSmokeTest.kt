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
        val confirmed=items.single { it.getString("occurrence")=="a:1000" }
        val remaining=items.single { it.getString("occurrence")=="b:1000" }
        assertEquals("confirmed",confirmed.getString("status"))
        assertEquals("ringing",remaining.getString("status"))
        assertEquals(299_000L,Runtime.remaining(remaining,1100,2000))
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
                val items=Runtime.records(activity)
                assertEquals("confirmed",items.single { it.getString("occurrence")=="a:1000" }.getString("status"))
                assertEquals("ringing",items.single { it.getString("occurrence")=="b:1000" }.getString("status"))
            }
        }
    }
    @Test fun compactCardKeepsCurrentScreenTouchableAndRestoresVolumeStream() {
        Runtime.start(context,"a",1000,"喝两杯水，补昨天欠的")
        ActivityScenario.launch(ReminderCardSmokeActivity::class.java).use { scenario ->
            androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            scenario.onActivity { activity ->
                val card = activity.card
                val density = activity.resources.displayMetrics.density
                val cardRect = Rect(); assertTrue(card.getGlobalVisibleRect(cardRect))
                val safe = Rect(); activity.window.decorView.getWindowVisibleDisplayFrame(safe)
                assertTrue(cardRect.width() <= (281 * density).toInt())
                assertTrue(kotlin.math.abs(safe.right - cardRect.right - 12 * density) < 3 * density)
                assertTrue(kotlin.math.abs(safe.bottom - cardRect.bottom - 12 * density) < 3 * density)
                assertTrue(card.confirmButton.width < card.width / 2)
                assertTrue(card.confirmButton.height >= (48 * density).toInt())
                assertEquals(android.media.AudioManager.STREAM_RING, activity.volumeControlStream)
                val buttonRect = Rect(); activity.outsideButton.getGlobalVisibleRect(buttonRect)
                val origin = IntArray(2); activity.window.decorView.getLocationOnScreen(origin)
                val now = android.os.SystemClock.uptimeMillis()
                for (action in listOf(android.view.MotionEvent.ACTION_DOWN, android.view.MotionEvent.ACTION_UP)) {
                    val event = android.view.MotionEvent.obtain(now, now, action,
                        (buttonRect.centerX() - origin[0]).toFloat(), (buttonRect.centerY() - origin[1]).toFloat(), 0)
                    activity.dispatchTouchEvent(event); event.recycle()
                }
                assertEquals(1, activity.outsideClicks)
                assertTrue(card.confirmButton.performClick())
                assertEquals(android.view.View.GONE, card.visibility)
                assertEquals(android.media.AudioManager.STREAM_MUSIC, activity.volumeControlStream)
                assertFalse(activity.isFinishing)
            }
        }
    }
    @Test fun captureCompactReminderForVisualReview() {
        Runtime.start(context,"preview",1000,"喝两杯水，补昨天欠的")
        ActivityScenario.launch(ReminderCardSmokeActivity::class.java).use {
            val instrumentation = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
            instrumentation.waitForIdleSync()
            val screenshot = instrumentation.uiAutomation.takeScreenshot()
            assertNotNull(screenshot)
            val file = java.io.File(context.getExternalFilesDir(null), "reminder-compact.png")
            file.outputStream().use { output ->
                assertTrue(screenshot!!.compress(android.graphics.Bitmap.CompressFormat.PNG,100,output))
            }
            screenshot!!.recycle()
            instrumentation.uiAutomation.executeShellCommand("cp ${file.absolutePath} /data/local/tmp/reminder-compact.png").use {
                android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
            }
        }
    }
    @Test fun pauseResumeRetainsDeadlineWithoutConfirmationOrDuplicateCard() {
        Runtime.start(context,"a",1000,"出发")
        val deadline = Runtime.records(context).single().getLong("deadlineElapsed")
        ActivityScenario.launch(ReminderCardSmokeActivity::class.java).use { scenario ->
            scenario.moveToState(androidx.lifecycle.Lifecycle.State.CREATED)
            assertFalse(com.aicompanion.localfirst.CalendarReminderCardHost.foregroundVisible)
            assertEquals("ringing", Runtime.records(context).single().getString("status"))
            scenario.moveToState(androidx.lifecycle.Lifecycle.State.RESUMED)
            scenario.onActivity { activity ->
                assertEquals(deadline, Runtime.records(context).single().getLong("deadlineElapsed"))
                assertTrue(activity.card.isShown)
                activity.host.start()
                assertSame(activity.host.card, activity.card)
            }
        }
        assertFalse(com.aicompanion.localfirst.CalendarReminderCardHost.foregroundVisible)
    }

}
