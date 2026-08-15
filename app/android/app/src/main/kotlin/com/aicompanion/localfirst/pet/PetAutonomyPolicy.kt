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

/**
 * Pure visual consumer for durable Desire/Thought state.
 *
 * It cannot create wants, send messages, mutate the database or bypass the
 * conversation/touch/physics arbiter. Stable cadence buckets replace a second
 * random personality system: identical state and idle time produce the same
 * visual choice.
 */
data class PetAutonomousMovementPlan(
    val actionId: String,
    val directions: List<String>,
)

object PetAutonomousMotionPolicy {
    fun plan(mode: String, dockedEdge: String): PetAutonomousMovementPlan? =
        when (PetMotionPolicy.normalized(mode)) {
            PetMotionPolicy.EDGE -> when (dockedEdge) {
                "left", "right" ->
                    PetAutonomousMovementPlan("STROLLING", listOf("up", "down"))
                "top", "bottom" ->
                    PetAutonomousMovementPlan("WALKING", listOf("left", "right"))
                else -> null
            }
            else -> PetAutonomousMovementPlan(
                "STROLLING",
                listOf("left", "right", "up", "down"),
            )
        }
}

object PetAutonomyPolicy {
    const val MIN_MICRO_IDLE_MS = 9_000L
    const val MIN_DAILY_IDLE_MS = 30_000L
    const val MIN_SEMANTIC_IDLE_MS = 45_000L
    const val SLEEP_IDLE_MS = 180_000L

    fun choose(
        snapshot: PetAutonomySnapshot,
        idleMs: Long,
        semanticReady: Boolean,
        microReady: Boolean,
        cadenceBucket: Long,
        dailyReady: Boolean = false,
    ): PetAutonomyDecision? {
        if (!snapshot.enabled || idleMs < MIN_MICRO_IDLE_MS) return null

        // Urgent durable state keeps priority over cosmetic daily motion.
        if (semanticReady && idleMs >= MIN_SEMANTIC_IDLE_MS) {
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
        }

        if (dailyReady && idleMs >= MIN_DAILY_IDLE_MS) {
            return PetAutonomyDecision(
                actionId = if (cadenceBucket % 5L == 0L) "SWEEPING" else "STROLLING",
                semantic = false,
            )
        }

        if (semanticReady && idleMs >= MIN_SEMANTIC_IDLE_MS) {
            if (snapshot.driveLevel >= 0.48) {
                return when (snapshot.dominantDrive) {
                    "curiosity" -> PetAutonomyDecision("STROLLING", semantic = true)
                    "reflection", "duty" -> PetAutonomyDecision("THINKING", semantic = true)
                    "attachment", "social", "libido" ->
                        PetAutonomyDecision("HAPPY", semantic = true)
                    else -> null
                }
            }
            return when (snapshot.mood) {
                "warm" -> PetAutonomyDecision("HAPPY", semantic = true)
                "curious" -> PetAutonomyDecision("STROLLING", semantic = true)
                "reflective" -> PetAutonomyDecision("THINKING", semantic = true)
                "tense" -> PetAutonomyDecision("GLANCE", semantic = true)
                else -> null
            }
        }

        if (!microReady) return null
        return PetAutonomyDecision(
            actionId = if (cadenceBucket % 4L == 0L) "GLANCE" else "BLINK",
            semantic = false,
        )
    }
}
