package com.aicompanion.localfirst

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.app.RemoteInput
import java.util.UUID

/** Receives the inline-reply action from a companion notification.
 *
 * The receiver never touches the SQLite brain directly. It hands the text to
 * the persistent overlay service, which forwards it to the same Dart
 * ChatController used by the full app and true overlay chat.
 */
class CompanionReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val actual = intent ?: return
        val text = RemoteInput.getResultsFromIntent(actual)
            ?.getCharSequence(CompanionNotification.REMOTE_INPUT_REPLY)
            ?.toString()
            ?.trim()
            .orEmpty()
        if (text.isEmpty()) return

        val replyId = "notification-reply:${UUID.randomUUID()}"
        val serviceIntent = Intent(context, OverlayBubbleService::class.java)
            .setAction(OverlayBubbleService.ACTION_NOTIFICATION_REPLY)
            .putExtra(OverlayBubbleService.EXTRA_REPLY_TEXT, text.take(6000))
            .putExtra(OverlayBubbleService.EXTRA_REPLY_ID, replyId)
            .putExtra(
                OverlayBubbleService.EXTRA_REPLY_TO_MESSAGE_ID,
                actual.getStringExtra(CompanionNotification.EXTRA_MESSAGE_ID).orEmpty(),
            )
            .putExtra("reason", "notification_inline_reply")

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !OverlayBubbleService.running) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }.onFailure { error ->
            NativeEventStore.addDeviceEvent(
                context = context,
                source = "system",
                eventType = "notification_inline_reply_failed",
                appPackage = context.packageName,
                summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
            )
        }
    }
}
