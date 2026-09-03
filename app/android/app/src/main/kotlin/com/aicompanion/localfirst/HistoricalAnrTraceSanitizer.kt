package com.aicompanion.localfirst

import java.io.InputStream

/**
 * Reduces an Android ANR trace to bounded, code-only evidence.
 *
 * Raw lines, paths, arguments, thread dumps and application/user data never
 * leave this helper. Exact symbols are retained only for this public app
 * package; framework code is represented by coarse categories.
 */
internal object HistoricalAnrTraceSanitizer {
    private const val maxCharacters = 262_144
    private const val maxAppFrames = 8
    private val framePattern = Regex("""^\s+at\s+([A-Za-z0-9_.$<>]+)(?:\([^)]*\))?\s*$""")
    private val safeStatePattern = Regex("^[A-Za-z_]{2,24}$")

    fun summarize(input: InputStream?): Map<String, Any> {
        if (input == null) return emptySummary(traceAvailable = false)
        return runCatching {
            var characters = 0
            var truncated = false
            var inMainThread = false
            var mainThreadSeen = false
            var mainThreadState = "unknown"
            val appFrames = linkedSetOf<String>()
            val categories = linkedSetOf<String>()
            input.bufferedReader(Charsets.UTF_8).use { reader ->
                while (true) {
                    val line = reader.readLine() ?: break
                    characters += line.length + 1
                    if (characters > maxCharacters) {
                        truncated = true
                        break
                    }
                    if (line.startsWith('"')) {
                        inMainThread = line.startsWith("\"main\"")
                        if (inMainThread) {
                            mainThreadSeen = true
                            val candidate = line.trim().substringAfterLast(' ').lowercase()
                            if (safeStatePattern.matches(candidate)) {
                                mainThreadState = candidate
                            }
                        }
                        continue
                    }
                    if (!inMainThread) continue
                    if (line.trimStart().startsWith("native:")) {
                        categories += "native"
                        continue
                    }
                    val symbol = framePattern.matchEntire(line)?.groupValues?.get(1)
                        ?: continue
                    val category = categoryFor(symbol)
                    categories += category
                    if (category == "app" && appFrames.size < maxAppFrames) {
                        appFrames += symbol.take(180)
                    }
                }
            }
            mapOf(
                "historicalAnrTraceAvailable" to true,
                "historicalAnrSanitizedSummaryVersion" to 1,
                "historicalAnrMainThreadSeen" to mainThreadSeen,
                "historicalAnrMainThreadState" to mainThreadState,
                "historicalAnrAppFrameCount" to appFrames.size,
                "historicalAnrAppTopFrames" to appFrames.toList(),
                "historicalAnrFrameCategories" to categories.toList(),
                "historicalAnrTraceSizeBucket" to sizeBucket(characters),
                "historicalAnrTraceTruncated" to truncated,
                "historicalAnrRawTraceIncluded" to false,
            )
        }.getOrElse { emptySummary(traceAvailable = false) }
    }

    private fun emptySummary(traceAvailable: Boolean): Map<String, Any> = mapOf(
        "historicalAnrTraceAvailable" to traceAvailable,
        "historicalAnrSanitizedSummaryVersion" to 1,
        "historicalAnrMainThreadSeen" to false,
        "historicalAnrMainThreadState" to "unknown",
        "historicalAnrAppFrameCount" to 0,
        "historicalAnrAppTopFrames" to emptyList<String>(),
        "historicalAnrFrameCategories" to emptyList<String>(),
        "historicalAnrTraceSizeBucket" to "unavailable",
        "historicalAnrTraceTruncated" to false,
        "historicalAnrRawTraceIncluded" to false,
    )

    private fun categoryFor(symbol: String): String = when {
        symbol.startsWith("com.aicompanion.localfirst.") -> "app"
        symbol.startsWith("io.flutter.") -> "flutter"
        symbol.contains("sqlite", ignoreCase = true) ||
            symbol.startsWith("android.database.") -> "database"
        symbol.startsWith("android.graphics.") ||
            symbol.contains("ImageDecoder") ||
            symbol.contains("BitmapFactory") -> "image"
        symbol.contains("LockSupport.park") ||
            symbol.contains("Object.wait") ||
            symbol.contains("CountDownLatch.await") ||
            symbol.contains("FutureTask.get") -> "lock"
        symbol.startsWith("java.io.") ||
            symbol.startsWith("java.net.") ||
            symbol.startsWith("okhttp3.") -> "io"
        symbol.startsWith("android.") ||
            symbol.startsWith("java.") ||
            symbol.startsWith("kotlin.") ||
            symbol.startsWith("dalvik.") -> "android"
        else -> "unknown"
    }

    private fun sizeBucket(characters: Int): String = when {
        characters <= 16_384 -> "le_16k"
        characters <= 65_536 -> "16_64k"
        characters <= maxCharacters -> "64_256k"
        else -> "gt_256k"
    }
}
