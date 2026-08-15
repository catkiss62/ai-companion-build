package com.aicompanion.localfirst.pet

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.pow

data class PetPhysicsBounds(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
) {
    fun limits(spriteWidth: Float, spriteHeight: Float): FloatArray = floatArrayOf(
        left,
        maxOf(left, right - maxOf(0f, spriteWidth) + 1f),
        top,
        maxOf(top, bottom - maxOf(0f, spriteHeight) + 1f),
    )
}

data class PetPhysicsStep(
    val x: Float,
    val y: Float,
    val velocityX: Float,
    val velocityY: Float,
    val floorContact: Boolean = false,
    val settled: Boolean = false,
    val hardLanding: Boolean = false,
    val impactSpeed: Float = 0f,
)

/** Android coordinate port of ds-local-pet/pet/physics.py. */
class PetThrowPhysics(
    private val gravity: Float = 2350f,
    private val maxLaunchSpeed: Float = 1850f,
    private val wallRestitution: Float = 0.34f,
    private val ceilingRestitution: Float = 0.24f,
    private val floorRestitution: Float = 0.18f,
    private val hardImpactSpeed: Float = 980f,
    private val bounceImpactSpeed: Float = 360f,
    private val settleHorizontalSpeed: Float = 42f,
) {
    var active: Boolean = false
        private set
    private var x = 0f
    private var y = 0f
    private var velocityX = 0f
    private var velocityY = 0f
    private var bounceCount = 0
    private var hardLanding = false
    private var largestImpact = 0f

    fun launch(x: Float, y: Float, velocityX: Float, velocityY: Float) {
        val limited = limitedVelocity(velocityX, velocityY)
        this.x = x
        this.y = y
        this.velocityX = limited.first
        this.velocityY = limited.second
        bounceCount = 0
        hardLanding = false
        largestImpact = 0f
        active = true
    }

    fun cancel() {
        active = false
        velocityX = 0f
        velocityY = 0f
    }

    fun step(
        deltaSeconds: Float,
        spriteWidth: Float,
        spriteHeight: Float,
        bounds: PetPhysicsBounds,
    ): PetPhysicsStep {
        if (!active) return snapshot()
        var remaining = deltaSeconds.coerceIn(0f, 0.10f)
        val limits = bounds.limits(spriteWidth, spriteHeight)
        var settled = false
        var floorContact = false
        while (remaining > 0.0000001f && active) {
            val substep = minOf(remaining, 1f / 120f)
            remaining -= substep
            velocityY += gravity * substep
            x += velocityX * substep
            y += velocityY * substep

            if (x < limits[0]) {
                x = limits[0]
                if (velocityX < 0f) velocityX = -velocityX * wallRestitution
            } else if (x > limits[1]) {
                x = limits[1]
                if (velocityX > 0f) velocityX = -velocityX * wallRestitution
            }
            if (y < limits[2]) {
                y = limits[2]
                if (velocityY < 0f) velocityY = -velocityY * ceilingRestitution
            }
            if (y >= limits[3]) {
                floorContact = true
                y = limits[3]
                val impactSpeed = maxOf(0f, velocityY)
                largestImpact = maxOf(largestImpact, impactSpeed)
                hardLanding = hardLanding || impactSpeed >= hardImpactSpeed
                if (impactSpeed >= bounceImpactSpeed && bounceCount < 2) {
                    velocityY = -impactSpeed * floorRestitution
                    velocityX *= 0.72f
                    bounceCount += 1
                } else {
                    velocityY = 0f
                    velocityX *= 0.045f.pow(substep)
                    if (abs(velocityX) <= settleHorizontalSpeed) {
                        velocityX = 0f
                        active = false
                        settled = true
                    }
                }
            }
        }
        return PetPhysicsStep(
            x,
            y,
            velocityX,
            velocityY,
            floorContact = floorContact,
            settled = settled,
            hardLanding = hardLanding,
            impactSpeed = largestImpact,
        )
    }

    private fun snapshot(): PetPhysicsStep = PetPhysicsStep(
        x,
        y,
        velocityX,
        velocityY,
        hardLanding = hardLanding,
        impactSpeed = largestImpact,
    )

    private fun limitedVelocity(x: Float, y: Float): Pair<Float, Float> {
        val speed = hypot(x, y)
        if (speed <= maxLaunchSpeed || speed <= 0f) return x to y
        val scale = maxLaunchSpeed / speed
        return x * scale to y * scale
    }
}
