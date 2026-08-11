package com.aicompanion.localfirst

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.os.Build

object CompanionNotification {
    const val CHANNEL_MESSAGES = "companion_messages"
    const val CHANNEL_MESSAGES_GENTLE = "companion_messages_gentle"
    const val CHANNEL_SERVICE = "companion_service"
    const val OVERLAY_FOREGROUND_ID = 41001
    const val REMOTE_INPUT_REPLY = "companion_inline_reply"
    const val EXTRA_MESSAGE_ID = "companion_message_id"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MESSAGES,
                "AI 女友消息",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "AI Companion 主动消息与聊天提醒"
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MESSAGES_GENTLE,
                "AI 女友轻声消息",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "忙碌或低压力时的主动留言；默认不弹出强提醒"
                setShowBadge(true)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_SERVICE,
                "AI Companion 常驻",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "悬浮球和本地陪伴服务"
                setShowBadge(false)
            },
        )
    }

    private fun overlayServiceIntent(context: Context, reason: String): Intent =
        Intent(context, OverlayBubbleService::class.java)
            .setAction(OverlayBubbleService.ACTION_SHOW_CHAT)
            .putExtra("reason", reason.take(120))

    private fun overlayPendingIntent(
        context: Context,
        requestCode: Int,
        reason: String,
    ): PendingIntent {
        val intent = overlayServiceIntent(context, reason)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(context, requestCode, intent, flags)
        } else {
            PendingIntent.getService(context, requestCode, intent, flags)
        }
    }

    fun postMessage(
        context: Context,
        title: String,
        body: String,
        messageId: String,
        intentKind: String = "",
        deliveryStyle: String = "normal",
    ) {
        ensureChannels(context)
        val pending = overlayPendingIntent(
            context,
            messageId.hashCode(),
            "message_notification:$messageId",
        )
        val quiet = deliveryStyle == "quiet"
        val channelId = if (quiet) CHANNEL_MESSAGES_GENTLE else CHANNEL_MESSAGES
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION") android.app.Notification.Builder(context)
        }
        val replyIntent = Intent(context, CompanionReplyReceiver::class.java)
            .putExtra(EXTRA_MESSAGE_ID, messageId)
        val replyFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val replyPending = PendingIntent.getBroadcast(
            context,
            messageId.hashCode() xor 0x51A7,
            replyIntent,
            replyFlags,
        )
        val remoteInput = RemoteInput.Builder(REMOTE_INPUT_REPLY)
            .setLabel("回复她")
            .build()
        val replyAction = android.app.Notification.Action.Builder(
            android.R.drawable.ic_menu_send,
            "回复",
            replyPending,
        )
            .addRemoteInput(remoteInput)
            .build()
        val label = intentLabel(intentKind)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O && quiet) {
            @Suppress("DEPRECATION")
            builder.setPriority(android.app.Notification.PRIORITY_LOW)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(android.app.Notification.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(quiet)
            .setSubText(label)
            .setCategory(android.app.Notification.CATEGORY_MESSAGE)
            .addAction(replyAction)
            .build()
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) {
            NativeEventStore.addDeviceEvent(
                context,
                source = "system",
                eventType = "companion_notification_suppressed",
                appPackage = context.packageName,
                summary = "主动消息已经写入本地，但系统通知当前被关闭。",
            )
            return
        }
        runCatching { manager.notify(messageId.hashCode(), notification) }
            .onFailure { error ->
                NativeEventStore.addDeviceEvent(
                    context,
                    source = "system",
                    eventType = "companion_notification_failed",
                    appPackage = context.packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
            }
    }

    private fun intentLabel(intentKind: String): String = when (intentKind) {
        "miss_you" -> "想你"
        "followup" -> "续上次的话"
        "share_thought" -> "分享念头"
        "curiosity" -> "好奇"
        "social_share" -> "随手分享"
        "intimacy_invitation" -> "亲密邀约"
        "emotional_reach" -> "想靠近你"
        else -> "主动消息"
    }

    fun buildOverlayForeground(context: Context): android.app.Notification {
        ensureChannels(context)
        val pending = overlayPendingIntent(context, 41002, "foreground_notification")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL_SERVICE)
        } else {
            @Suppress("DEPRECATION") android.app.Notification.Builder(context)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("AI Companion 在这里")
            .setContentText("悬浮聊天已开启")
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(android.app.Notification.CATEGORY_SERVICE)
            .build()
    }
}
