package com.aicompanion.localfirst

import java.io.ByteArrayOutputStream
import java.io.InputStream

/**
 * Extracts bounded, non-content diagnostics from Android's native tombstone proto.
 *
 * Android 12+ returns this binary protobuf from
 * ApplicationExitInfo.getTraceInputStream(). Raw abort text, command lines,
 * mappings, registers, logs, paths and addresses are deliberately discarded.
 */
internal object HistoricalNativeTombstoneSanitizer {
    private const val maxBytes = 2 * 1024 * 1024
    private const val maxFrames = 12

    fun summarize(input: InputStream?): Map<String, Any> {
        if (input == null) return emptySummary(traceAvailable = false)
        return runCatching {
            val (bytes, truncated) = readBounded(input)
            val tombstone = parseTombstone(bytes)
            mapOf(
                "historicalNativeTraceAvailable" to true,
                "historicalNativeSanitizedSummaryVersion" to 1,
                "historicalNativeSignalNumber" to tombstone.signalNumber,
                "historicalNativeSignalName" to safeProtoToken(tombstone.signalName, 32),
                "historicalNativeSignalCode" to tombstone.signalCode,
                "historicalNativeSignalCodeName" to safeProtoToken(tombstone.signalCodeName, 48),
                "historicalNativeAbortMessagePresent" to tombstone.abortMessage.isNotBlank(),
                "historicalNativeAbortCategory" to abortCategory(tombstone.abortMessage),
                "historicalNativeCauseCategories" to tombstone.causes
                    .map(::abortCategory)
                    .filter { it != "unavailable" }
                    .distinct()
                    .take(6),
                "historicalNativeCrashThreadCategory" to threadCategory(tombstone.crashThreadName),
                "historicalNativeBacktraceModules" to tombstone.frames
                    .map { moduleCategory(it.fileName) }
                    .distinct()
                    .take(maxFrames),
                "historicalNativeBacktraceFrameCategories" to tombstone.frames
                    .map { frameCategory(it.functionName, it.fileName) }
                    .distinct()
                    .take(maxFrames),
                "historicalNativeTraceSizeBucket" to sizeBucket(bytes.size),
                "historicalNativeTraceTruncated" to truncated,
                "historicalNativeRawTraceIncluded" to false,
            )
        }.getOrElse { emptySummary(traceAvailable = false) }
    }

    private data class Tombstone(
        var crashTid: Long = 0,
        var signalNumber: Long = 0,
        var signalName: String = "unknown",
        var signalCode: Long = 0,
        var signalCodeName: String = "unknown",
        var abortMessage: String = "",
        val causes: MutableList<String> = mutableListOf(),
        var crashThreadName: String = "",
        val frames: MutableList<Frame> = mutableListOf(),
    )

    private data class Frame(val functionName: String, val fileName: String)

    private fun parseTombstone(bytes: ByteArray): Tombstone {
        val result = Tombstone()
        val threadEntries = mutableListOf<ByteArray>()
        val reader = ProtoReader(bytes)
        while (reader.hasRemaining()) {
            val (field, wire) = reader.readTag()
            when {
                field == 6 && wire == 0 -> result.crashTid = reader.readVarint()
                field == 10 && wire == 2 -> parseSignal(reader.readBytes(), result)
                field == 14 && wire == 2 -> result.abortMessage = decode(reader.readBytes())
                field == 15 && wire == 2 && result.causes.size < 6 -> {
                    parseCause(reader.readBytes())?.let(result.causes::add)
                }
                field == 16 && wire == 2 -> threadEntries += reader.readBytes()
                else -> reader.skip(wire)
            }
        }
        for (entry in threadEntries) {
            val parsed = parseThreadEntry(entry) ?: continue
            if (parsed.first == result.crashTid) {
                result.crashThreadName = parsed.second.first
                result.frames += parsed.second.second.take(maxFrames)
                break
            }
        }
        return result
    }

