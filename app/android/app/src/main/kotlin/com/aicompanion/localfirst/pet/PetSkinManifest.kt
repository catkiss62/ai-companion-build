package com.aicompanion.localfirst.pet

import android.content.res.AssetManager
import org.json.JSONObject

data class PetClipSpec(
    val id: String,
    val frames: List<String>,
    val fps: Int,
    val loop: Boolean,
    val interruptible: Boolean,
)

data class PetSkinManifest(
    val id: String,
    val name: String,
    val version: String,
    val author: String,
    val license: String,
    val sourceUrl: String,
    val redistributionAllowed: Boolean,
    val canvasWidth: Int,
    val canvasHeight: Int,
    val actions: Map<String, PetClipSpec>,
) {
    fun requireAction(id: String): PetClipSpec = actions[id]
        ?: throw PetSkinFormatException("Missing pet action: $id")

    companion object {
        private const val MAX_ACTIONS = 64
        private const val MAX_FRAMES_PER_ACTION = 48

        fun load(
            assets: AssetManager,
            root: String = "pets/dafeiyu",
        ): PetSkinManifest {
            val json = assets.open("$root/pet.json")
                .bufferedReader(Charsets.UTF_8)
                .use { JSONObject(it.readText()) }
            return parse(json)
        }

        internal fun parse(json: JSONObject): PetSkinManifest {
            if (json.optInt("format_version") != 1) {
                throw PetSkinFormatException("Unsupported pet manifest version")
            }
            val id = safeIdentifier(json.requireText("id"), "id")
            val canvas = json.getJSONObject("canvas")
            val width = canvas.getInt("width")
            val height = canvas.getInt("height")
            if (width !in 32..2048 || height !in 32..2048) {
                throw PetSkinFormatException("Invalid canvas size: ${width}x$height")
            }

            val actionJson = json.getJSONObject("actions")
            if (actionJson.length() !in 1..MAX_ACTIONS) {
                throw PetSkinFormatException("Invalid action count")
            }
            val actions = linkedMapOf<String, PetClipSpec>()
            val keys = actionJson.keys()
            while (keys.hasNext()) {
                val actionId = safeIdentifier(keys.next(), "action")
                val item = actionJson.getJSONObject(actionId)
                val frameJson = item.getJSONArray("frames")
                if (frameJson.length() !in 1..MAX_FRAMES_PER_ACTION) {
                    throw PetSkinFormatException("Invalid frame count for $actionId")
                }
                val frames = buildList {
                    repeat(frameJson.length()) { index ->
                        add(safeAssetPath(frameJson.getString(index)))
                    }
                }
                val fps = item.optInt("fps", 8)
                if (fps !in 1..30) {
                    throw PetSkinFormatException("Invalid fps for $actionId: $fps")
                }
                actions[actionId] = PetClipSpec(
                    id = actionId,
                    frames = frames,
                    fps = fps,
                    loop = item.optBoolean("loop", false),
                    interruptible = item.optBoolean("interruptible", true),
                )
            }
            if (!actions.containsKey("idle")) {
                throw PetSkinFormatException("The idle action is required")
            }

            return PetSkinManifest(
                id = id,
                name = json.requireText("name"),
                version = json.requireText("version"),
                author = json.requireText("author"),
                license = json.requireText("license"),
                sourceUrl = json.requireText("source_url"),
                redistributionAllowed = json.optBoolean("redistribution_allowed", false),
                canvasWidth = width,
                canvasHeight = height,
                actions = actions,
            )
        }

        private fun safeIdentifier(value: String, label: String): String {
            if (!value.matches(Regex("[a-z0-9_\\-]{1,64}"))) {
                throw PetSkinFormatException("Invalid $label: $value")
            }
            return value
        }

        private fun safeAssetPath(value: String): String {
            val normalized = value.replace('\\', '/').trimStart('/')
            if (normalized.isBlank() || normalized.contains("..") ||
                !normalized.startsWith("actions/") || !normalized.endsWith(".png")
            ) {
                throw PetSkinFormatException("Unsafe pet asset path: $value")
            }
            return normalized
        }

        private fun JSONObject.requireText(key: String): String =
            optString(key).trim().takeIf { it.isNotEmpty() }
                ?: throw PetSkinFormatException("Missing $key")
    }
}

class PetSkinFormatException(message: String) : IllegalArgumentException(message)
