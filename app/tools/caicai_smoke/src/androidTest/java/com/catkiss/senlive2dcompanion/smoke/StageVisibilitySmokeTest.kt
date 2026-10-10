package com.catkiss.senlive2dcompanion.smoke

import android.opengl.GLSurfaceView
import android.opengl.GLES20
import android.os.Build
import android.view.View
import android.view.MotionEvent
import android.os.SystemClock
import android.widget.Button
import android.widget.FrameLayout
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.catkiss.senlive2dcompanion.CaicaiStageVisibility
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

@RunWith(AndroidJUnit4::class)
class StageVisibilitySmokeTest {
    @Test fun oldSurfaceHidesAndRestoresWithoutReplacingView() {
        ActivityScenario.launch(StageVisibilitySmokeActivity::class.java).use { scenario ->
            lateinit var stage: FrameLayout
            lateinit var surface: GLSurfaceView
            lateinit var button: Button
            var taps = 0
            val rendered = CountDownLatch(1)
            scenario.onActivity { activity ->
                val host = FrameLayout(activity)
                stage = FrameLayout(activity)
                surface = GLSurfaceView(activity).apply {
                    setEGLContextClientVersion(2)
                    setRenderer(object : GLSurfaceView.Renderer {
                        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {}
                        override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) { GLES20.glViewport(0,0,w,h) }
                        override fun onDrawFrame(gl: GL10?) { GLES20.glClearColor(0f,0f,1f,1f); GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT); rendered.countDown() }
                    })
                }
                activity.surface = surface
                button = Button(activity).apply { text = "More"; setOnClickListener { taps++ } }
                host.addView(button, FrameLayout.LayoutParams(-1,-1))
                stage.addView(surface, FrameLayout.LayoutParams(-1,-1))
                host.addView(stage, FrameLayout.LayoutParams(-1,-1))
                activity.setContentView(host)
            }
            assertTrue("GL surface must render before hiding", rendered.await(10, TimeUnit.SECONDS))
            repeat(5) {
                scenario.onActivity {
                    CaicaiStageVisibility.apply(stage, surface, false)
                    surface.onPause()
                    if (Build.VERSION.SDK_INT in 26..27) {
                        assertEquals(View.INVISIBLE, surface.visibility)
                        assertFalse(stage.isShown)
                    }
                }
                InstrumentationRegistry.getInstrumentation().waitForIdleSync()
                if (Build.VERSION.SDK_INT in 26..27) {
                    val center = IntArray(2)
                    scenario.onActivity { button.getLocationOnScreen(center); center[0] += button.width / 2; center[1] += button.height / 2 }
                    val stamp = SystemClock.uptimeMillis()
                    for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
                        val event = MotionEvent.obtain(stamp, SystemClock.uptimeMillis(), action, center[0].toFloat(), center[1].toFloat(), 0)
                        InstrumentationRegistry.getInstrumentation().sendPointerSync(event)
                        event.recycle()
                    }
                    InstrumentationRegistry.getInstrumentation().waitForIdleSync()
                }
                scenario.onActivity {
                    if (Build.VERSION.SDK_INT !in 26..27) assertTrue(button.performClick())
                    CaicaiStageVisibility.apply(stage, surface, true)
                    surface.onResume()
                    assertEquals(View.VISIBLE, surface.visibility)
                    assertEquals(1f, stage.alpha)
                    assertSame(stage, surface.parent)
                }
            }
            scenario.moveToState(androidx.lifecycle.Lifecycle.State.CREATED)
            scenario.moveToState(androidx.lifecycle.Lifecycle.State.RESUMED)
            scenario.onActivity { surface.onPause(); assertEquals(5,taps) }
        }
    }
}