    private fun parseSignal(bytes: ByteArray, tombstone: Tombstone) {
        val reader = ProtoReader(bytes)
        while (reader.hasRemaining()) {
            val (field, wire) = reader.readTag()
            when {
                field == 1 && wire == 0 -> tombstone.signalNumber = reader.readVarint()
                field == 2 && wire == 2 -> tombstone.signalName = decode(reader.readBytes())
                field == 3 && wire == 0 -> tombstone.signalCode = reader.readVarint()
                field == 4 && wire == 2 -> tombstone.signalCodeName = decode(reader.readBytes())
                else -> reader.skip(wire)
            }
        }
    }

    private fun parseCause(bytes: ByteArray): String? {
        val reader = ProtoReader(bytes)
        while (reader.hasRemaining()) {
            val (field, wire) = reader.readTag()
            if (field == 1 && wire == 2) return decode(reader.readBytes())
            reader.skip(wire)
        }
        return null
    }

    private fun parseThreadEntry(bytes: ByteArray): Pair<Long, Pair<String, List<Frame>>>? {
        var tid = -1L
        var thread: Pair<String, List<Frame>>? = null
        val reader = ProtoReader(bytes)
        while (reader.hasRemaining()) {
            val (field, wire) = reader.readTag()
            when {
                field == 1 && wire == 0 -> tid = reader.readVarint()
                field == 2 && wire == 2 -> thread = parseThread(reader.readBytes())
                else -> reader.skip(wire)
            }
        }
        return thread?.let { tid to it }
    }

    private fun parseThread(bytes: ByteArray): Pair<String, List<Frame>> {
        var name = ""
        val frames = mutableListOf<Frame>()
        val reader = ProtoReader(bytes)
        while (reader.hasRemaining()) {
            val (field, wire) = reader.readTag()
            when {
                field == 2 && wire == 2 -> name = decode(reader.readBytes())
                field == 4 && wire == 2 && frames.size < maxFrames -> frames += parseFrame(reader.readBytes())
                else -> reader.skip(wire)
            }
        }
        return name to frames
    }

    private fun parseFrame(bytes: ByteArray): Frame {
        var functionName = ""
        var fileName = ""
        val reader = ProtoReader(bytes)
        while (reader.hasRemaining()) {
            val (field, wire) = reader.readTag()
            when {
                field == 4 && wire == 2 -> functionName = decode(reader.readBytes())
                field == 6 && wire == 2 -> fileName = decode(reader.readBytes())
                else -> reader.skip(wire)
            }
        }
        return Frame(functionName, fileName)
    }

    private class ProtoReader(private val bytes: ByteArray) {
        private var offset = 0

        fun hasRemaining() = offset < bytes.size

        fun readTag(): Pair<Int, Int> {
            val value = readVarint()
            require(value != 0L) { "invalid protobuf tag" }
            return (value ushr 3).toInt() to (value and 7).toInt()
        }

        fun readVarint(): Long {
            var value = 0L
            var shift = 0
            while (shift < 64) {
                require(offset < bytes.size) { "truncated protobuf varint" }
                val byte = bytes[offset++].toInt() and 0xff
                value = value or ((byte and 0x7f).toLong() shl shift)
                if (byte and 0x80 == 0) return value
                shift += 7
            }
            error("oversized protobuf varint")
        }

        fun readBytes(): ByteArray {
            val length = readVarint()
            require(length in 0..(bytes.size - offset).toLong()) { "invalid protobuf length" }
            val end = offset + length.toInt()
            return bytes.copyOfRange(offset, end).also { offset = end }
        }

        fun skip(wire: Int) {
            when (wire) {
                0 -> readVarint()
                1 -> advance(8)
                2 -> advance(readVarint().toInt())
                5 -> advance(4)
                else -> error("unsupported protobuf wire type")
            }
        }

        private fun advance(count: Int) {
            require(count >= 0 && count <= bytes.size - offset) { "invalid protobuf field" }
            offset += count
        }
    }

    private fun readBounded(input: InputStream): Pair<ByteArray, Boolean> {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        input.use {
            while (output.size() <= maxBytes) {
                val remaining = maxBytes + 1 - output.size()
                val count = it.read(buffer, 0, minOf(buffer.size, remaining))
                if (count < 0) break
                output.write(buffer, 0, count)
            }
        }
        val all = output.toByteArray()
        return if (all.size > maxBytes) all.copyOf(maxBytes) to true else all to false
    }

