package com.aicompanion.localfirst

import android.app.Activity
import android.os.Looper
import android.os.Handler
import android.widget.FrameLayout
import android.widget.Button
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.time.Duration
import java.util.concurrent.ExecutorService
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

/** Real Service handlers and Android main-loop timers, with only Dart transport
 * withheld. No Flutter engine, LLM, overlay permission or cosmetic renderer. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class OverlayServiceRecoveryTest {
    private class Channel(var throwOnInvoke: Boolean = false) : MethodChannel(object : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {}
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {}
    }, "fixture") {
        val calls = mutableListOf<Pair<String, MethodChannel.Result>>()
        override fun invokeMethod(method: String, arguments: Any?, callback: MethodChannel.Result?) {
            if (throwOnInvoke) throw IllegalStateException("private transport detail")
            if (callback != null) calls.add(method to callback)
        }
    }
    private fun field(name: String) = OverlayBubbleService::class.java.getDeclaredField(name).apply { isAccessible = true }
    private fun set(service: OverlayBubbleService, name: String, value: Any?) = field(name).set(service, value)
    private fun get(service: OverlayBubbleService, name: String): Any? = field(name).get(service)
    private fun invoke(service: OverlayBubbleService, name: String, vararg args: Any?) =
        OverlayBubbleService::class.java.declaredMethods.single { it.name == name }.apply { isAccessible = true }.invoke(service, *args)
    private fun cleanup(service: OverlayBubbleService) {
        (get(service, "lifetime") as OverlayWindowSession).destroy()
        (get(service, "thumbnailExecutor") as ExecutorService).shutdownNow()
        (get(service, "submissionIo") as ExecutorService).shutdownNow()
        (get(service, "submissionLogExecutor") as ExecutorService).shutdownNow()
        shadowOf(Looper.getMainLooper()).idle()
    }
    private fun service(channel: Channel): OverlayBubbleService {
        // Overlay permission is deliberately unavailable: onCreate attaches the
        // context and returns before starting a foreground engine/window.
        val service = Robolectric.buildService(OverlayBubbleService::class.java).create().get()
        set(service, "backgroundCommands", channel)
        set(service, "backgroundBrainReady", true)
        set(service, "chatExpanded", true)
        set(service, "chatSending", true)
        return service
    }
    @Test fun lostWakeReplyRetriesFreshAndOldSuccessCannotAcknowledgeTheNewRequest() {
        val channel = Channel(); val service = service(channel)
        try {
            set(service, "pendingBrainWakeReason", "test_wake")
            invoke(service, "signalBackgroundBrainWake")
            val old = channel.calls.single().second
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(6_600))
            assertEquals(2, channel.calls.size)
            old.success(mapOf("ok" to true))
            assertEquals("test_wake", get(service, "pendingBrainWakeReason"))
            assertEquals(true, get(service, "brainWakeInFlight"))
            channel.calls.last().second.success(mapOf("ok" to true))
            assertNull(get(service, "pendingBrainWakeReason"))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(20))
            assertEquals(2, channel.calls.size)
        } finally { cleanup(service) }
    }
    @Test fun rapidWakeSignalsCoalesceAndTheLatestReasonStillGetsDelivered() {
        val channel = Channel(); val service = service(channel)
        try {
            set(service, "pendingBrainWakeReason", "first"); invoke(service, "signalBackgroundBrainWake")
            repeat(100) { set(service, "pendingBrainWakeReason", "latest"); invoke(service, "signalBackgroundBrainWake") }
            assertEquals(1, channel.calls.size)
            channel.calls.first().second.success(mapOf("ok" to true))
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(2, channel.calls.size)
            assertEquals("latest", get(service, "pendingBrainWakeReason"))
            channel.calls.last().second.success(mapOf("ok" to true))
            assertNull(get(service, "pendingBrainWakeReason"))
        } finally { cleanup(service) }
    }
    @Test fun aSilentChannelHasAFiniteRetryBudgetAndKeepsTheWakeForRecovery() {
        val channel = Channel(); val service = service(channel)
        try {
            set(service, "pendingBrainWakeReason", "silent"); invoke(service, "signalBackgroundBrainWake")
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(80))
            assertEquals(5, channel.calls.size)
            assertEquals("silent", get(service, "pendingBrainWakeReason"))
            assertEquals(false, get(service, "brainWakeInFlight"))
            assertEquals(false, get(service, "brainWakeRetryScheduled"))
        } finally { cleanup(service) }
    }
    @Test fun anOldEngineCallbackCannotClearTheNewEnginesPendingWake() {
        val old = Channel(); val fresh = Channel(); val service = service(old)
        try {
            set(service, "pendingBrainWakeReason", "old"); invoke(service, "signalBackgroundBrainWake")
            invoke(service, "invalidateBrainWakeRequest"); set(service, "backgroundCommands", fresh)
            set(service, "pendingBrainWakeReason", "new"); invoke(service, "signalBackgroundBrainWake")
            old.calls.single().second.success(mapOf("ok" to true))
            assertEquals("new", get(service, "pendingBrainWakeReason"))
            fresh.calls.single().second.success(mapOf("ok" to true))
            assertNull(get(service, "pendingBrainWakeReason"))
        } finally { cleanup(service) }
    }
    @Test fun readyChannelWithoutSnapshotReplyReleasesUnknownUiAndIgnoresLateReply() {
        val channel = Channel(); val service = service(channel)
        try {
            invoke(service, "beginGenerationPolling")
            assertEquals("generationSnapshot", channel.calls.single().first)
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(7))
            assertEquals(false, get(service, "chatSending"))
            channel.calls.single().second.success(mapOf("sending" to true, "content" to "late"))
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(false, get(service, "chatSending"))
        } finally { cleanup(service) }
    }
    @Test fun pendingAcceptanceKeepsPollingAfterALostSnapshotInsteadOfStoppingTheChain() {
        val channel = Channel(); val service = service(channel)
        try {
            set(service, "overlaySubmitCommandPending", true)
            invoke(service, "beginGenerationPolling")
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(6300))
            assertTrue(channel.calls.count { it.first == "generationSnapshot" } >= 2)
            assertEquals(true, get(service, "chatSending"))
        } finally { cleanup(service) }
    }
    @Test fun actualHistoryHandlerCannotReplaceNewOptimisticInputWithAnOlderList() {
        val channel = Channel(); val service = service(channel)
        val activity = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val root = FrameLayout(activity.get()); activity.get().setContentView(root)
            set(service, "chatRoot", root)
            val oldRows = listOf(mapOf("id" to "old", "role" to "assistant", "content" to "old body"))
            val freshRows = oldRows + mapOf("id" to "new", "role" to "user", "content" to "new input")
            set(service, "loadedMessages", (invoke(service, "parseMessageList", oldRows) as List<*>).toMutableList())
            invoke(service, "refreshOverlayMessages", false, 0)
            assertEquals(1, channel.calls.size)
            val history = get(service, "historyRefresh") as OverlayHistoryRefreshState
            history.messagesChanged()
            set(service, "loadedMessages", (invoke(service, "parseMessageList", freshRows) as List<*>).toMutableList())
            channel.calls.first().second.success(oldRows)
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(2, (get(service, "loadedMessages") as List<*>).size)
            assertEquals(2, channel.calls.size)
        } finally { cleanup(service); activity.pause().stop().destroy() }
    }
    private fun withHistory(block: (OverlayBubbleService, Channel, Button) -> Unit) {
        val channel = Channel(); val service = service(channel)
        val activity = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val root = FrameLayout(activity.get()); activity.get().setContentView(root)
            set(service, "chatRoot", root)
            val button = Button(activity.get()); set(service, "chatLoadOlder", button)
            val rows = listOf(mapOf("id" to "current", "role" to "user", "content" to "body"))
            set(service, "loadedMessages", (invoke(service, "parseMessageList", rows) as List<*>).toMutableList())
            block(service, channel, button)
        } finally { cleanup(service); activity.pause().stop().destroy() }
    }
    @Test fun olderHistoryTransportExceptionDoesNotEscapeTheUiHandler() = withHistory { service, channel, button ->
        channel.throwOnInvoke = true
        invoke(service, "loadOlderMessages")
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(button.isEnabled)
        assertEquals(1, (get(service, "loadedMessages") as List<*>).size)
    }
    @Test fun olderHistoryTimeoutRestoresButtonAndLateReplyCannotAppendRows() = withHistory { service, channel, button ->
        invoke(service, "loadOlderMessages")
        assertFalse(button.isEnabled)
        val old = channel.calls.single().second
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(9))
        assertTrue(button.isEnabled)
        invoke(service, "loadOlderMessages")
        old.success(listOf(mapOf("id" to "late", "role" to "user")))
        shadowOf(Looper.getMainLooper()).idle()
        assertFalse(button.isEnabled) // An old reply must not finish the new read.
        assertEquals(1, (get(service, "loadedMessages") as List<*>).size)
        channel.calls.last().second.success(listOf(mapOf("id" to "fresh", "role" to "user")))
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(button.isEnabled)
        assertEquals(2, (get(service, "loadedMessages") as List<*>).size)
    }
    @Test fun replacingHistoryWhileOlderPageIsInFlightDoesNotResurrectOldRows() = withHistory { service, channel, button ->
        invoke(service, "loadOlderMessages")
        set(service, "loadedMessages", mutableListOf<Any>())
        channel.calls.single().second.success(listOf(mapOf("id" to "old", "role" to "user")))
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(button.isEnabled)
        assertTrue((get(service, "loadedMessages") as List<*>).isEmpty())
    }
    @Test fun replacedChannelRejectsOldHistoryAndRestoresReadControl() = withHistory { service, channel, button ->
        invoke(service, "loadOlderMessages")
        set(service, "backgroundCommands", Channel())
        channel.calls.single().second.success(listOf(mapOf("id" to "old", "role" to "user")))
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(button.isEnabled)
        assertEquals(1, (get(service, "loadedMessages") as List<*>).size)
    }
    @Test fun destroyedServiceIgnoresReadTimeoutAndReply() = withHistory { service, channel, button ->
        invoke(service, "loadOlderMessages")
        (get(service, "lifetime") as OverlayWindowSession).destroy()
        channel.calls.single().second.success(listOf(mapOf("id" to "late", "role" to "user")))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(9))
        assertEquals(1, (get(service, "loadedMessages") as List<*>).size)
        assertFalse(button.isEnabled) // Obsolete UI receives no writes.
    }
    @Test fun ttsSnapshotTimeoutContinuesPollingAndIgnoresLatePlayingState() {
        val channel = Channel(); val service = service(channel)
        try {
            invoke(service, "beginTtsPolling")
            val old = channel.calls.single().second
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(10))
            assertTrue(channel.calls.count { it.first == "ttsSnapshot" } >= 2)
            old.success(mapOf("phase" to "playing", "message_id" to "late"))
            shadowOf(Looper.getMainLooper()).idle()
            assertNotEquals("late", get(service, "overlayTtsMessageId"))
        } finally { cleanup(service) }
    }
    @Test fun duplicateHistoryRepliesHaveOnlyOneTerminalEffect() = withHistory { service, channel, button ->
        invoke(service, "loadOlderMessages")
        val reply = channel.calls.single().second
        reply.success(listOf(mapOf("id" to "first", "role" to "user")))
        reply.success(listOf(mapOf("id" to "second", "role" to "user")))
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(button.isEnabled)
        assertEquals(2, (get(service, "loadedMessages") as List<*>).size)
    }

    @Test fun channelReplacementBetweenTransportAndUiApplyCannotInsertOldRows() = withHistory { service, channel, button ->
        invoke(service, "loadOlderMessages")
        channel.calls.single().second.success(listOf(mapOf("id" to "old", "role" to "user")))
        // Transport completion queues UI application. Replace the engine in
        // that gap to verify the check at the actual state mutation boundary.
        Handler(Looper.getMainLooper()).post { set(service, "backgroundCommands", Channel()) }
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(button.isEnabled)
        assertEquals(1, (get(service, "loadedMessages") as List<*>).size)
    }

}
