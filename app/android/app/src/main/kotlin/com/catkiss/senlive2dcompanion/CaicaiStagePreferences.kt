package com.catkiss.senlive2dcompanion

import android.content.SharedPreferences

/** One preference reader for new stages and an existing stage after restore. */
internal data class CaicaiStagePreferences(
    val motionGain: Float, val motionSpeed: Float, val legPivot: Float,
    val scale: Float, val x: Float, val y: Float,
    val headLeft: Float, val headTop: Float, val headRight: Float, val headBottom: Float,
) {
    fun headBox() = floatArrayOf(headLeft, headTop, headRight, headBottom)
    fun applyTo(view: CaicaiCompanionView, previous: CaicaiStagePreferences? = null) {
        if (previous == null || motionGain != previous.motionGain || motionSpeed != previous.motionSpeed || legPivot != previous.legPivot)
            view.tuneCaicaiMotion(motionGain, motionSpeed, legPivot)
        if (previous == null || scale != previous.scale || x != previous.x || y != previous.y)
            view.setStageTransform(scale, x, y)
        view.requestRender()
    }
    companion object {
        // Legacy +332 ear keys remain accepted by portable snapshots, but are
        // deliberately ignored here: the accepted placement is now fixed.
        fun read(prefs: SharedPreferences): CaicaiStagePreferences {
            val scale = prefs.getFloat("scale", 1f)
            val limit = .9f + .5f * scale
            return CaicaiStagePreferences(
                prefs.getFloat("motionGain", 1f), prefs.getFloat("motionSpeed", 1f),
                prefs.getFloat("legPivot", .88f), scale,
                prefs.getFloat("x", 0f).coerceIn(-limit, limit),
                prefs.getFloat("y", 0f).coerceIn(-limit, limit),
                prefs.getFloat("headLeft", .27f), prefs.getFloat("headTop", .02f),
                prefs.getFloat("headRight", .73f), prefs.getFloat("headBottom", .32f))
        }
    }
}
