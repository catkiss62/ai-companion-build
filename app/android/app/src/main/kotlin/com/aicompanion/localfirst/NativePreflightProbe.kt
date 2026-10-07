package com.aicompanion.localfirst

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager

/** Read-only Android runtime probe used by the v0.27 device preflight page. */
object NativePreflightProbe {
    fun collect(
        context: Context,
        capabilities: Map<String, Any>,
    ): Map<String, Any> {
        val power = context.getSystemService(PowerManager::class.java)
        val activityManager = context.getSystemService(ActivityManager::class.java)
        val audio = context.getSystemService(AudioManager::class.java)
        val outputs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .map { audioDeviceName(it.type) }
                .distinct()
                .sorted()
        } else emptyList()
        @Suppress("DEPRECATION")
        val versionInfo = if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            context.packageManager.getPackageInfo(context.packageName, 0)
        }
        @Suppress("DEPRECATION")
        val versionCode = if (Build.VERSION.SDK_INT >= 28) {
            versionInfo.longVersionCode
        } else {
            versionInfo.versionCode.toLong()
        }
        return mapOf(
            "app" to mapOf(
                "versionName" to (versionInfo.versionName ?: ""),
                "versionCode" to versionCode,
                "packageName" to context.packageName,
            ),
            "android" to mapOf(
                "sdk" to Build.VERSION.SDK_INT,
                "release" to Build.VERSION.RELEASE,
                "manufacturer" to Build.MANUFACTURER.take(40),
                "model" to Build.MODEL.take(60),
                "backgroundRestricted" to (Build.VERSION.SDK_INT >= 28 && activityManager.isBackgroundRestricted),
                "batteryOptimizationIgnored" to power.isIgnoringBatteryOptimizations(context.packageName),
            ),
            "capabilities" to capabilities,
            "audio" to mapOf(
                "mode" to audio.mode,
                "musicActive" to audio.isMusicActive,
                "outputDevices" to outputs,
            ),
            "runtimeDiagnosticCount" to RuntimeDiagnosticStore.snapshot(context, 160).size,
        )
    }

    private fun audioDeviceName(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetooth_a2dp"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth_sco"
        AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
        else -> "type_$type"
    }
}
