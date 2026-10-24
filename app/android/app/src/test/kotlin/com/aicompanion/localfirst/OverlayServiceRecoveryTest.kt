package com.aicompanion.localfirst

import android.app.Activity
import android.os.Looper
import android.widget.FrameLayout
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
    private class Channel : MethodChannel(object : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {}
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {}
    }, "fixture") {
        val calls = mutableListOf<Pair<String, MethodChannel.Result>>()
        override fun invokeMethod(method: String, arguments: Any?, callback: MethodChannel.Result?) {
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
}
