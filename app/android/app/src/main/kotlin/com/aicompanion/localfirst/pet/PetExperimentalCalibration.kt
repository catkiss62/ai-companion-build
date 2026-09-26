package com.aicompanion.localfirst.pet

import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Color
import kotlin.math.pow

/** One shared visual transform for the trial clips; it never changes pet geometry. */
data class PetExperimentalCalibration(
    val scale: Float = 1.35f,
    val xDp: Float = 0f,
    val yDp: Float = 0f,
    val gamma: Float = 0.85f,
) {
    fun bounded() = copy(
        scale = scale.coerceIn(0.5f, 2.5f),
        xDp = xDp.coerceIn(-80f, 80f),
        yDp = yDp.coerceIn(-80f, 80f),
        gamma = gamma.coerceIn(0.5f, 1.25f),
    )

    fun save(prefs: SharedPreferences) {
        val value = bounded()
        prefs.edit()
            .putFloat(KEY_SCALE, value.scale)
            .putFloat(KEY_X, value.xDp)
            .putFloat(KEY_Y, value.yDp)
            .putFloat(KEY_GAMMA, value.gamma)
            .apply()
    }

    companion object {
        private const val KEY_SCALE = "pet_experimental_scale"
        private const val KEY_X = "pet_experimental_x_dp"
        private const val KEY_Y = "pet_experimental_y_dp"
        private const val KEY_GAMMA = "pet_experimental_gamma"

        fun load(prefs: SharedPreferences) = PetExperimentalCalibration(
            scale = prefs.getFloat(KEY_SCALE, 1.35f),
            xDp = prefs.getFloat(KEY_X, 0f),
            yDp = prefs.getFloat(KEY_Y, 0f),
            gamma = prefs.getFloat(KEY_GAMMA, 0.85f),
        ).bounded()
    }
}

/** Gamma below 1 lifts midtones while preserving transparent edges and endpoints. */
object PetExperimentalCurve {
    fun apply(source: Bitmap, gamma: Float): Bitmap {
        if (gamma == 1f) return source
        val safe = gamma.coerceIn(0.5f, 1.25f)
        val lut = IntArray(256) { index ->
            ((index / 255.0).pow(safe.toDouble()) * 255.0 + 0.5).toInt().coerceIn(0, 255)
        }
        val pixels = IntArray(source.width * source.height)
        source.getPixels(pixels, 0, source.width, 0, 0, source.width, source.height)
        for (index in pixels.indices) {
            val color = pixels[index]
            pixels[index] = Color.argb(
                Color.alpha(color),
                lut[Color.red(color)],
                lut[Color.green(color)],
                lut[Color.blue(color)],
            )
        }
        return Bitmap.createBitmap(pixels, source.width, source.height, Bitmap.Config.ARGB_8888)
    }
}
