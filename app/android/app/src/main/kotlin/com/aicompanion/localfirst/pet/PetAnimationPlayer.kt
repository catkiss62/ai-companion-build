package com.aicompanion.localfirst.pet

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.os.SystemClock

data class PetRenderLayer(
    val bitmap: Bitmap,
    val actionId: String,
    val assetId: String,
    val frameIndex: Int,
    val anchor: PetAnchor,
    val phase: PetAnimationPhase,
    val mirrored: Boolean,
)

data class PetRenderSnapshot(
    val current: PetRenderLayer,
    val previous: PetRenderLayer?,
    val currentOpacity: Float,
    val previousOpacity: Float,
    val elapsedSeconds: Float,
    val effect: String,
    val selectedSize: Int,
    val phase: PetAnimationPhase,
)

/**
 * Android port of ds-local-pet's manifest registry, three-phase player and state update loop.
 * The upstream actions.json remains the source of truth.
 */
class PetAnimationPlayer(
    private val manifest: PetSkinManifest,
    private val cache: PetFrameCache,
    private val onSnapshot: (PetRenderSnapshot) -> Unit,
    private val onActionChanged: (PetActionSpec, PetAnimationPhase) -> Unit = { _, _ -> },
) {
    private val handler = Handler(Looper.getMainLooper())
    private var state = PetActionStateMachine(manifest.actions)
    private var running = false
    private var paused = false
    private var lastTickAtMs = 0L
    private var targetHeight = 238
    private var direction = "left"

    private var program: PetAnimationProgram = manifest.programFor("IDLE", targetHeight, direction)
    private var clip: PetAnimationClip = program.body
    private var phase: PetAnimationPhase = PetAnimationPhase.BODY
    private var pendingProgram: PetAnimationProgram? = null
    private var pendingCrossfade = true
    private var elapsedMs = 0L
    private var previousLayer: PetRenderLayer? = null
    private var crossfadeElapsedMs = CROSSFADE_MS

    val currentActionId: String
        get() = state.current

    val currentPhase: PetAnimationPhase
        get() = phase

    private val tick = object : Runnable {
        override fun run() {
            if (!running || paused) return
            val now = SystemClock.uptimeMillis()
            val delta = if (lastTickAtMs == 0L) 0L else (now - lastTickAtMs).coerceIn(0L, 100L)
            lastTickAtMs = now
            advancePlayer(delta)
            state.update(now)?.let {
                switchToState(state.current, crossfade = true, immediate = false)
                onActionChanged(manifest.requireAction(state.current), phase)
            }
            emitSnapshot()
            handler.postDelayed(this, TICK_MS)
        }
    }

    fun start() {
        if (running) return
        running = true
        paused = false
        lastTickAtMs = 0L
        emitSnapshot()
        handler.post(tick)
    }

    fun stop() {
        running = false
        handler.removeCallbacks(tick)
    }

    fun setPaused(value: Boolean) {
        paused = value
        handler.removeCallbacks(tick)
        if (!value && running) {
            lastTickAtMs = 0L
            handler.post(tick)
        }
    }

    fun setTargetHeight(value: Int) {
        if (value == targetHeight) return
        targetHeight = value
        switchToState(state.current, crossfade = false, immediate = true)
        emitSnapshot()
    }

    fun setDirection(value: String) {
        require(value in setOf("left", "right", "up", "down"))
        if (value == direction) return
        direction = value
        if (state.current in setOf("IDLE", "THINKING", "STROLLING", "WALKING")) {
            activateProgram(
                manifest.programFor(state.current, targetHeight, direction),
                crossfade = true,
                startWithEnter = false,
            )
            emitSnapshot()
        }
    }

    fun play(
        actionId: String,
        reason: String = "preview",
        force: Boolean = false,
        immediate: Boolean = false,
    ): Boolean {
        val now = SystemClock.uptimeMillis()
        val change = state.request(actionId, now, reason, force) ?: return false
        switchToState(change.current, crossfade = true, immediate = immediate)
        onActionChanged(manifest.requireAction(change.current), phase)
        if (running && !paused) {
            lastTickAtMs = now
            handler.removeCallbacks(tick)
            handler.post(tick)
        }
        return true
    }

    fun queueAfterCurrent(actionId: String) {
        state.queueAfterCurrent(actionId)
    }

    fun resetToIdle(reason: String = "preview_reset") {
        val now = SystemClock.uptimeMillis()
        state.forceIdle(now, reason)
        switchToState("IDLE", crossfade = false, immediate = true)
        onActionChanged(manifest.requireAction("IDLE"), phase)
        emitSnapshot()
    }

    fun returnToIdle(
        directionValue: String = "down",
        reason: String = "pet_motion_complete",
    ) {
        require(directionValue in setOf("left", "right", "up", "down"))
        val now = SystemClock.uptimeMillis()
        direction = directionValue
        if (state.forceIdle(now, reason) == null) return
        switchToState("IDLE", crossfade = true, immediate = false)
        onActionChanged(manifest.requireAction("IDLE"), phase)
        emitSnapshot()
    }

    private fun switchToState(actionId: String, crossfade: Boolean, immediate: Boolean) {
        val next = manifest.programFor(actionId, targetHeight, direction)
        val currentExit = program.exit
        if (!immediate && currentExit != null && program.actionId != next.actionId) {
            pendingProgram = next
            pendingCrossfade = crossfade
            if (phase != PetAnimationPhase.EXIT) {
                activateClip(currentExit, crossfade = false)
            }
            return
        }
        activateProgram(next, crossfade, startWithEnter = true)
    }

    private fun activateProgram(
        next: PetAnimationProgram,
        crossfade: Boolean,
        startWithEnter: Boolean,
    ) {
        program = next
        pendingProgram = null
        activateClip(if (startWithEnter) next.enter ?: next.body else next.body, crossfade)
    }

    private fun activateClip(next: PetAnimationClip, crossfade: Boolean) {
        val prior = currentLayer()
        val keepPrevious = crossfade &&
            prior.assetId == next.assetId &&
            prior.anchor == next.anchor
        previousLayer = if (keepPrevious) prior else null
        crossfadeElapsedMs = if (keepPrevious) 0L else CROSSFADE_MS
        clip = next
        phase = next.phase
        elapsedMs = 0L
        onActionChanged(manifest.requireAction(next.actionId), phase)
    }

    private fun advancePlayer(deltaMs: Long) {
        var remaining = deltaMs.coerceAtLeast(0L)
        while (remaining > 0L) {
            val phaseDuration = clip.durationMs.takeIf {
                phase == PetAnimationPhase.ENTER || phase == PetAnimationPhase.EXIT
            }
            val advance = phaseDuration?.let { minOf(remaining, maxOf(0L, it - elapsedMs)) }
                ?: remaining
            elapsedMs += advance
            crossfadeElapsedMs = minOf(CROSSFADE_MS, crossfadeElapsedMs + advance)
            remaining -= advance

            if (phaseDuration == null || elapsedMs < phaseDuration) break
            if (phase == PetAnimationPhase.ENTER) {
                activateClip(program.body, crossfade = false)
                continue
            }
            if (phase == PetAnimationPhase.EXIT) {
                val pending = pendingProgram ?: break
                val crossfade = pendingCrossfade
                activateProgram(pending, crossfade, startWithEnter = true)
                continue
            }
            break
        }
        if (crossfadeElapsedMs >= CROSSFADE_MS) previousLayer = null
    }

    private fun currentLayer(): PetRenderLayer {
        val count = clip.frames.size
        var index = (elapsedMs / maxOf(1L, clip.frameDurationMs)).toInt()
        index = if (clip.loop) index % count else minOf(count - 1, index)
        return PetRenderLayer(
            bitmap = cache.get(clip.frames[index]),
            actionId = clip.actionId,
            assetId = clip.assetId,
            frameIndex = index,
            anchor = clip.anchor,
            phase = phase,
            mirrored = clip.mirrored,
        )
    }

    private fun emitSnapshot() {
        val previous = previousLayer
        val ratio = if (previous == null || CROSSFADE_MS <= 0L) {
            1f
        } else {
            (crossfadeElapsedMs.toFloat() / CROSSFADE_MS.toFloat()).coerceIn(0f, 1f)
        }
        val smooth = ratio * ratio * (3f - 2f * ratio)
        onSnapshot(
            PetRenderSnapshot(
                current = currentLayer(),
                previous = previous,
                currentOpacity = if (previous == null) 1f else smooth,
                previousOpacity = if (previous == null) 0f else 1f - smooth,
                elapsedSeconds = elapsedMs / 1000f,
                effect = clip.effect,
                selectedSize = clip.selectedSize,
                phase = phase,
            ),
        )
    }

    companion object {
        private const val TICK_MS = 12L
        private const val CROSSFADE_MS = 90L
    }
}
