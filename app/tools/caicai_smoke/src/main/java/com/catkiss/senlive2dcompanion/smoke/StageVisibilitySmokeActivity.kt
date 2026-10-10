package com.catkiss.senlive2dcompanion.smoke

import android.app.Activity
import android.opengl.GLSurfaceView

/** Isolated real GL surface host; does not construct or release a second renderer. */
class StageVisibilitySmokeActivity : Activity() {
    var surface: GLSurfaceView? = null
    override fun onPause() { surface?.onPause(); super.onPause() }
    override fun onResume() { super.onResume(); surface?.onResume() }
}
