package com.aicompanion.localfirst.pet

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream

class PetFrameCache(
    private val assets: AssetManager,
    private val root: String = PetSkinManifest.SOURCE_ROOT,
    maxBytes: Int = 24 * 1024 * 1024,
) {
    private var experimentalGamma = 0.85f
    private var experimentalSaturation = 1f
    private val packedFrames = mutableMapOf<String, List<ByteArray>>()
    private val experimentalPath = Regex(
        """runtime_overrides/experimental/(hum|stretch|cube|stand|click)/(\d{3})\.webp""",
    )
    private val cache = object : LruCache<String, Bitmap>((maxBytes / 1024).coerceAtLeast(1024)) {
        override fun sizeOf(key: String, value: Bitmap): Int =
            (value.allocationByteCount / 1024).coerceAtLeast(1)
    }

    fun get(relativePath: String): Bitmap {
        cache.get(relativePath)?.let { return it }
        val experimental = experimentalPath.matchEntire(relativePath)
        val decoded = if (experimental != null) {
            val folder = experimental.groupValues[1]
            val index = experimental.groupValues[2].toInt()
            val frames = packedFrames.getOrPut(folder) { loadPackedFrames(folder) }
            val bytes = frames.getOrNull(index)
                ?: throw PetSkinFormatException("Missing experimental frame: $relativePath")
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } else assets.open("$root/$relativePath").use { stream ->
            BitmapFactory.decodeStream(stream)
        } ?: throw PetSkinFormatException("Cannot decode frame: $relativePath")
        val bitmap = if (experimental != null) {
            PetExperimentalCurve.apply(decoded, experimentalGamma, experimentalSaturation).also {
                if (it !== decoded) decoded.recycle()
            }
        } else decoded
        cache.put(relativePath, bitmap)
        return bitmap
    }

    private fun loadPackedFrames(folder: String): List<ByteArray> {
        val directory = "$root/runtime_overrides/experimental/$folder/packed"
        val names = assets.list(directory)?.sorted().orEmpty()
        if (names.isEmpty()) throw PetSkinFormatException("Missing experimental pack: $folder")
        val bytes = ByteArrayOutputStream()
        names.forEachIndexed { index, name ->
            if (name != "${index.toString().padStart(3, '0')}.bin") {
                throw PetSkinFormatException("Experimental pack order changed: $folder")
            }
            assets.open("$directory/$name").use { it.copyTo(bytes) }
        }
        val input = DataInputStream(ByteArrayInputStream(bytes.toByteArray()))
        val signature = ByteArray(7)
        input.readFully(signature)
        if (!signature.contentEquals("PET241\u0000".toByteArray(Charsets.US_ASCII))) {
            throw PetSkinFormatException("Invalid experimental pack: $folder")
        }
        val frames = List(PetExperimentalClips.FRAME_COUNT) {
            val size = input.readInt()
            if (size !in 16..100_000) throw PetSkinFormatException("Invalid frame size: $folder")
            ByteArray(size).also { input.readFully(it) }
        }
        if (input.available() != 0) throw PetSkinFormatException("Extra experimental data: $folder")
        return frames
    }

    fun setExperimentalColors(gamma: Float, saturation: Float) {
        val boundedGamma = gamma.coerceIn(0.5f, 1.25f)
        val boundedSaturation = saturation.coerceIn(0.5f, 2f)
        if (experimentalGamma == boundedGamma && experimentalSaturation == boundedSaturation) return
        experimentalGamma = boundedGamma
        experimentalSaturation = boundedSaturation
        cache.evictAll()
    }

    fun clear() {
        cache.evictAll()
        packedFrames.clear()
    }
}
