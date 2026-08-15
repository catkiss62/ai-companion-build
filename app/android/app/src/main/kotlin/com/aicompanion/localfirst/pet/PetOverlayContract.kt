package com.aicompanion.localfirst.pet

/** Pure interaction geometry copied from ds-local-pet/pet/interaction.py. */
object PetTouchRegions {
    fun classify(x: Float, y: Float, width: Int, height: Int): String {
        if (width <= 0 || height <= 0) return "body"
        val nx = x / width.toFloat()
        val ny = y / height.toFloat()
        if (nx !in 0f..1f || ny !in 0f..1f) return "body"
        if (nx in 0.27f..0.73f && ny in 0.20f..0.43f) return "face"
        if (nx in 0.14f..0.86f && ny in 0.02f..0.40f) return "head"
        if ((nx >= 0.72f || nx <= 0.24f) && ny in 0.45f..0.88f) return "tail"
        return "body"
    }
}

/** Display size and source-raster tier are independent but deliberately paired. */
object PetOverlaySizing {
    const val SMALL = "small"
    const val MEDIUM = "medium"
    const val LARGE = "large"

    fun normalized(value: String?): String = when (value) {
        SMALL, MEDIUM, LARGE -> value
        else -> MEDIUM
    }

    fun windowDp(size: String): Int = when (normalized(size)) {
        SMALL -> 112
        LARGE -> 200
        else -> 152
    }

    fun assetHeight(size: String): Int = when (normalized(size)) {
        SMALL -> 187
        LARGE -> 306
        else -> 238
    }
}

/** Pure release and persisted-mode contract shared by every pet motion region. */
object PetMotionPolicy {
    const val FREE = "free"
    const val EDGE = "edge"
    const val HALF_TOP = "half_top"
    const val HALF_BOTTOM = "half_bottom"
    const val HALF_LEFT = "half_left"
    const val HALF_RIGHT = "half_right"

    private val modes = setOf(
        FREE,
        EDGE,
        HALF_TOP,
        HALF_BOTTOM,
        HALF_LEFT,
        HALF_RIGHT,
    )

    fun normalized(value: String?): String = value?.takeIf(modes::contains) ?: FREE

    fun isHalf(value: String?): Boolean = normalized(value).startsWith("half_")

    /**
     * A throw needs sustained evidence, not one noisy last sample. A stable tail
     * always wins so a long, deliberate drag can still be placed gently.
     */
    fun shouldThrow(
        speedDpPerSecond: Float,
        recentTravelDp: Float,
        totalDisplacementDp: Float,
        tailStable: Boolean,
    ): Boolean = !tailStable &&
        speedDpPerSecond >= 650f &&
        recentTravelDp >= 30f &&
        totalDisplacementDp >= 48f
}
