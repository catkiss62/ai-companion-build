package com.aicompanion.localfirst.pet

/** Chooses the dock axis after a gentle user drag reaches an edge. */
object PetEdgeDockPolicy {
    const val LEFT = "left"
    const val RIGHT = "right"
    const val TOP = "top"
    const val BOTTOM = "bottom"

    fun choose(
        leftDistance: Int,
        rightDistance: Int,
        topDistance: Int,
        bottomDistance: Int,
        captureRange: Int,
    ): String {
        val nearSide = minOf(leftDistance, rightDistance) <= captureRange
        val nearTopOrBottom = minOf(topDistance, bottomDistance) <= captureRange
        // A corner belongs to the upper/lower edge even if the side is closer.
        // Use the same inclusive capture range as the drag-release eligibility.
        if (nearSide && nearTopOrBottom) {
            return if (topDistance <= bottomDistance) TOP else BOTTOM
        }
        // Preserve the previous nearest-edge order everywhere outside corners.
        return listOf(
            LEFT to leftDistance,
            RIGHT to rightDistance,
            TOP to topDistance,
            BOTTOM to bottomDistance,
        ).minByOrNull { it.second }?.first ?: BOTTOM
    }
}
