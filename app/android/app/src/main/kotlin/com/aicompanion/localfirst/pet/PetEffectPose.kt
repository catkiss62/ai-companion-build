package com.aicompanion.localfirst.pet

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

data class PetEffectPose(
    val offsetX: Float = 0f,
    val offsetY: Float = 0f,
    val scaleX: Float = 1f,
    val scaleY: Float = 1f,
    val rotationDegrees: Float = 0f,
    val shadowScale: Float = 1f,
    val shadowOpacity: Float = 0.22f,
    val decoration: String? = null,
)

/** Formula-for-formula port of ds-local-pet/animation/effects.py. */
object PetEffects {
    fun poseFor(effect: String, elapsedSeconds: Float): PetEffectPose {
        val time = max(0f, elapsedSeconds)
        val breath = sin(time * 2.35f)
        return when (effect) {
            "breath" -> PetEffectPose(
                scaleX = 1f - breath * 0.006f,
                scaleY = 1f + breath * 0.012f,
            )
            "micro_idle" -> PetEffectPose(
                offsetY = breath * 0.35f,
                scaleX = 1f - breath * 0.002f,
                scaleY = 1f + breath * 0.004f,
                shadowOpacity = 0.20f,
            )
            "think" -> {
                val sway = sin(time * 2.2f)
                PetEffectPose(
                    offsetY = -1.5f + breath * 1.1f,
                    rotationDegrees = sway * 1.8f,
                    scaleY = 1f + breath * 0.009f,
                    decoration = "thought",
                )
            }
            "walk_frames" -> {
                val phase = sin(time * (PI * 2.0 * 2.08)).toFloat()
                PetEffectPose(
                    offsetY = -abs(phase) * 0.75f,
                    shadowScale = 1f - abs(phase) * 0.05f,
                    shadowOpacity = 0.20f,
                )
            }
            "walk_start" -> {
                val progress = min(1f, time / 0.26f)
                val anticipation = sin(progress * PI).toFloat()
                PetEffectPose(
                    offsetY = anticipation * 1.2f,
                    scaleX = 1f + anticipation * 0.018f,
                    scaleY = 1f - anticipation * 0.025f,
                    shadowScale = 1f + anticipation * 0.05f,
                    shadowOpacity = 0.20f,
                )
            }
            "walk_stop" -> {
                val settle = (exp((-time * 12f).toDouble()) * cos((time * 24f).toDouble())).toFloat()
                PetEffectPose(
                    offsetY = abs(settle) * 0.8f,
                    scaleX = 1f + settle * 0.012f,
                    scaleY = 1f - settle * 0.018f,
                    shadowScale = 1f + settle * 0.04f,
                    shadowOpacity = 0.20f,
                )
            }
            "bounce" -> {
                // HAPPY lasts 1.05 s: 1.9047619 Hz makes exactly two complete hops.
                val phase = max(0f, sin(time * PI.toFloat() * 2f * 1.9047619f))
                PetEffectPose(
                    offsetY = -phase * 10f,
                    scaleX = 1f + phase * 0.018f,
                    scaleY = 1f - phase * 0.024f,
                    shadowScale = 1f - phase * 0.23f,
                )
            }
            "stroll" -> {
                val sway = sin(time * PI.toFloat() * 2f * 1.35f)
                val step = abs(sin(time * PI.toFloat() * 2f * 2.70f))
                PetEffectPose(
                    offsetY = -step * 1.8f,
                    rotationDegrees = sway * 2.2f,
                    shadowScale = 1f - step * 0.06f,
                    shadowOpacity = 0.20f,
                )
            }
            "yawn_sway" -> {
                val tired = sin(time * PI.toFloat() * 1.15f)
                PetEffectPose(
                    offsetY = -abs(tired) * 1.1f,
                    rotationDegrees = tired * 1.5f,
                    scaleX = 1f - tired * 0.004f,
                    scaleY = 1f + tired * 0.010f,
                    shadowOpacity = 0.20f,
                )
            }
            "head_pat" -> {
                val settle = (exp((-time * 4.8f).toDouble()) * sin((time * 9f).toDouble())).toFloat()
                PetEffectPose(
                    offsetY = abs(settle) * 0.8f,
                    scaleX = 1f + settle * 0.003f,
                    scaleY = 1f - settle * 0.005f,
                    shadowOpacity = 0.20f,
                )
            }
            "talk" -> {
                val phase = sin(time * 7.6f)
                PetEffectPose(
                    offsetY = -abs(phase) * 1.8f,
                    rotationDegrees = phase * 0.7f,
                    decoration = "voice",
                )
            }
            "angry" -> {
                val phase = sin(time * 20f)
                PetEffectPose(
                    offsetX = phase * 2.5f,
                    rotationDegrees = phase * 1.1f,
                )
            }
            "poke_frames" -> {
                val impulse = exp((-time * 7f).toDouble()).toFloat()
                PetEffectPose(
                    offsetX = -impulse * 2f,
                    rotationDegrees = -impulse * 0.8f,
                    shadowOpacity = 0.20f,
                )
            }
            "tail_react" -> {
                val settle = (exp((-time * 5.5f).toDouble()) * sin((time * 13f).toDouble())).toFloat()
                PetEffectPose(
                    offsetX = settle * 0.8f,
                    rotationDegrees = settle * 0.7f,
                    shadowOpacity = 0.20f,
                )
            }
            "eat" -> {
                val phase = max(0f, sin(time * 11f))
                PetEffectPose(
                    offsetY = -phase * 2.8f,
                    scaleX = 1f + phase * 0.012f,
                    scaleY = 1f - phase * 0.015f,
                )
            }
            "sweep" -> {
                val phase = sin(time * 4.2f)
                PetEffectPose(
                    offsetX = phase * 2.5f,
                    rotationDegrees = phase * 2.4f,
                )
            }
            "sleep" -> PetEffectPose(
                offsetY = breath * 1.6f,
                scaleX = 1f - breath * 0.008f,
                scaleY = 1f + breath * 0.013f,
            )
            "sleep_enter" -> {
                val progress = min(1f, time / 1.05f)
                PetEffectPose(
                    offsetY = progress,
                    shadowScale = 1f + progress * 0.04f,
                )
            }
            "sleep_wake" -> {
                val progress = min(1f, time / 0.90f)
                PetEffectPose(offsetY = (1f - progress) * 0.8f, shadowOpacity = 0.20f)
            }
            "float" -> {
                val phase = sin(time * 5.8f)
                PetEffectPose(
                    offsetY = phase * 2.4f,
                    rotationDegrees = phase * 2.2f,
                    shadowOpacity = 0f,
                )
            }
            "fall" -> {
                val progress = min(1f, time / 0.42f)
                PetEffectPose(
                    rotationDegrees = progress * 10f,
                    scaleX = 1f + progress * 0.012f,
                    scaleY = 1f - progress * 0.018f,
                    shadowOpacity = 0f,
                )
            }
            "landing" -> {
                val settle = (exp((-time * 8f).toDouble()) * cos((time * 19f).toDouble())).toFloat()
                val compression = max(0f, settle)
                PetEffectPose(
                    offsetY = compression * 2f,
                    scaleX = 1f + compression * 0.055f,
                    scaleY = 1f - compression * 0.075f,
                    shadowScale = 1f + compression * 0.16f,
                    shadowOpacity = 0.25f,
                )
            }
            "dizzy" -> {
                val phase = sin(time * 10f)
                PetEffectPose(
                    offsetX = phase * 1.5f,
                    rotationDegrees = phase * 2.8f,
                    decoration = "dizzy",
                )
            }
            else -> PetEffectPose()
        }
    }
}
