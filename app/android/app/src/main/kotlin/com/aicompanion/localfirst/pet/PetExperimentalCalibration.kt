package com.aicompanion.localfirst.pet

import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Color
import kotlin.math.pow

/** One shared visual transform for the trial clips; it never changes pet geometry. */
data class PetExperimentalCalibration(
    val scale: Float = 1.35f,
    val widthScale: Float = 1f,
    val xDp: Float = 0f,
    val yDp: Float = 0f,
    val gamma: Float = 0.86f,
    val blackPoint: Int = 0,
    val whitePoint: Int = 230,
    val saturation: Float = 1f,
) {
    fun bounded() = copy(
        scale = scale.coerceIn(0.5f, 2.5f),
        widthScale = widthScale.coerceIn(0.5f, 1.5f),
        xDp = xDp.coerceIn(-80f, 80f),
        yDp = yDp.coerceIn(-80f, 80f),
        gamma = gamma.coerceIn(0.5f, 1.25f),
        blackPoint = blackPoint.coerceIn(0, 100),
        whitePoint = whitePoint.coerceIn(150, 255).coerceAtLeast(blackPoint + 1),
        saturation = saturation.coerceIn(0.5f, 2f),
    )

    fun save(prefs: SharedPreferences) {
        val value = bounded()
        prefs.edit()
            .putFloat(KEY_SCALE, value.scale)
            .putFloat(KEY_WIDTH_SCALE, value.widthScale)
            .putFloat(KEY_X, value.xDp)
            .putFloat(KEY_Y, value.yDp)
            .putFloat(KEY_GAMMA, value.gamma)
            .putInt(KEY_BLACK, value.blackPoint)
            .putInt(KEY_WHITE, value.whitePoint)
            .putFloat(KEY_SATURATION, value.saturation)
            .apply()
    }

    companion object {
        private const val KEY_SCALE = "pet_experimental_scale"
        private const val KEY_WIDTH_SCALE = "pet_experimental_width_scale"
        private const val KEY_X = "pet_experimental_x_dp"
        private const val KEY_Y = "pet_experimental_y_dp"
        private const val KEY_GAMMA = "pet_experimental_gamma"
        private const val KEY_BLACK = "pet_experimental_levels_black"
        private const val KEY_WHITE = "pet_experimental_levels_white"
        private const val KEY_SATURATION = "pet_experimental_saturation"

        fun load(prefs: SharedPreferences) = PetExperimentalCalibration(
            scale = prefs.getFloat(KEY_SCALE, 1.35f),
            widthScale = prefs.getFloat(KEY_WIDTH_SCALE, 1f),
            xDp = prefs.getFloat(KEY_X, 0f),
            yDp = prefs.getFloat(KEY_Y, 0f),
            gamma = if (prefs.contains(KEY_WHITE)) prefs.getFloat(KEY_GAMMA, 0.86f) else 0.86f,
            blackPoint = prefs.getInt(KEY_BLACK, 0),
            whitePoint = prefs.getInt(KEY_WHITE, 230),
            saturation = prefs.getFloat(KEY_SATURATION, 1f),
        ).bounded()
    }
}

/** Photoshop RGB input levels (black / midtone / white), with unchanged output 0–255. */
object PetExperimentalCurve {
    fun apply(source: Bitmap, gamma: Float, saturation: Float, blackPoint: Int, whitePoint: Int): Bitmap {
        if (gamma == 1f && saturation == 1f && blackPoint == 0 && whitePoint == 255) return source
        val safe = gamma.coerceIn(0.5f, 1.25f)
        val chroma = saturation.coerceIn(0.5f, 2f)
        val black = blackPoint.coerceIn(0, 100)
        val white = whitePoint.coerceIn(150, 255).coerceAtLeast(black + 1)
        val lut = IntArray(256) { index ->
            (((index - black).toDouble() / (white - black)).coerceIn(0.0, 1.0)
                .pow(1.0 / safe) * 255.0 + 0.5).toInt().coerceIn(0, 255)
        }
        val pixels = IntArray(source.width * source.height)
        source.getPixels(pixels, 0, source.width, 0, 0, source.width, source.height)
        for (index in pixels.indices) {
            val color = pixels[index]
            val red = lut[Color.red(color)]
            val green = lut[Color.green(color)]
            val blue = lut[Color.blue(color)]
            val grey = (0.2126f * red + 0.7152f * green + 0.0722f * blue)
            pixels[index] = Color.argb(
                Color.alpha(color),
                (grey + (red - grey) * chroma).toInt().coerceIn(0, 255),
                (grey + (green - grey) * chroma).toInt().coerceIn(0, 255),
                (grey + (blue - grey) * chroma).toInt().coerceIn(0, 255),
            )
        }
        return Bitmap.createBitmap(pixels, source.width, source.height, Bitmap.Config.ARGB_8888)
    }
}
