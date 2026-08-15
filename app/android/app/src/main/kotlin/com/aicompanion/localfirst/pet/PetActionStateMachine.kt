package com.aicompanion.localfirst.pet

data class PetStateChange(
    val previous: String,
    val current: String,
    val reason: String,
)

/** Direct Kotlin port of ds-local-pet/animation/state_machine.py semantics. */
class PetActionStateMachine(
    private val specs: Map<String, PetActionSpec>,
    startAtMs: Long = 0L,
) {
    init {
        require(specs.containsKey("IDLE")) { "IDLE action is required" }
    }

    var current: String = "IDLE"
        private set

    var enteredAtMs: Long = startAtMs
        private set

    var reason: String = "startup"
        private set

    private var queuedAfter: String? = null

    val spec: PetActionSpec
        get() = specs[current] ?: error("Missing action spec: $current")

    fun request(
        target: String,
        nowMs: Long,
        reason: String,
        force: Boolean = false,
    ): PetStateChange? {
        if (target == current) return null
        val candidate = specs[target] ?: return null
        val active = spec
        if (!force) {
            if (!active.interruptible && candidate.priority <= active.priority) return null
            if (candidate.priority < active.priority) return null
        }
        val previous = current
        current = target
        enteredAtMs = nowMs
        this.reason = reason
        queuedAfter = null
        return PetStateChange(previous, target, reason)
    }

    fun queueAfterCurrent(target: String) {
        require(specs.containsKey(target)) { "Unknown queued action: $target" }
        queuedAfter = target
    }

    fun update(nowMs: Long): PetStateChange? {
        val active = spec
        val durationMs = active.durationMs
        if (active.loop || durationMs == null) return null
        if (nowMs - enteredAtMs < durationMs) return null
        val target = queuedAfter ?: active.returnState
        val previous = current
        current = target
        enteredAtMs = nowMs
        reason = "${previous.lowercase()}_complete"
        queuedAfter = null
        return PetStateChange(previous, target, reason)
    }

    fun forceIdle(nowMs: Long, reason: String = "preview_reset"): PetStateChange? =
        request("IDLE", nowMs, reason, force = true)
}
