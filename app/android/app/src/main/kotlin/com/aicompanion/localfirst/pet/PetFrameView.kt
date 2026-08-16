package com.aicompanion.localfirst.pet

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

class PetFrameView(context: Context) : View(context) {
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val decorationPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeWidth = dp(1.6f)
    }
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.rgb(10, 48, 87)
    }
    private var snapshot: PetRenderSnapshot? = null
    private var translationX = 0f
    private var translationY = 0f
    private var previewWindowDp: Int? = null

    fun showSnapshot(value: PetRenderSnapshot) {
        snapshot = value
        postInvalidateOnAnimation()
    }

    fun setPetTranslation(x: Float, y: Float) {
        translationX = x
        translationY = y
        postInvalidateOnAnimation()
    }

    fun resetPetTranslation() = setPetTranslation(0f, 0f)

    fun setPreviewWindowDp(value: Int?) {
        previewWindowDp = value
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val value = snapshot ?: return
        val pose = PetEffects.poseFor(value.effect, value.elapsedSeconds)
        val scale = displayScale(value.current)
        val anchor = renderAnchor(value.current, scale)
        drawShadow(canvas, value.current, anchor.first, anchor.second, scale, pose)
        value.previous?.takeIf { value.previousOpacity > 0f }?.let {
            drawLayer(canvas, it, anchor.first, anchor.second, scale, pose, value.previousOpacity)
        }
        drawLayer(
            canvas,
            value.current,
            anchor.first,
            anchor.second,
            scale,
            pose,
            value.currentOpacity,
        )
        drawDecoration(canvas, value.current, anchor.first, anchor.second, scale, pose, value.elapsedSeconds)
    }

    private fun displayScale(layer: PetRenderLayer): Float {
        val available = min(
            width * 0.90f / layer.bitmap.width.toFloat(),
            height * 0.88f / layer.bitmap.height.toFloat(),
        )
        val requested = previewWindowDp?.let { windowDp ->
            min(
                dp(windowDp.toFloat()) * 0.90f / layer.bitmap.width.toFloat(),
                dp(windowDp.toFloat()) * 0.88f / layer.bitmap.height.toFloat(),
            )
        } ?: available
        return min(available, requested).coerceAtLeast(0.1f)
    }

    private fun renderAnchor(layer: PetRenderLayer, scale: Float): Pair<Float, Float> {
        val floorY = height * 0.94f
        val anchorY = if (layer.anchor.kind in setOf("drag", "seat", "sleep")) {
            height * 0.52f
        } else {
            floorY
        }
        return (width / 2f + translationX) to (anchorY + translationY)
    }

    private fun drawLayer(
        canvas: Canvas,
        layer: PetRenderLayer,
        anchorX: Float,
        anchorY: Float,
        scale: Float,
        pose: PetEffectPose,
        opacity: Float,
    ) {
        val bitmap = layer.bitmap
        bitmapPaint.alpha = (opacity.coerceIn(0f, 1f) * 255f).toInt()
        canvas.save()
        canvas.translate(
            anchorX + pose.offsetX * scale,
            anchorY + pose.offsetY * scale,
        )
        canvas.rotate(pose.rotationDegrees)
        val horizontal = if (layer.mirrored) -1f else 1f
        canvas.scale(horizontal * scale * pose.scaleX, scale * pose.scaleY)
        canvas.translate(
            -bitmap.width * (if (layer.mirrored) 1f - layer.anchor.x else layer.anchor.x),
            -bitmap.height * layer.anchor.y,
        )
        canvas.drawBitmap(bitmap, 0f, 0f, bitmapPaint)
        canvas.restore()
        bitmapPaint.alpha = 255
    }

    private fun drawShadow(
        canvas: Canvas,
        layer: PetRenderLayer,
        anchorX: Float,
        anchorY: Float,
        scale: Float,
        pose: PetEffectPose,
    ) {
        if (pose.shadowOpacity <= 0f) return
        val shadowWidth = maxOf(dp(22f), layer.bitmap.width * 0.27f * scale * pose.shadowScale)
        val shadowHeight = maxOf(dp(4f), layer.bitmap.height * 0.027f * scale * pose.shadowScale)
        shadowPaint.alpha = (pose.shadowOpacity.coerceIn(0f, 1f) * 130f).toInt()
        canvas.drawOval(
            RectF(
                anchorX - shadowWidth / 2f,
                anchorY - shadowHeight / 2f + dp(1f),
                anchorX + shadowWidth / 2f,
                anchorY + shadowHeight / 2f + dp(1f),
            ),
            shadowPaint,
        )
    }

    private fun drawDecoration(
        canvas: Canvas,
        layer: PetRenderLayer,
        anchorX: Float,
        anchorY: Float,
        scale: Float,
        pose: PetEffectPose,
        elapsed: Float,
    ) {
        val kind = pose.decoration ?: return
        if (kind !in setOf("thought", "voice", "dizzy")) return
        val top = anchorY - layer.bitmap.height * layer.anchor.y * scale
        val right = anchorX + layer.bitmap.width * (1f - layer.anchor.x) * scale
        decorationPaint.color = Color.rgb(80, 177, 228)
        when (kind) {
            "thought" -> {
                decorationPaint.style = Paint.Style.FILL
                decorationPaint.alpha = 155
                listOf(3f, 4.5f, 6f).forEachIndexed { index, radius ->
                    canvas.drawCircle(
                        right - dp(23f) + index * dp(7f),
                        top + dp(25f) - index * dp(9f),
                        dp(radius),
                        decorationPaint,
                    )
                }
            }
            "voice" -> {
                decorationPaint.style = Paint.Style.STROKE
                decorationPaint.alpha = 190
                repeat(2) { index ->
                    val rect = RectF(
                        right - dp(20f) + index * dp(4f),
                        top + dp(50f) - index * dp(3f),
                        right - dp(10f) + index * dp(7f),
                        top + dp(64f),
                    )
                    canvas.drawArc(rect, -55f, 110f, false, decorationPaint)
                }
            }
            "dizzy" -> {
                decorationPaint.style = Paint.Style.FILL
                decorationPaint.color = Color.rgb(255, 210, 65)
                decorationPaint.alpha = 230
                repeat(3) { index ->
                    val angle = elapsed * 2.8f + index * (PI.toFloat() * 2f / 3f)
                    val centerX = anchorX + cos(angle) * dp(23f)
                    val centerY = top + dp(11f) + sin(angle) * dp(7f)
                    drawStar(canvas, centerX, centerY, dp(4.6f), decorationPaint)
                }
            }
        }
        decorationPaint.alpha = 255
        decorationPaint.style = Paint.Style.STROKE
    }

    private fun drawStar(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        radius: Float,
        paint: Paint,
    ) {
        val path = Path()
        repeat(10) { index ->
            val angle = -PI / 2.0 + index * PI / 5.0
            val pointRadius = if (index % 2 == 0) radius else radius * 0.44f
            val x = centerX + cos(angle).toFloat() * pointRadius
            val y = centerY + sin(angle).toFloat() * pointRadius
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        canvas.drawPath(path, paint)
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}

