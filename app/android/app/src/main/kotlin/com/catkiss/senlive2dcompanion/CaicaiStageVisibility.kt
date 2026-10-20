package com.catkiss.senlive2dcompanion

import android.view.View

/** Apply the shared stage composition path without recreating the surface. */
object CaicaiStageVisibility {
    @JvmStatic
    fun apply(root: View, visible: Boolean) {
        root.alpha = if (visible) 1f else 0f
    }
}
