package com.catkiss.senlive2dcompanion

import android.os.Build
import android.view.View

/** Keep the tested modern compositor path; Android 8 needs a real hide. */
object CaicaiStageVisibility {
    @JvmStatic
    fun apply(root: View, surface: View, visible: Boolean) {
        root.alpha = if (visible) 1f else 0f
        if (Build.VERSION.SDK_INT in 26..27) {
            surface.visibility = if (visible) View.VISIBLE else View.INVISIBLE
            root.visibility = if (visible) View.VISIBLE else View.INVISIBLE
        }
    }
}
