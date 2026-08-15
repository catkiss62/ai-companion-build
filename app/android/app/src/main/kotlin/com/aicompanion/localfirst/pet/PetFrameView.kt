package com.aicompanion.localfirst.pet

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.view.View

class PetFrameView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private var bitmap: Bitmap? = null

    fun showFrame(frame: Bitmap) {
        bitmap = frame
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val frame = bitmap ?: return
        val scale = minOf(
            width.toFloat() / frame.width.toFloat(),
            height.toFloat() / frame.height.toFloat(),
        )
        val drawWidth = (frame.width * scale).toInt()
        val drawHeight = (frame.height * scale).toInt()
        val left = (width - drawWidth) / 2
        val top = height - drawHeight
        canvas.drawBitmap(
            frame,
            null,
            Rect(left, top, left + drawWidth, top + drawHeight),
            paint,
        )
    }
}
