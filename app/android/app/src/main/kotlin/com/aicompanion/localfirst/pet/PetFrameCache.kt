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
    private val cache = object : LruCache<String, Bitmap>((maxBytes / 1024).coerceAtLeast(1024)) {
        override fun sizeOf(key: String, value: Bitmap): Int =
            (value.allocationByteCount / 1024).coerceAtLeast(1)
    }

    fun get(relativePath: String): Bitmap {
        cache.get(relativePath)?.let { return it }
        val bitmap = assets.open("$root/$relativePath").use { stream ->
            BitmapFactory.decodeStream(stream)
        } ?: throw PetSkinFormatException("Cannot decode frame: $relativePath")
        cache.put(relativePath, bitmap)
        return bitmap
    }

    fun clear() {
        cache.evictAll()
    }
}
