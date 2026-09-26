package com.aicompanion.localfirst.pet

/** Small, reversible Android test set from MerZlin/dsh-pet-indesktop. */
object PetExperimentalClips {
    const val PREF_KEY = "pet_shenshen_clip_test"
    const val CLICK = "EXPERIMENTAL_CLICK"
    const val STAND = "EXPERIMENTAL_STAND"
    const val FRAME_COUNT = 241
    val IDLE = listOf("EXPERIMENTAL_HUM", "EXPERIMENTAL_STRETCH", "EXPERIMENTAL_CUBE", STAND)

    fun isExperimental(actionId: String): Boolean = actionId == CLICK || actionId in IDLE

    fun frameIndex(elapsedMs: Long, frameCount: Int, durationMs: Long): Int =
        (elapsedMs.coerceAtLeast(0L) * frameCount / durationMs.coerceAtLeast(1L))
            .toInt().coerceIn(0, frameCount - 1)

    fun install(
        assets: MutableMap<String, PetAssetSpec>,
        actions: MutableMap<String, PetActionSpec>,
    ) {
        val clips = listOf(
            Triple(IDLE[0], "hum", "experimental_idle"),
            Triple(IDLE[1], "stretch", "experimental_idle"),
            Triple(IDLE[2], "cube", "experimental_idle"),
            Triple(STAND, "stand", "experimental_idle"),
            Triple(CLICK, "click", "experimental_jelly"),
        )
        for ((id, folder, effect) in clips) {
            val assetId = "shenshen_$folder"
            val frameCount = FRAME_COUNT
            assets[assetId] = PetAssetSpec(
                id = assetId,
                framesBySize = mapOf(238 to (0 until frameCount).map { index ->
                    "runtime_overrides/experimental/$folder/${index.toString().padStart(3, '0')}.webp"
                }),
                frameCount = frameCount,
            )
            actions[id] = PetActionSpec(
                id = id,
                assetId = assetId,
                loop = false,
                durationMs = 6_667L,
                priority = if (id == CLICK) 80 else 15,
                interruptible = true,
                returnState = "IDLE",
                anchor = PetAnchor(x = 0.5f, y = 0.92f),
                effect = effect,
                enter = null,
                exit = null,
            )
        }
    }
}
