package com.aicompanion.localfirst

import android.Manifest
import android.app.ActivityManager
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability

/** Read-only Android runtime probe used by the v0.27 device preflight page. */
object NativePreflightProbe {
    fun collect(
        context: Context,
        capabilities: Map<String, Any>,
    ): Map<String, Any> {
        val power = context.getSystemService(PowerManager::class.java)
        val activityManager = context.getSystemService(ActivityManager::class.java)
        val audio = context.getSystemService(AudioManager::class.java)
        val bluetooth = context.getSystemService(BluetoothManager::class.java).adapter
        val location = context.getSystemService(LocationManager::class.java)
        val missingNearby = nearbyPermissionNames().filter { permission ->
            context.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED
        }
        val playServices = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context)
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
        val bluetoothEnabled = runCatching { bluetooth?.isEnabled == true }.getOrDefault(false)
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
            "nearby" to mapOf(
                "permissionsGranted" to missingNearby.isEmpty(),
                "missingPermissions" to missingNearby.map { it.substringAfterLast('.') },
                "bluetoothEnabled" to bluetoothEnabled,
                "locationEnabled" to (if (Build.VERSION.SDK_INT >= 28) location.isLocationEnabled else true),
                "googlePlayServicesAvailable" to (playServices == ConnectionResult.SUCCESS),
                "googlePlayServicesCode" to playServices,
            ),
            "audio" to mapOf(
                "mode" to audio.mode,
                "musicActive" to audio.isMusicActive,
                "outputDevices" to outputs,
            ),
            "runtimeDiagnosticCount" to RuntimeDiagnosticStore.snapshot(context, 160).size,
        )
    }

    fun nearbyPermissionNames(): List<String> = when {
        Build.VERSION.SDK_INT >= 37 -> listOf(
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.NEARBY_WIFI_DEVICES,
            "android.permission.ACCESS_LOCAL_NETWORK",
        )
        Build.VERSION.SDK_INT >= 33 -> listOf(
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.NEARBY_WIFI_DEVICES,
        )
        Build.VERSION.SDK_INT >= 31 -> listOf(
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
        Build.VERSION.SDK_INT >= 29 -> listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        else -> listOf(Manifest.permission.ACCESS_COARSE_LOCATION)
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
