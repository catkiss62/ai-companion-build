package com.aicompanion.localfirst.pet

import org.json.JSONObject

/** Full-frame clips generated from the pinned dsh-pet-indesktop source archive. */
object PetExperimentalClips {
    const val PREF_KEY = "pet_shenshen_clip_test"
    const val CLICK = "EXPERIMENTAL_CLICK"
    const val STAND = "EXPERIMENTAL_STAND"
    const val FRAME_COUNT = 241 // Legacy five packs retain the original format.
    private val legacyIdle = listOf("EXPERIMENTAL_HUM", "EXPERIMENTAL_STRETCH", "EXPERIMENTAL_CUBE", STAND)

    data class Entry(
        val id: String,
        val folder: String,
        val name: String,
        val category: String,
        val frames: Int,
        val durationMs: Long,
    )

    private var loaded: List<Entry> = emptyList()
    val IDLE: List<String> get() = loaded.filter { it.category == "ambient" }.map { it.id }
        .ifEmpty { legacyIdle }
    val CLICKS: List<String> get() = loaded.filter { it.category == "click" }.map { it.id }
        .ifEmpty { listOf(CLICK) }
    val SLEEP_PREVIEW: List<String> get() = loaded.filter { it.category == "sleep" }.map { it.id }
    fun nameFor(id: String): String? = loaded.firstOrNull { it.id == id }?.name
    fun categoryFor(id: String): String? = loaded.firstOrNull { it.id == id }?.category
    fun frameCountFor(folder: String): Int? = loaded.firstOrNull { it.folder == folder }?.frames
    fun isExperimental(actionId: String): Boolean = actionId.startsWith("EXPERIMENTAL_")

    fun frameIndex(elapsedMs: Long, frameCount: Int, durationMs: Long): Int =
        (elapsedMs.coerceAtLeast(0L) * frameCount / durationMs.coerceAtLeast(1L))
            .toInt().coerceIn(0, frameCount - 1)

    fun install(
        assets: MutableMap<String, PetAssetSpec>,
        actions: MutableMap<String, PetActionSpec>,
        catalog: JSONObject? = null,
    ) {
        val entries = if (catalog == null) {
            listOf(
                Entry(legacyIdle[0], "hum", "悠闲哼歌", "ambient", FRAME_COUNT, 6_667L),
                Entry(legacyIdle[1], "stretch", "超大伸懒腰", "ambient", FRAME_COUNT, 6_667L),
                Entry(legacyIdle[2], "cube", "原地专心玩魔方", "ambient", FRAME_COUNT, 6_667L),
                Entry(STAND, "stand", "待机呼吸休闲", "ambient", FRAME_COUNT, 6_667L),
                Entry(CLICK, "click", "点击回应-开心跃动", "click", FRAME_COUNT, 6_667L),
            )
        } else {
            require(catalog.getInt("schema") == 1)
            val clips = catalog.getJSONArray("clips")
            require(clips.length() == 96) { "Incomplete experimental clip catalog" }
            (0 until clips.length()).map { index ->
                val item = clips.getJSONObject(index)
                Entry(
                    id = item.getString("id"),
                    folder = item.getString("folder"),
                    name = item.getString("name"),
                    category = item.getString("category"),
                    frames = item.getInt("frames"),
                    durationMs = item.getLong("duration_ms"),
                ).also {
                    require(it.folder.matches(Regex("[a-z0-9_]+")))
                    require(it.frames in 1..300 && it.durationMs > 0)
                    require(it.category in setOf("click", "sleep", "preview", "ambient"))
                }
            }.also { all ->
                require(all.map { it.id }.toSet().size == all.size)
                require(all.map { it.folder }.toSet().size == all.size)
                require(all.count { it.category == "click" } == 5)
                require(all.count { it.category == "sleep" } == 3)
            }
        }
        loaded = entries
        entries.forEach { entry ->
            val assetId = "shenshen_${entry.folder}"
            assets[assetId] = PetAssetSpec(
                id = assetId,
                framesBySize = mapOf(238 to (0 until entry.frames).map { index ->
                    "runtime_overrides/experimental/${entry.folder}/${index.toString().padStart(3, '0')}.webp"
                }),
                frameCount = entry.frames,
            )
            actions[entry.id] = PetActionSpec(
                id = entry.id,
                assetId = assetId,
                loop = false,
                durationMs = entry.durationMs,
                priority = if (entry.category == "click") 80 else 15,
                interruptible = true,
                returnState = "IDLE",
                anchor = PetAnchor(x = 0.5f, y = 0.92f),
                effect = if (entry.category == "click") "experimental_jelly" else "experimental_idle",
                enter = null,
                exit = null,
            )
        }
    }
}
