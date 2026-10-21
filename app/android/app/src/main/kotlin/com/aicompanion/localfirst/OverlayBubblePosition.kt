package com.aicompanion.localfirst

import kotlin.math.abs
import kotlin.math.roundToInt

/** Normalized ordinary-bubble position; desk-pet overscan is a separate policy. */
data class OverlayBubblePosition(val edge: Int, val xFraction: Float, val yFraction: Float) {
    fun place(left: Int, top: Int, right: Int, bottom: Int, width: Int, height: Int): Pair<Int, Int> {
        val xRange = (right - left - width).coerceAtLeast(0)
        val yRange = (bottom - top - height).coerceAtLeast(0)
        val x = when (edge) {
            -1 -> left
            1 -> left + xRange
            else -> left + (xFraction.coerceIn(0f, 1f) * xRange).roundToInt()
        }
        return x to top + (yFraction.coerceIn(0f, 1f) * yRange).roundToInt()
    }

    companion object {
        fun capture(x: Int, y: Int, left: Int, top: Int, right: Int, bottom: Int,
                    width: Int, height: Int, retracted: Boolean): OverlayBubblePosition {
            val xRange = (right - left - width).coerceAtLeast(0)
            val yRange = (bottom - top - height).coerceAtLeast(0)
            val edge = when {
                retracted || abs(x - left) <= 2 -> -1
                abs(x - left - xRange) <= 2 -> 1
                else -> 0
            }
            return OverlayBubblePosition(edge,
                if (xRange == 0) 0f else ((x - left).toFloat() / xRange).coerceIn(0f, 1f),
                if (yRange == 0) 0f else ((y - top).toFloat() / yRange).coerceIn(0f, 1f))
        }
    }
}
