package com.aicompanion.localfirst.pet

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.WindowInsets

/** Keep the entire control surface inside the status bar, cutout and nav bar. */
object PetActivityInsets {
    fun apply(
        activity: Activity,
        view: View,
        left: Int,
        top: Int,
        right: Int,
        bottom: Int,
    ) {
        if (Build.VERSION.SDK_INT >= 30) {
            activity.window.setDecorFitsSystemWindows(false)
            view.setOnApplyWindowInsetsListener { target, insets ->
                val bars = insets.getInsets(
                    WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
                )
                target.setPadding(left + bars.left, top + bars.top,
                    right + bars.right, bottom + bars.bottom)
                insets
            }
            view.requestApplyInsets()
        } else {
            view.setPadding(left, top, right, bottom)
            view.fitsSystemWindows = true
        }
    }
}
