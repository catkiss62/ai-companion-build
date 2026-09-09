package com.aicompanion.localfirst

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoricalNativeTombstoneSanitizerTest {
    @Test
    fun `extracts only bounded native categories from tombstone proto`() {
        val signal = message {
            varint(1, 6)
            string(2, "SIGABRT")
            varint(3, -6)
            string(4, "SI_TKILL")
        }
        val frame = message {
            varint(1, 0x1234)
            string(4, "onnxruntime::SequentialExecutor::Execute")
            string(6, "/data/app/private/base.apk!/lib/arm64-v8a/libonnxruntime.so")
        }
        val thread = message {
            varint(1, 27)
            string(2, "Genie-TTS-worker")
            bytes(4, frame)
        }
        val threadEntry = message {
            varint(1, 27)
            bytes(2, thread)
        }
        val cause = message { string(1, "allocator reported out of memory at /private/path") }
        val proto = message {
            varint(6, 27)
            bytes(10, signal)
            string(14, "terminating after throwing std::bad_alloc; user text SECRET")
            bytes(15, cause)
            bytes(16, threadEntry)
            string(18, "SECRET log buffer payload")
        }

        val summary = HistoricalNativeTombstoneSanitizer.summarize(
            ByteArrayInputStream(proto),
        )

        assertEquals(true, summary["historicalNativeTraceAvailable"])
        assertEquals(6L, summary["historicalNativeSignalNumber"])
        assertEquals("SIGABRT", summary["historicalNativeSignalName"])
        assertEquals("allocation_failure", summary["historicalNativeAbortCategory"])
        assertEquals("genie_worker", summary["historicalNativeCrashThreadCategory"])
        assertEquals(listOf("onnxruntime"), summary["historicalNativeBacktraceModules"])
        assertEquals(listOf("onnxruntime"), summary["historicalNativeBacktraceFrameCategories"])
        assertFalse(summary.toString().contains("SECRET"))
        assertFalse(summary.toString().contains("/data/app"))
        assertFalse(summary.toString().contains("0x1234"))
        assertEquals(false, summary["historicalNativeRawTraceIncluded"])
    }

    @Test
    fun `missing or invalid tombstone exposes no raw failure`() {
        val missing = HistoricalNativeTombstoneSanitizer.summarize(null)
        val broken = HistoricalNativeTombstoneSanitizer.summarize(
            ByteArrayInputStream(byteArrayOf(0x7a, 0x7f)),
        )

        assertEquals(false, missing["historicalNativeTraceAvailable"])
        assertEquals(false, broken["historicalNativeTraceAvailable"])
        assertTrue((broken["historicalNativeBacktraceModules"] as List<*>).isEmpty())
        assertFalse(broken.toString().contains("private"))
    }

    private class ProtoBuilder {
        private val output = ByteArrayOutputStream()

        fun varint(field: Int, value: Long) {
            rawVarint((field.toLong() shl 3) or 0)
            rawVarint(value)
        }

        fun string(field: Int, value: String) = bytes(field, value.toByteArray())

        fun bytes(field: Int, value: ByteArray) {
            rawVarint((field.toLong() shl 3) or 2)
            rawVarint(value.size.toLong())
            output.write(value)
        }

        private fun rawVarint(source: Long) {
            var value = source
            while (true) {
                if (value and -128L == 0L) {
                    output.write(value.toInt())
                    return
                }
                output.write((value.toInt() and 0x7f) or 0x80)
                value = value ushr 7
            }
        }

        fun build(): ByteArray = output.toByteArray()
    }

    private fun message(block: ProtoBuilder.() -> Unit): ByteArray =
        ProtoBuilder().apply(block).build()
}
