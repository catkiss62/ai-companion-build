package com.aicompanion.localfirst

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings

/** Restores the explicitly user-enabled persistent companion after reboot/update. */
class CompanionBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }
        if (!CompanionRuntimeState.isOverlayUserEnabled(context)) return
        if (!Settings.canDrawOverlays(context)) {
            NativeEventStore.addDeviceEvent(
                context,
                source = "system",
                eventType = "overlay_restore_skipped_permission",
                appPackage = context.packageName,
                summary = "悬浮陪伴曾开启，但系统当前未授予悬浮窗权限。",
            )
            return
        }
        OverlayBubbleService.startPersistent(context, "${action.substringAfterLast('.')}:restore")
    }
}
