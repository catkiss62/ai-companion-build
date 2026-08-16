package com.aicompanion.localfirst.pet

import kotlin.math.abs

data class PetVisibleBounds(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
)

data class PetVisibleOffset(
    val x: Float = 0f,
    val y: Float = 0f,
)

/**
 * WindowManager docks the transparent overlay rectangle. Rendering must separately
 * keep the transformed, non-transparent pixels on the same visible contact line.
 */
object PetVisibleEdgeCompensation {
    const val LEFT = "left"
    const val RIGHT = "right"
    const val TOP = "top"
    const val BOTTOM = "bottom"

    fun offset(
        edges: Set<String>,
        reference: PetVisibleBounds,
        current: PetVisibleBounds,
    ): PetVisibleOffset {
        val x = when {
            LEFT in edges -> reference.left - current.left
            RIGHT in edges -> reference.right - current.right
            else -> 0f
        }
        val y = when {
            TOP in edges -> reference.top - current.top
            BOTTOM in edges -> reference.bottom - current.bottom
            else -> 0f
        }
        return PetVisibleOffset(x, y)
    }
}

object PetVisualDockingPolicy {
    fun edges(
        edgeMode: Boolean,
        dockedEdge: String,
        x: Int,
        y: Int,
        minX: Int,
        maxX: Int,
        minY: Int,
        maxY: Int,
        tolerancePx: Int = 1,
    ): Set<String> {
        if (!edgeMode || dockedEdge !in setOf(
                PetVisibleEdgeCompensation.LEFT,
                PetVisibleEdgeCompensation.RIGHT,
                PetVisibleEdgeCompensation.TOP,
                PetVisibleEdgeCompensation.BOTTOM,
            )
        ) {
            return emptySet()
        }
        return buildSet {
            add(dockedEdge)
            when (dockedEdge) {
                PetVisibleEdgeCompensation.TOP,
                PetVisibleEdgeCompensation.BOTTOM -> when {
                    abs(x - minX) <= tolerancePx -> add(PetVisibleEdgeCompensation.LEFT)
                    abs(x - maxX) <= tolerancePx -> add(PetVisibleEdgeCompensation.RIGHT)
                }
                PetVisibleEdgeCompensation.LEFT,
                PetVisibleEdgeCompensation.RIGHT -> when {
                    abs(y - minY) <= tolerancePx -> add(PetVisibleEdgeCompensation.TOP)
                    abs(y - maxY) <= tolerancePx -> add(PetVisibleEdgeCompensation.BOTTOM)
                }
            }
        }
    }
}
