package com.aicompanion.localfirst.pet

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.os.SystemClock

class PetAnimationPlayer(
    private val manifest: PetSkinManifest,
    private val cache: PetFrameCache,
    private val onFrame: (Bitmap, String, Int) -> Unit,
    private val onActionChanged: (String) -> Unit = {},
) {
    private val handler = Handler(Looper.getMainLooper())
    private val state = PetActionStateMachine()
    private var frameIndex = 0
    private var running = false
    private var nextFrameAt = 0L

    private val tick = object : Runnable {
        override fun run() {
            if (!running || state.paused) return
            val now = SystemClock.uptimeMillis()
            val clip = manifest.requireAction(state.active.actionId)
            if (now >= nextFrameAt) {
                val path = clip.frames[frameIndex]
                onFrame(cache.get(path), clip.id, frameIndex)
                frameIndex += 1
                if (frameIndex >= clip.frames.size) {
                    if (clip.loop) {
                        frameIndex = 0
                    } else {
                        val idle = state.complete(now)
                        onActionChanged(idle.actionId)
                        frameIndex = 0
                    }
                }
                nextFrameAt = now + (1000L / clip.fps.coerceAtLeast(1))
            }
            handler.postDelayed(this, 12L)
        }
    }

    fun start() {
        if (running) return
        running = true
        frameIndex = 0
        nextFrameAt = 0L
        handler.post(tick)
    }

    fun stop() {
        running = false
        handler.removeCallbacks(tick)
    }

    fun setPaused(paused: Boolean) {
        state.setPaused(paused, SystemClock.uptimeMillis())
        if (paused) {
            handler.removeCallbacks(tick)
        } else if (running) {
            nextFrameAt = 0L
            handler.post(tick)
        }
    }

    fun play(actionId: String, source: PetActionSource = PetActionSource.NOTICE): Boolean {
        val clip = manifest.actions[actionId] ?: return false
        val accepted = state.request(
            actionId = actionId,
            source = source,
            interruptible = clip.interruptible,
            nowMs = SystemClock.uptimeMillis(),
        )
        if (!accepted) return false
        frameIndex = 0
        nextFrameAt = 0L
        onActionChanged(actionId)
        if (running) {
            handler.removeCallbacks(tick)
            handler.post(tick)
        }
        return true
    }
}
