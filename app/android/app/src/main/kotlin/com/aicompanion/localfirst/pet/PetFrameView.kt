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

    private fun displayScale(layer: PetRenderLayer): Float = min(
        width * 0.90f / layer.bitmap.width.toFloat(),
        height * 0.88f / layer.bitmap.height.toFloat(),
    ).coerceAtLeast(0.1f)

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
        canvas.scale(scale * pose.scaleX, scale * pose.scaleY)
        canvas.translate(
            -bitmap.width * layer.anchor.x,
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
        val top = anchorY - layer.bitmap.height * layer.anchor.y * scale
        val right = anchorX + layer.bitmap.width * (1f - layer.anchor.x) * scale
        val left = anchorX - layer.bitmap.width * layer.anchor.x * scale
        decorationPaint.color = when (kind) {
            "anger" -> Color.rgb(221, 91, 105)
            "crumb" -> Color.rgb(246, 186, 93)
            "dizzy" -> Color.rgb(230, 177, 74)
            else -> Color.rgb(80, 177, 228)
        }
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
            "sparkle" -> {
                drawSparkle(canvas, right - dp(17f), top + dp(34f), dp(6f))
                drawSparkle(canvas, left + dp(22f), top + dp(48f), dp(4f))
            }
            "voice" -> {
                decorationPaint.style = Paint.Style.STROKE
                decorationPaint.alpha = 190
                repeat(2) { index ->
                    val rect = RectF(
                        right - dp(20f) + index * dp(4f),
                        top + dp(50f) - index * dp(3f),
                        right - dp(10f) + index * dp(7f),
                        top + dp(64f) + index * dp(0f),
                    )
                    canvas.drawArc(rect, -55f, 110f, false, decorationPaint)
                }
            }
            // The dafeiyu ANGRY raster already contains its orange anger mark.
            // Drawing another diagonal cross outside the sprite looked like a
            // broken unread/close badge on a real phone, so this skin keeps the
            // source frame and deliberately adds no second decoration.
            "anger" -> Unit
            "crumb" -> {
                decorationPaint.style = Paint.Style.FILL
                decorationPaint.alpha = 205
                repeat(3) { index ->
                    val y = anchorY - dp(35f) + ((index + (elapsed * 8f).toInt()) % 3) * dp(3f)
                    canvas.drawCircle(anchorX + dp(6f) + index * dp(4f), y, dp(1.4f), decorationPaint)
                }
            }
            "sweep" -> {
                decorationPaint.style = Paint.Style.STROKE
                decorationPaint.alpha = 155
                canvas.drawArc(
                    RectF(left + dp(8f), anchorY - dp(24f), left + dp(35f), anchorY - dp(14f)),
                    180f,
                    110f,
                    false,
                    decorationPaint,
                )
            }
            "sleep" -> {
                decorationPaint.style = Paint.Style.FILL
                decorationPaint.alpha = 145
                val drift = sin(elapsed * 2f) * dp(2f)
                listOf(3f, 4f, 5f).forEachIndexed { index, radius ->
                    canvas.drawCircle(
                        right - dp(20f) + index * dp(6f),
                        top + dp(38f) - index * dp(12f) + drift,
                        dp(radius),
                        decorationPaint,
                    )
                }
            }
            "dizzy" -> {
                val angle = elapsed * 4f
                repeat(3) { index ->
                    val theta = angle + index * (PI.toFloat() * 2f / 3f)
                    drawSparkle(
                        canvas,
                        anchorX + cos(theta) * dp(22f),
                        top + dp(24f) + sin(theta) * dp(10f),
                        dp(3.5f),
                    )
                }
            }
        }
        decorationPaint.alpha = 255
        decorationPaint.style = Paint.Style.STROKE
    }

    private fun drawSparkle(canvas: Canvas, x: Float, y: Float, radius: Float) {
        decorationPaint.style = Paint.Style.STROKE
        decorationPaint.alpha = 210
        decorationPaint.strokeWidth = maxOf(dp(1f), radius / 3f)
        canvas.drawLine(x - radius, y, x + radius, y, decorationPaint)
        canvas.drawLine(x, y - radius, x, y + radius, decorationPaint)
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density
}
