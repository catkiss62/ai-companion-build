package com.aicompanion.localfirst

import kotlin.math.atan2
import kotlin.math.exp
import kotlin.math.sqrt

/** Relative rotation in screen coordinates: no Euler wrap or upright-phone gimbal jump. */
internal class RoomTiltFilter {
    private var reference: FloatArray? = null
    private var lastTime = 0L
    var x = 0f; private set
    var y = 0f; private set

    fun reset() { reference = null; lastTime = 0; x = 0f; y = 0f }

    fun update(matrix: FloatArray, timeNanos: Long): Boolean {
        if (matrix.size < 9 || matrix.any { !it.isFinite() } || timeNanos <= lastTime) return false
        val origin = reference
        if (origin == null) {
            reference = matrix.copyOf(); lastTime = timeNanos
            return true
        }
        // Third column of R0-transpose * R is the current screen normal in the
        // original screen's coordinates. Rotation around that normal is ignored.
        val nx = origin[0]*matrix[2] + origin[3]*matrix[5] + origin[6]*matrix[8]
        val ny = origin[1]*matrix[2] + origin[4]*matrix[5] + origin[7]*matrix[8]
        val nz = origin[2]*matrix[2] + origin[5]*matrix[5] + origin[8]*matrix[8]
        val targetX = (atan2(nx, nz) / .35f).coerceIn(-1f, 1f)
        val targetY = (atan2(-ny, sqrt(nx*nx + nz*nz)) / .35f).coerceIn(-1f, 1f)
        val dt = ((timeNanos-lastTime)/1e9).coerceIn(0.0, .1)
        val alpha = (1.0-exp(-dt/.12)).toFloat()
        x += (targetX-x)*alpha; y += (targetY-y)*alpha
        lastTime = timeNanos
        return true
    }
}
