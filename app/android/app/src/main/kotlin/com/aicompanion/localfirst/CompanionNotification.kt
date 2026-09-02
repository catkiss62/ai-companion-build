package com.aicompanion.localfirst

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Person
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

object CompanionNotification {
    const val CHANNEL_MESSAGES = "companion_messages"
    const val CHANNEL_MESSAGES_CHIME = "companion_messages_chime_v1"
    const val CHANNEL_MESSAGES_SOFT = "companion_messages_soft_v1"
    const val CHANNEL_MESSAGES_CHIME_V2 = "companion_messages_chime_v2"
    const val CHANNEL_MESSAGES_SOFT_V2 = "companion_messages_soft_v2"
    const val CHANNEL_MESSAGES_BUBBLE_V1 = "companion_messages_bubble_v1"
    const val CHANNEL_MESSAGES_SYSTEM = "companion_messages_system_v1"
    const val CHANNEL_MESSAGES_SILENT = "companion_messages_silent_v1"
    const val CHANNEL_MESSAGES_GENTLE = "companion_messages_gentle"
    const val CHANNEL_SERVICE = "companion_service"
    const val OVERLAY_FOREGROUND_ID = 41001
    const val CONVERSATION_NOTIFICATION_ID = 41003
    const val REMOTE_INPUT_REPLY = "companion_inline_reply"
    const val EXTRA_MESSAGE_ID = "companion_message_id"
    private const val DIAGNOSTIC_PREFS = "companion_notification_diagnostics"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val notificationAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        fun soundUri(rawId: Int): Uri = Uri.parse(
            "android.resource://${context.packageName}/$rawId",
        )
        fun popupChannel(
            id: String,
            name: String,
            sound: Uri?,
            silent: Boolean = false,
        ) = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
            description = "她主动找你时的系统横幅消息"
            enableLights(true)
            setShowBadge(true)
            if (silent) {
                setSound(null, null)
                enableVibration(false)
            } else {
                setSound(sound, notificationAttributes)
            }
        }
        manager.createNotificationChannels(
            listOf(
                // Keep the historical channel so existing installs retain
                // their user-controlled notification settings.
                popupChannel(
                    CHANNEL_MESSAGES,
                    "AI 女友消息（旧频道）",
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                ),
                popupChannel(
                    CHANNEL_MESSAGES_CHIME_V2,
                    "AI 女友消息 · 清脆三音",
                    soundUri(R.raw.companion_chime_v2),
                ),
                popupChannel(
                    CHANNEL_MESSAGES_SOFT_V2,
                    "AI 女友消息 · 柔和水滴",
                    soundUri(R.raw.companion_soft_v2),
                ),
                popupChannel(
                    CHANNEL_MESSAGES_BUBBLE_V1,
                    "AI 女友消息 · 气泡轻弹",
                    soundUri(R.raw.companion_bubble_v1),
                ),
                popupChannel(
                    CHANNEL_MESSAGES_SYSTEM,
                    "AI 女友消息 · 系统默认音",
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                ),
                popupChannel(
                    CHANNEL_MESSAGES_SILENT,
                    "AI 女友消息 · 静音弹窗",
                    null,
                    silent = true,
                ),
            ),
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
        soundKey: String = "chime",
    ): Map<String, Any> {
        ensureChannels(context)
        val pending = overlayPendingIntent(
            context,
            CONVERSATION_NOTIFICATION_ID,
            "message_notification:$messageId",
        )
        val quiet = deliveryStyle == "quiet"
        val normalizedSound = normalizeSoundKey(soundKey)
        val channelId = if (quiet) {
            CHANNEL_MESSAGES_GENTLE
        } else {
            popupChannelId(normalizedSound)
        }
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(
                if (quiet) android.app.Notification.PRIORITY_LOW
                else android.app.Notification.PRIORITY_HIGH,
            )
            if (!quiet) {
                when (normalizedSound) {
                    "silent" -> builder.setSound(null)
                    "system" -> builder.setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    )
                    "soft" -> builder.setSound(
                        Uri.parse("android.resource://${context.packageName}/${R.raw.companion_soft_v2}"),
                    )
                    "bubble" -> builder.setSound(
                        Uri.parse("android.resource://${context.packageName}/${R.raw.companion_bubble_v1}"),
                    )
                    else -> builder.setSound(
                        Uri.parse("android.resource://${context.packageName}/${R.raw.companion_chime_v2}"),
                    )
                }
            }
        }
        val style = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val user = Person.Builder().setName("你").build()
            val companion = Person.Builder().setName(title.ifBlank { "她" }).build()
            android.app.Notification.MessagingStyle(user)
                .addMessage(body, System.currentTimeMillis(), companion)
        } else {
            android.app.Notification.BigTextStyle().bigText(body)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(style)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(quiet)
            .setSubText(label)
            .setCategory(android.app.Notification.CATEGORY_MESSAGE)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .addAction(replyAction)
            .build()
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) {
            recordOutcome(
                context,
                posted = false,
                reason = "notifications_disabled",
                channelId = channelId,
                soundKey = normalizedSound,
            )
            NativeEventStore.addDeviceEvent(
                context,
                source = "system",
                eventType = "companion_notification_suppressed",
                appPackage = context.packageName,
                summary = "主动消息已经写入本地，但系统通知当前被关闭。",
            )
            return mapOf(
                "posted" to false,
                "reason" to "notifications_disabled",
                "channelId" to channelId,
                "soundKey" to normalizedSound,
            )
        }
        val result = runCatching {
            // A single relationship conversation replaces its previous banner;
            // durable chat history remains in SQLite, not in NotificationManager.
            manager.notify(CONVERSATION_NOTIFICATION_ID, notification)
        }
        result.onSuccess {
            recordOutcome(
                context,
                posted = true,
                reason = "posted",
                channelId = channelId,
                soundKey = normalizedSound,
            )
            NativeEventStore.addDeviceEvent(
                context,
                source = "system",
                eventType = "companion_notification_posted",
                appPackage = context.packageName,
                summary = "主动消息通知已交给 Android。",
                metadata = mapOf(
                    "channel" to channelId,
                    "sound" to normalizedSound,
                    "quiet" to quiet,
                ),
            )
        }.onFailure { error ->
                recordOutcome(
                    context,
                    posted = false,
                    reason = error.javaClass.simpleName,
                    channelId = channelId,
                    soundKey = normalizedSound,
                )
                NativeEventStore.addDeviceEvent(
                    context,
                    source = "system",
                    eventType = "companion_notification_failed",
                    appPackage = context.packageName,
                    summary = "${error.javaClass.simpleName}: ${error.message ?: "unknown"}",
                )
            }
        return mapOf(
            "posted" to result.isSuccess,
            "reason" to if (result.isSuccess) "posted" else
                (result.exceptionOrNull()?.javaClass?.simpleName ?: "unknown"),
            "channelId" to channelId,
            "soundKey" to normalizedSound,
        )
    }

    fun diagnosticStatus(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(DIAGNOSTIC_PREFS, Context.MODE_PRIVATE)
        val manager = context.getSystemService(NotificationManager::class.java)
        val channelId = prefs.getString("last_channel", "") ?: ""
        val importance = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channelId.isNotBlank()) {
            manager.getNotificationChannel(channelId)?.importance ?: -1
        } else {
            -1
        }
        return mapOf(
            "companionNotificationsEnabled" to
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || manager.areNotificationsEnabled()),
            "companionNotificationLastPosted" to prefs.getBoolean("last_posted", false),
            "companionNotificationLastAt" to prefs.getLong("last_at", 0L),
            "companionNotificationLastReason" to
                (prefs.getString("last_reason", "") ?: ""),
            "companionNotificationLastChannel" to channelId,
            "companionNotificationLastChannelImportance" to importance,
            "companionNotificationLastSound" to
                (prefs.getString("last_sound", "") ?: ""),
            "companionNotificationLastAcknowledgedAt" to
                prefs.getLong("last_acknowledged_at", 0L),
            "companionNotificationLastAcknowledgeReason" to
                (prefs.getString("last_acknowledge_reason", "") ?: ""),
            "companionNotificationStyle" to "messaging",
        )
    }

    fun acknowledgeMessages(context: Context, reason: String) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(CONVERSATION_NOTIFICATION_ID)
        context.getSharedPreferences(DIAGNOSTIC_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong("last_acknowledged_at", System.currentTimeMillis())
            .putString("last_acknowledge_reason", reason.take(80))
            .apply()
    }

    fun openMessageChannelSettings(context: Context, soundKey: String) {
        ensureChannels(context)
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                .putExtra(
                    Settings.EXTRA_CHANNEL_ID,
                    popupChannelId(normalizeSoundKey(soundKey)),
                )
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
        context.startActivity(intent)
    }

    internal fun normalizeSoundKey(soundKey: String): String = when (soundKey) {
        "soft", "bubble", "system", "silent" -> soundKey
        else -> "chime"
    }

    internal fun popupChannelId(soundKey: String): String = when (soundKey) {
        "soft" -> CHANNEL_MESSAGES_SOFT_V2
        "bubble" -> CHANNEL_MESSAGES_BUBBLE_V1
        "system" -> CHANNEL_MESSAGES_SYSTEM
        "silent" -> CHANNEL_MESSAGES_SILENT
        else -> CHANNEL_MESSAGES_CHIME_V2
    }

    internal fun bundledSoundResource(soundKey: String): Int? = when (
        normalizeSoundKey(soundKey)
    ) {
        "chime" -> R.raw.companion_chime_v2
        "soft" -> R.raw.companion_soft_v2
        "bubble" -> R.raw.companion_bubble_v1
        else -> null
    }

    private fun recordOutcome(
        context: Context,
        posted: Boolean,
        reason: String,
        channelId: String,
        soundKey: String,
    ) {
        context.getSharedPreferences(DIAGNOSTIC_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("last_posted", posted)
            .putLong("last_at", System.currentTimeMillis())
            .putString("last_reason", reason.take(80))
            .putString("last_channel", channelId.take(80))
            .putString("last_sound", soundKey.take(20))
            .apply()
    }

    private fun intentLabel(intentKind: String): String = when (intentKind) {
        "miss_you" -> "想你"
        "followup" -> "想起之前的话"
        "share_thought" -> "分享念头"
        "curiosity" -> "好奇"
        "social_share" -> "随手分享"
        "intimacy_invitation" -> "亲密邀约"
        "emotional_reach" -> "想靠近你"
        "diagnostic_test" -> "跨 App 测试"
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