    private fun decode(bytes: ByteArray) = bytes.toString(Charsets.UTF_8).take(1024)

    private fun safeProtoToken(value: String, maxLength: Int): String {
        val token = value.trim().take(maxLength)
        return token.takeIf { it.matches(Regex("[A-Za-z0-9_+.-]{1,$maxLength}")) } ?: "unknown"
    }

    private fun abortCategory(value: String): String {
        val lower = value.lowercase()
        return when {
            lower.isBlank() -> "unavailable"
            "pthread_create" in lower || "thread creation" in lower ||
                "resource temporarily unavailable" in lower -> "thread_resource_failure"
            "bad_alloc" in lower || "out of memory" in lower ||
                "failed to allocate" in lower || "cannot allocate" in lower -> "allocation_failure"
            "scudo" in lower -> "allocator_safety_failure"
            "fdsan" in lower -> "file_descriptor_safety_failure"
            "fortify" in lower -> "fortify_failure"
            "check failed" in lower || "assert" in lower -> "native_assertion"
            "onnxruntime" in lower || "onnx runtime" in lower -> "onnxruntime_abort"
            "terminate called" in lower || "uncaught exception" in lower -> "uncaught_native_exception"
            else -> "other_native_abort"
        }
    }

    private fun threadCategory(value: String): String = when {
        value == "Genie-TTS-worker" -> "genie_worker"
        value == "main" -> "main"
        value.startsWith("Binder:") -> "binder"
        value.contains("onnx", ignoreCase = true) -> "onnxruntime_worker"
        value.isBlank() -> "unknown"
        else -> "other"
    }

    private fun moduleCategory(path: String): String {
        val name = path.substringAfterLast('/').lowercase()
        return when {
            name == "libonnxruntime.so" -> "onnxruntime"
            name == "libopenjtalk_native.so" -> "openjtalk"
            name == "libgenie_frontend.so" -> "genie_frontend"
            name == "libflutter.so" -> "flutter"
            name in setOf("libc.so", "libc++.so", "libdl.so", "libm.so") -> "android_native"
            name.endsWith(".so") -> "other_native"
            name.isBlank() -> "unknown"
            else -> "app_or_runtime"
        }
    }

    private fun frameCategory(function: String, file: String): String {
        val lower = "$function $file".lowercase()
        return when {
            "onnxruntime" in lower || "onnxruntime" in moduleCategory(file) -> "onnxruntime"
            "pthread" in lower || "thread" in lower -> "thread"
            "malloc" in lower || "operator new" in lower || "alloc" in lower -> "allocation"
            "abort" in lower || "assert" in lower || "check" in lower -> "abort"
            "openjtalk" in lower -> "openjtalk"
            "genie_frontend" in lower -> "genie_frontend"
            else -> moduleCategory(file)
        }
    }

    private fun sizeBucket(bytes: Int): String = when {
        bytes <= 64 * 1024 -> "le_64k"
        bytes <= 512 * 1024 -> "64_512k"
        bytes <= maxBytes -> "512k_2m"
        else -> "gt_2m"
    }

    private fun emptySummary(traceAvailable: Boolean): Map<String, Any> = mapOf(
        "historicalNativeTraceAvailable" to traceAvailable,
        "historicalNativeSanitizedSummaryVersion" to 1,
        "historicalNativeSignalNumber" to 0,
        "historicalNativeSignalName" to "unknown",
        "historicalNativeSignalCode" to 0,
        "historicalNativeSignalCodeName" to "unknown",
        "historicalNativeAbortMessagePresent" to false,
        "historicalNativeAbortCategory" to "unavailable",
        "historicalNativeCauseCategories" to emptyList<String>(),
        "historicalNativeCrashThreadCategory" to "unknown",
        "historicalNativeBacktraceModules" to emptyList<String>(),
        "historicalNativeBacktraceFrameCategories" to emptyList<String>(),
        "historicalNativeTraceSizeBucket" to "unavailable",
        "historicalNativeTraceTruncated" to false,
        "historicalNativeRawTraceIncluded" to false,
    )
}
