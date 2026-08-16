package com.aicompanion.localfirst.pet

import android.content.res.AssetManager
import org.json.JSONObject
import kotlin.math.abs

enum class PetAnimationPhase { ENTER, BODY, EXIT }

data class PetAnchor(
    val kind: String = "ground",
    val x: Float = 0.5f,
    val y: Float = 0.985f,
)

data class PetSegmentSpec(
    val assetId: String,
    val durationMs: Long,
    val effect: String?,
)

data class PetAssetSpec(
    val id: String,
    val framesBySize: Map<Int, List<String>>,
    val frameCount: Int,
) {
    fun framesNearestTo(targetHeight: Int): Pair<List<String>, Int> {
        val size = framesBySize.keys.minByOrNull { abs(it - targetHeight) }
            ?: throw PetSkinFormatException("Asset $id has no runtime frames")
        return (framesBySize[size]
            ?: throw PetSkinFormatException("Asset $id is missing size $size")) to size
    }
}

data class PetActionSpec(
    val id: String,
    val assetId: String,
    val loop: Boolean,
    val durationMs: Long?,
    val priority: Int,
    val interruptible: Boolean,
    val returnState: String,
    val anchor: PetAnchor,
    val effect: String,
    val enter: PetSegmentSpec?,
    val exit: PetSegmentSpec?,
)

data class PetAnimationClip(
    val actionId: String,
    val assetId: String,
    val frames: List<String>,
    val selectedSize: Int,
    val loop: Boolean,
    val durationMs: Long?,
    val frameDurationMs: Long,
    val anchor: PetAnchor,
    val effect: String,
    val phase: PetAnimationPhase = PetAnimationPhase.BODY,
    val mirrored: Boolean = false,
)

data class PetAnimationProgram(
    val actionId: String,
    val body: PetAnimationClip,
    val enter: PetAnimationClip?,
    val exit: PetAnimationClip?,
)

