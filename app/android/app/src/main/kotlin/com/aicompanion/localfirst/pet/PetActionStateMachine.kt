package com.aicompanion.localfirst.pet

enum class PetActionSource(val priority: Int) {
    RANDOM_IDLE(10),
    DESIRE_EXPRESSION(20),
    NOTICE(30),
    SPEAK(40),
    SYSTEM(80),
    DRAG(100),
}

data class ActivePetAction(
    val actionId: String,
    val source: PetActionSource,
    val interruptible: Boolean,
    val startedAtMs: Long,
)

class PetActionStateMachine(
    private val idleActionId: String = "idle",
) {
    var active: ActivePetAction = ActivePetAction(
        actionId = idleActionId,
        source = PetActionSource.RANDOM_IDLE,
        interruptible = true,
        startedAtMs = 0L,
    )
        private set

    var paused: Boolean = false
        private set

    fun request(
        actionId: String,
        source: PetActionSource,
        interruptible: Boolean,
        nowMs: Long,
    ): Boolean {
        if (paused && source != PetActionSource.SYSTEM) return false
        if (!active.interruptible && source.priority <= active.source.priority) return false
        if (source.priority < active.source.priority) return false
        active = ActivePetAction(actionId, source, interruptible, nowMs)
        return true
    }

    fun complete(nowMs: Long): ActivePetAction {
        active = ActivePetAction(
            actionId = idleActionId,
            source = PetActionSource.RANDOM_IDLE,
            interruptible = true,
            startedAtMs = nowMs,
        )
        return active
    }

    fun setPaused(value: Boolean, nowMs: Long) {
        paused = value
        if (value) {
            active = ActivePetAction(
                actionId = idleActionId,
                source = PetActionSource.SYSTEM,
                interruptible = false,
                startedAtMs = nowMs,
            )
        } else {
            complete(nowMs)
        }
    }
}
