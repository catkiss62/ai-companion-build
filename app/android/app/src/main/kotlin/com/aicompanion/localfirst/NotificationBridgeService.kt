package com.aicompanion.localfirst

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationBridgeService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        CompanionRuntimeState.setNotificationListenerConnected(true)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "notification_listener_connected",
            appPackage = packageName,
            summary = "通知感知服务已连接。",
        )
    }

    override fun onListenerDisconnected() {
        CompanionRuntimeState.setNotificationListenerConnected(false)
        NativeEventStore.addDeviceEvent(
            this,
            source = "system",
            eventType = "notification_listener_disconnected",
            appPackage = packageName,
            summary = "通知感知服务与系统断开，已请求重新绑定。",
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            runCatching {
                requestRebind(ComponentName(this, NotificationBridgeService::class.java))
            }
        }
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val item = sbn ?: return
        val sourcePackage = item.packageName
        if (!PrivacyFilter.allowPackage(sourcePackage)) return
        val extras = item.notification.extras ?: return
        val title = PrivacyFilter.sanitize(extras.getCharSequence(Notification.EXTRA_TITLE), 120)
        val text = PrivacyFilter.sanitize(extras.getCharSequence(Notification.EXTRA_TEXT), 280)
        val summary = listOf(title, text).filter { it.isNotBlank() }.joinToString(" · ")
        if (summary.isBlank()) return
        NativeEventStore.addDeviceEvent(
            this,
            source = "notification",
            eventType = "notification_posted",
            appPackage = sourcePackage,
            summary = summary,
            metadata = mapOf("notification_id" to item.id),
        )
    }

    override fun onDestroy() {
        CompanionRuntimeState.setNotificationListenerConnected(false)
        super.onDestroy()
    }
}
