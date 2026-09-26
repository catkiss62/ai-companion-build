package com.aicompanion.localfirst.pet

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache

class PetFrameCache(
    private val assets: AssetManager,
    private val root: String = PetSkinManifest.SOURCE_ROOT,
    maxBytes: Int = 24 * 1024 * 1024,
) {
    private var experimentalGamma = 0.85f
    private val cache = object : LruCache<String, Bitmap>((maxBytes / 1024).coerceAtLeast(1024)) {
        override fun sizeOf(key: String, value: Bitmap): Int =
            (value.allocationByteCount / 1024).coerceAtLeast(1)
    }

    fun get(relativePath: String): Bitmap {
        cache.get(relativePath)?.let { return it }
        val decoded = assets.open("$root/$relativePath").use { stream ->
            BitmapFactory.decodeStream(stream)
        } ?: throw PetSkinFormatException("Cannot decode frame: $relativePath")
        val bitmap = if (relativePath.startsWith("runtime_overrides/experimental/")) {
            PetExperimentalCurve.apply(decoded, experimentalGamma).also {
                if (it !== decoded) decoded.recycle()
            }
        } else decoded
        cache.put(relativePath, bitmap)
        return bitmap
    }

    fun setExperimentalGamma(value: Float) {
        val bounded = value.coerceIn(0.5f, 1.25f)
        if (experimentalGamma == bounded) return
        experimentalGamma = bounded
        clear()
    }

    fun clear() {
        cache.evictAll()
    }
}
