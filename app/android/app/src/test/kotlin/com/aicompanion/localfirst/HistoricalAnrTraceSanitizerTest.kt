package com.aicompanion.localfirst

import java.io.ByteArrayInputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoricalAnrTraceSanitizerTest {
    @Test
    fun `keeps bounded app symbols and coarse framework categories`() {
        val trace = """
            "main" prio=5 tid=1 Waiting
              at java.util.concurrent.CountDownLatch.await(CountDownLatch.java:230)
              at com.aicompanion.localfirst.SystemBridge.preflightStatus(SystemBridge.kt:1170)
              at io.flutter.embedding.engine.dart.DartMessenger.handleMessageFromDart(DartMessenger.java:300)
            "worker" prio=5 tid=17 Runnable
              at com.example.secret.PrivateWorker.run(PrivateWorker.kt:9)
        """.trimIndent()

        val summary = HistoricalAnrTraceSanitizer.summarize(
            ByteArrayInputStream(trace.toByteArray()),
        )

        assertEquals(true, summary["historicalAnrTraceAvailable"])
        assertEquals("waiting", summary["historicalAnrMainThreadState"])
        assertEquals(
            listOf("com.aicompanion.localfirst.SystemBridge.preflightStatus"),
            summary["historicalAnrAppTopFrames"],
        )
        assertEquals(listOf("lock", "app", "flutter"), summary["historicalAnrFrameCategories"])
        assertFalse(summary.toString().contains("com.example.secret"))
        assertFalse(summary.toString().contains("SystemBridge.kt"))
        assertFalse(summary.toString().contains("CountDownLatch.java"))
        assertEquals(false, summary["historicalAnrRawTraceIncluded"])
    }

    @Test
    fun `missing or unreadable trace exposes no raw failure`() {
        val missing = HistoricalAnrTraceSanitizer.summarize(null)
        val broken = HistoricalAnrTraceSanitizer.summarize(
            object : java.io.InputStream() {
                override fun read(): Int = error("private failure detail")
            },
        )

        assertEquals(false, missing["historicalAnrTraceAvailable"])
        assertEquals(false, broken["historicalAnrTraceAvailable"])
        assertTrue((broken["historicalAnrAppTopFrames"] as List<*>).isEmpty())
        assertFalse(broken.toString().contains("private failure detail"))
    }
}
