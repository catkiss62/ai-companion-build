package com.aicompanion.localfirst.pet

data class PetAutonomySnapshot(
    val enabled: Boolean = false,
    val dominantDrive: String = "attachment",
    val driveLevel: Double = 0.0,
    val mood: String = "calm",
    val thoughtActive: Boolean = false,
    val thoughtStrength: Double = 0.0,
    val lateNight: Boolean = false,
) {
    companion object {
        private val drives = setOf(
            "attachment", "curiosity", "reflection", "duty",
            "social", "libido", "stress", "fatigue",
        )
        private val moods = setOf("calm", "sleepy", "tense", "warm", "curious", "reflective")

        fun fromChannel(value: Any?): PetAutonomySnapshot {
            val map = value as? Map<*, *> ?: return PetAutonomySnapshot()
            val drive = (map["dominant_drive"] as? String).orEmpty()
            val mood = (map["mood"] as? String).orEmpty()
            return PetAutonomySnapshot(
                enabled = map["enabled"] == true,
                dominantDrive = drive.takeIf(drives::contains) ?: "attachment",
                driveLevel = ((map["drive_level"] as? Number)?.toDouble() ?: 0.0)
                    .coerceIn(0.0, 1.0),
                mood = mood.takeIf(moods::contains) ?: "calm",
                thoughtActive = map["thought_active"] == true,
                thoughtStrength = ((map["thought_strength"] as? Number)?.toDouble() ?: 0.0)
                    .coerceIn(0.0, 1.0),
                lateNight = map["late_night"] == true,
            )
        }
    }
}

data class PetAutonomyDecision(
    val actionId: String,
    val semantic: Boolean,
    val queueSleepAfter: Boolean = false,
)

object PetMobilityPolicy {
    const val MOBILE = "mobile"
    const val STATIONARY = "stationary"

    fun normalized(value: String?): String =
        if (value == STATIONARY) STATIONARY else MOBILE
}

data class PetAutonomousMovementPlan(
    val actionId: String,
    val directions: List<String>,
    val continuous2D: Boolean,
)

object PetAutonomousMotionPolicy {
    fun plan(mode: String, dockedEdge: String): PetAutonomousMovementPlan? =
        when (PetMotionPolicy.normalized(mode)) {
            PetMotionPolicy.EDGE -> when (dockedEdge) {
                "left", "right" -> PetAutonomousMovementPlan(
                    actionId = "STROLLING",
                    directions = listOf("up", "down"),
                    continuous2D = false,
                )
                "top", "bottom" -> PetAutonomousMovementPlan(
                    actionId = "WALKING",
                    directions = listOf("left", "right"),
                    continuous2D = false,
                )
                else -> null
            }
            else -> PetAutonomousMovementPlan(
                actionId = "STROLLING",
                directions = listOf("left", "right", "up", "down"),
                continuous2D = true,
            )
        }
}

/**
 * Ambient visuals are always available while the pet overlay is idle. Durable
 * Desire/Thought state never owns this scheduler; it only adds a small number
 * of extra cards to the shuffled action bag.
 */
object PetAmbientActionPolicy {
    private val stationaryBase = listOf("BLINK", "GLANCE", "HAPPY", "SWEEPING", "EATING")

    fun candidates(
        snapshot: PetAutonomySnapshot,
        mobilityEnabled: Boolean,
    ): List<String> = buildList {
        if (mobilityEnabled) repeat(6) { add("STROLLING") }
        addAll(stationaryBase)
        if (!snapshot.enabled) return@buildList
        when (snapshot.dominantDrive) {
            "curiosity" -> if (mobilityEnabled) {
                repeat(2) { add("STROLLING") }
            } else {
                add("GLANCE")
            }
            "duty" -> add("SWEEPING")
            "attachment", "social", "libido" -> add("HAPPY")
            "stress" -> add("GLANCE")
            "reflection" -> add("GLANCE")
        }
        when (snapshot.mood) {
            "warm" -> add("HAPPY")
            "curious" -> if (mobilityEnabled) add("STROLLING") else add("GLANCE")
            "tense", "reflective" -> add("GLANCE")
        }
    }

    fun nextDelayMs(randomUnit: Double): Long {
        val unit = randomUnit.coerceIn(0.0, 0.999999)
        return 8_000L + (unit * 12_000L).toLong()
    }
}

/**
 * High-priority semantic reactions remain deterministic. They are evaluated
 * before the random ambient bag and never create or mutate durable state.
 */
object PetAutonomyPolicy {
    const val MIN_AMBIENT_IDLE_MS = 6_000L
    const val MIN_SEMANTIC_IDLE_MS = 45_000L
    const val SLEEP_IDLE_MS = 180_000L

    fun chooseSemantic(
        snapshot: PetAutonomySnapshot,
        idleMs: Long,
        semanticReady: Boolean,
        mobilityEnabled: Boolean,
    ): PetAutonomyDecision? {
        if (!snapshot.enabled || !semanticReady || idleMs < MIN_SEMANTIC_IDLE_MS) return null
        if (snapshot.mood == "sleepy" || snapshot.dominantDrive == "fatigue") {
            return PetAutonomyDecision(
                actionId = "YAWNING",
                semantic = true,
                queueSleepAfter = idleMs >= SLEEP_IDLE_MS,
            )
        }
        if (snapshot.thoughtActive && snapshot.thoughtStrength >= 0.50) {
            return PetAutonomyDecision("THINKING", semantic = true)
        }
        if (snapshot.dominantDrive == "stress" && snapshot.driveLevel >= 0.48) {
            return PetAutonomyDecision("GLANCE", semantic = true)
        }
        if (snapshot.driveLevel >= 0.62) {
            return when (snapshot.dominantDrive) {
                "curiosity" -> PetAutonomyDecision(
                    if (mobilityEnabled) "STROLLING" else "GLANCE",
                    semantic = true,
                )
                "reflection" -> PetAutonomyDecision("THINKING", semantic = true)
                "duty" -> PetAutonomyDecision("SWEEPING", semantic = true)
                "attachment", "social", "libido" ->
                    PetAutonomyDecision("HAPPY", semantic = true)
                else -> null
            }
        }
        return when (snapshot.mood) {
            "warm" -> PetAutonomyDecision("HAPPY", semantic = true)
            "curious" -> PetAutonomyDecision(
                if (mobilityEnabled) "STROLLING" else "GLANCE",
                semantic = true,
            )
            "reflective" -> PetAutonomyDecision("THINKING", semantic = true)
            "tense" -> PetAutonomyDecision("GLANCE", semantic = true)
            else -> null
        }
    }
}
