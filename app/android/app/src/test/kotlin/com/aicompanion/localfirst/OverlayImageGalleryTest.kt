package com.aicompanion.localfirst

import android.app.Activity
import android.view.MotionEvent
import android.widget.FrameLayout
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class OverlayImageGalleryTest {
    private fun event(view: OverlayImageGallery, action: Int, x: Float, y: Float) {
        val e = MotionEvent.obtain(0, 100, action, x, y, 0)
        try { view.dispatchTouchEvent(e) } finally { e.recycle() }
    }
    private fun swipe(view: OverlayImageGallery, dx: Float, dy: Float, cancel: Boolean = false) {
        event(view, MotionEvent.ACTION_DOWN, 200f, 100f)
        event(view, MotionEvent.ACTION_MOVE, 200f + dx, 100f + dy)
        event(view, if (cancel) MotionEvent.ACTION_CANCEL else MotionEvent.ACTION_UP,
            200f + dx, 100f + dy)
    }
    @Test fun horizontalSwipeUsesCurrentImageAndStopsAtBoundaries() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val bound = mutableListOf<String>(); val changed = mutableListOf<Int>()
        val view = OverlayImageGallery(activity, listOf("a", "b", "c"), 0,
            { _, path -> bound.add(path) }, { changed.add(it) })
        activity.setContentView(view); view.layout(0, 0, 500, 300)
        swipe(view, -150f, 0f); assertEquals(1, view.page)
        swipe(view, -150f, 0f); assertEquals(2, view.page)
        swipe(view, -150f, 0f); assertEquals(2, view.page)
        swipe(view, 150f, 0f); assertEquals(1, view.page)
        assertEquals(listOf("a", "b", "c", "b"), bound)
        assertEquals(listOf(1, 2, 1), changed)
        assertTrue(view.contentDescription.contains("第 2 张"))
    }
    @Test fun verticalGestureReleasesParentAndNeverChangesImage() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val requests = mutableListOf<Boolean>()
        val parent = object : FrameLayout(activity) {
            override fun requestDisallowInterceptTouchEvent(disallow: Boolean) {
                requests.add(disallow); super.requestDisallowInterceptTouchEvent(disallow)
            }
        }
        val view = OverlayImageGallery(activity, listOf("a", "b"), 0, { _, _ -> }, {})
        parent.addView(view); activity.setContentView(parent); view.layout(0, 0, 500, 300)
        swipe(view, 10f, -150f)
        assertEquals(0, view.page); assertTrue(requests.contains(true)); assertFalse(requests.last())
    }
    @Test fun cancelledSwipeDoesNotCommitAndNextGestureStartsFresh() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val view = OverlayImageGallery(activity, listOf("a", "b"), 0, { _, _ -> }, {})
        view.layout(0, 0, 500, 300)
        swipe(view, -150f, 0f, cancel = true); assertEquals(0, view.page)
        swipe(view, -150f, 0f); assertEquals(1, view.page)
    }
    @Test fun restoredPageIsBoundedAndMissingDecodeDoesNotBlockSwiping() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val paths = mutableListOf<String>()
        val view = OverlayImageGallery(activity, listOf("missing", "other"), 9,
            { _, path -> paths.add(path) }, {})
        view.layout(0, 0, 500, 300)
        assertEquals(1, view.page)
        swipe(view, 150f, 0f); assertEquals(0, view.page)
        assertEquals(listOf("other", "missing"), paths)
    }
}