data class PetSkinManifest(
    val formatVersion: Int,
    val characterId: String,
    val assets: Map<String, PetAssetSpec>,
    val actions: Map<String, PetActionSpec>,
) {
    fun requireAction(id: String): PetActionSpec = actions[id]
        ?: throw PetSkinFormatException("Missing pet action: $id")

    fun clipFor(actionId: String, targetHeight: Int, direction: String): PetAnimationClip {
        val action = requireAction(actionId)
        val assetId = directionalAsset(actionId, action.assetId, direction)
        val (sourceFrames, selectedSize) = requireAsset(assetId).framesNearestTo(targetHeight)
        // Preserve the authoring order for both walk directions: 00 -> 01 -> 02 -> 03.
        val frames = sourceFrames
        return PetAnimationClip(
            actionId = actionId,
            assetId = assetId,
            frames = frames,
            selectedSize = selectedSize,
            loop = action.loop,
            durationMs = action.durationMs,
            frameDurationMs = frameDuration(action, frames.size),
            anchor = action.anchor,
            effect = action.effect,
            mirrored = direction == "right" && actionId in setOf("STROLLING", "WALKING"),
        )
    }

    fun programFor(actionId: String, targetHeight: Int, direction: String): PetAnimationProgram {
        val action = requireAction(actionId)
        val enter = segmentClip(action, action.enter, PetAnimationPhase.ENTER, targetHeight, direction)
        val normalBody = clipFor(actionId, targetHeight, direction)
        val body = if (actionId == "SLEEPING" && enter?.frames?.isNotEmpty() == true) {
            // The upstream single-frame sleep body is roughly 27% larger than
            // the visually identical last sleep-enter pose. Keep the authored
            // transition, then hold that final pose for the sleep loop.
            normalBody.copy(
                assetId = enter.assetId,
                frames = listOf(enter.frames.last()),
                selectedSize = enter.selectedSize,
                frameDurationMs = frameDuration(action, 1),
                mirrored = enter.mirrored,
            )
        } else {
            normalBody
        }
        return PetAnimationProgram(
            actionId = actionId,
            body = body,
            enter = enter,
            exit = segmentClip(action, action.exit, PetAnimationPhase.EXIT, targetHeight, direction),
        )
    }

    private fun segmentClip(
        action: PetActionSpec,
        segment: PetSegmentSpec?,
        phase: PetAnimationPhase,
        targetHeight: Int,
        direction: String,
    ): PetAnimationClip? {
        segment ?: return null
        val mirrorLeftWalk = action.id == "WALKING" && direction == "right"
        val assetId = if (mirrorLeftWalk) {
            segment.assetId
        } else {
            directionalTransitionAsset(segment.assetId, direction)
        }
        val (frames, selectedSize) = requireAsset(assetId).framesNearestTo(targetHeight)
        return PetAnimationClip(
            actionId = action.id,
            assetId = assetId,
            frames = frames,
            selectedSize = selectedSize,
            loop = false,
            durationMs = segment.durationMs,
            frameDurationMs = maxOf(55L, segment.durationMs / maxOf(1, frames.size)),
            anchor = action.anchor,
            effect = segment.effect ?: action.effect,
            phase = phase,
            mirrored = mirrorLeftWalk,
        )
    }

    private fun requireAsset(id: String): PetAssetSpec = assets[id]
        ?: throw PetSkinFormatException("Missing pet asset: $id")

    private fun directionalAsset(actionId: String, defaultAsset: String, direction: String): String {
        if (actionId == "IDLE" || actionId == "THINKING") {
            return when {
                direction == "up" -> "idle_back"
                actionId == "THINKING" -> "idle_think"
                else -> "idle_front"
            }
        }
        if (actionId == "STROLLING") {
            return when (direction) {
                "up" -> "idle_back"
                "down" -> "idle_front"
                "left", "right" -> "walk_side_stand"
                else -> defaultAsset
            }
        }
        if (actionId == "WALKING") {
            // The authored left gait is the stable source of truth; mirror the whole program for right.
            return defaultAsset
        }
        return defaultAsset
    }

    private fun directionalTransitionAsset(assetId: String, direction: String): String =
        if (direction == "right" && assetId.endsWith("_left")) {
            assetId.removeSuffix("_left") + "_right"
        } else {
            assetId
        }

    private fun frameDuration(action: PetActionSpec, frameCount: Int): Long {
        if (frameCount <= 0) return 120L
        action.durationMs?.let { return maxOf(70L, it / frameCount) }
        return if (action.id == "WALKING") 120L else 180L
    }

    companion object {
        const val SOURCE_ROOT = "pets/dafeiyu/source"
        const val MANIFEST_PATH = "$SOURCE_ROOT/assets/manifests/actions.json"
        private const val MAX_ACTIONS = 64
        private const val MAX_ASSETS = 128
        private const val MAX_FRAMES_PER_SIZE = 48

        fun load(assets: AssetManager): PetSkinManifest {
            val json = assets.open(MANIFEST_PATH)
                .bufferedReader(Charsets.UTF_8)
                .use { JSONObject(it.readText()) }
            return parse(json)
        }

        internal fun parse(json: JSONObject): PetSkinManifest {
            val formatVersion = json.optInt("format_version")
            if (formatVersion != 4) {
                throw PetSkinFormatException("Unsupported upstream action manifest: $formatVersion")
            }
            val characterId = safeIdentifier(json.requireText("character_id"), "character_id")
            val assets = parseAssets(json.getJSONObject("assets"))
            val actions = parseActions(json.getJSONObject("actions"))
            if (actions.keys != EXPECTED_ACTION_IDS) {
                throw PetSkinFormatException("Upstream action set changed: ${actions.keys}")
            }
            actions.values.forEach { action ->
                if (!assets.containsKey(action.assetId)) {
                    throw PetSkinFormatException("Action ${action.id} references missing asset ${action.assetId}")
                }
                listOfNotNull(action.enter, action.exit).forEach { segment ->
                    if (!assets.containsKey(segment.assetId) &&
                        !assets.containsKey(segment.assetId.removeSuffix("_left") + "_right")
                    ) {
                        throw PetSkinFormatException(
                            "Action ${action.id} references missing segment ${segment.assetId}",
                        )
                    }
                }
            }
            val runtimeAssets = LinkedHashMap(assets)
            val runtimeActions = LinkedHashMap(actions)
            installRuntimeActions(runtimeAssets, runtimeActions)
            return PetSkinManifest(formatVersion, characterId, runtimeAssets, runtimeActions)
        }

        /**
         * Keep upstream registration strict, then add Android-only visual states.
         * The sleepy-yawn source is normalized into the same three runtime tiers
         * as sleep-enter, preserving the original art without pose splicing.
         */
        private fun installRuntimeActions(
            assets: MutableMap<String, PetAssetSpec>,
            actions: MutableMap<String, PetActionSpec>,
        ) {
            require(assets.containsKey("idle_front"))
            require(assets.containsKey("walk_side_stand"))
            assets["sleepy_yawn_runtime"] = PetAssetSpec(
                id = "sleepy_yawn_runtime",
                framesBySize = mapOf(
                    187 to listOf("runtime_overrides/yawning/sleepy_yawn_187.png"),
                    238 to listOf("runtime_overrides/yawning/sleepy_yawn_238.png"),
                    306 to listOf("runtime_overrides/yawning/sleepy_yawn_306.png"),
                ),
                frameCount = 1,
            )
            actions["YAWNING"] = PetActionSpec(
                id = "YAWNING",
                assetId = "sleepy_yawn_runtime",
                loop = false,
                durationMs = 1_800L,
                priority = 24,
                interruptible = true,
                returnState = "IDLE",
                anchor = PetAnchor(),
                effect = "yawn_sway",
                enter = null,
                exit = null,
            )
            actions["STROLLING"] = PetActionSpec(
                id = "STROLLING",
                assetId = "idle_front",
                loop = true,
                durationMs = null,
                priority = 30,
                interruptible = true,
                returnState = "IDLE",
                anchor = PetAnchor(),
                effect = "stroll",
                enter = null,
                exit = null,
            )
        }

        private fun parseAssets(json: JSONObject): Map<String, PetAssetSpec> {
            if (json.length() !in 1..MAX_ASSETS) {
                throw PetSkinFormatException("Invalid upstream asset count")
            }
            val result = linkedMapOf<String, PetAssetSpec>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val id = safeIdentifier(keys.next(), "asset")
                val item = json.getJSONObject(id)
                val framesJson = item.getJSONObject("frames")
                val framesBySize = linkedMapOf<Int, List<String>>()
                val sizes = framesJson.keys()
                while (sizes.hasNext()) {
                    val sizeText = sizes.next()
                    val size = sizeText.toIntOrNull()
                        ?: throw PetSkinFormatException("Invalid frame size: $sizeText")
                    if (size !in 32..2048) {
                        throw PetSkinFormatException("Invalid frame size: $size")
                    }
                    val array = framesJson.getJSONArray(sizeText)
                    if (array.length() !in 1..MAX_FRAMES_PER_SIZE) {
                        throw PetSkinFormatException("Invalid frame count for $id/$size")
                    }
                    framesBySize[size] = buildList {
                        repeat(array.length()) { index -> add(safeAssetPath(array.getString(index))) }
                    }
                }
                val declaredCount = item.optInt("frame_count", -1)
                if (declaredCount <= 0 || framesBySize.values.any { it.size != declaredCount }) {
                    throw PetSkinFormatException("Frame count mismatch for $id")
                }
                result[id] = PetAssetSpec(id, framesBySize, declaredCount)
            }
            return result
        }

        private fun parseActions(json: JSONObject): Map<String, PetActionSpec> {
            if (json.length() !in 1..MAX_ACTIONS) {
                throw PetSkinFormatException("Invalid upstream action count")
            }
            val result = linkedMapOf<String, PetActionSpec>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val rawKey = keys.next()
                val item = json.getJSONObject(rawKey)
                val id = safeActionId(item.optString("id", rawKey))
                val anchorJson = item.optJSONObject("anchor") ?: JSONObject()
                val transitionJson = item.optJSONObject("transition") ?: JSONObject()
                val duration = item.optLong("duration_ms", -1L).takeIf { it > 0L }
                result[id] = PetActionSpec(
                    id = id,
                    assetId = safeIdentifier(item.requireText("asset"), "asset"),
                    loop = item.optBoolean("loop", false),
                    durationMs = duration,
                    priority = item.optInt("priority", 0),
                    interruptible = item.optBoolean("interruptible", true),
                    returnState = safeActionId(item.optString("return_state", "IDLE")),
                    anchor = PetAnchor(
                        kind = safeIdentifier(anchorJson.optString("type", "ground"), "anchor"),
                        x = anchorJson.optDouble("x", 0.5).toFloat(),
                        y = anchorJson.optDouble("y", 0.985).toFloat(),
                    ),
                    effect = safeIdentifier(
                        item.optJSONObject("procedural_motion")?.optString("type", "breath")
                            ?: "breath",
                        "effect",
                    ),
                    enter = parseSegment(transitionJson.optJSONObject("enter")),
                    exit = parseSegment(transitionJson.optJSONObject("exit")),
                )
            }
            return result
        }

        private fun parseSegment(json: JSONObject?): PetSegmentSpec? {
            json ?: return null
            val duration = json.optLong("duration_ms", -1L)
            if (duration <= 0L) return null
            return PetSegmentSpec(
                assetId = safeIdentifier(json.requireText("asset"), "segment asset"),
                durationMs = duration,
                effect = json.optString("effect").trim().takeIf { it.isNotEmpty() }
                    ?.let { safeIdentifier(it, "segment effect") },
            )
        }

        private fun safeActionId(value: String): String {
            if (!value.matches(Regex("[A-Z0-9_]{1,64}"))) {
                throw PetSkinFormatException("Invalid action id: $value")
            }
            return value
        }

        private fun safeIdentifier(value: String, label: String): String {
            if (!value.matches(Regex("[A-Za-z0-9_\\-]{1,96}"))) {
                throw PetSkinFormatException("Invalid $label: $value")
            }
            return value
        }

        private fun safeAssetPath(value: String): String {
            val normalized = value.replace('\\', '/').trimStart('/')
            if (normalized.isBlank() || normalized.contains("..") ||
                !normalized.startsWith("assets/processed/runtime/") ||
                !normalized.endsWith(".png")
            ) {
                throw PetSkinFormatException("Unsafe upstream runtime path: $value")
            }
            return normalized
        }

        private fun JSONObject.requireText(key: String): String =
            optString(key).trim().takeIf { it.isNotEmpty() }
                ?: throw PetSkinFormatException("Missing $key")

        val EXPECTED_ACTION_IDS: Set<String> = linkedSetOf(
            "IDLE", "BLINK", "GLANCE", "THINKING", "WALKING", "HAPPY",
            "HEAD_PAT", "TALKING", "ANGRY", "POKE_REACT", "TAIL_REACT",
            "EATING", "SWEEPING", "SLEEPING", "DRAGGING", "FALLING",
            "LANDING", "DIZZY",
        )
    }
}

class PetSkinFormatException(message: String) : IllegalArgumentException(message)
