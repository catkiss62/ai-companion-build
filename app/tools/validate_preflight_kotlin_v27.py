#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
STUBS={
'android/Manifest.kt': r'''package android
object Manifest { object permission {
 const val BLUETOOTH_ADVERTISE="android.permission.BLUETOOTH_ADVERTISE"
 const val BLUETOOTH_CONNECT="android.permission.BLUETOOTH_CONNECT"
 const val BLUETOOTH_SCAN="android.permission.BLUETOOTH_SCAN"
 const val NEARBY_WIFI_DEVICES="android.permission.NEARBY_WIFI_DEVICES"
 const val ACCESS_FINE_LOCATION="android.permission.ACCESS_FINE_LOCATION"
 const val ACCESS_COARSE_LOCATION="android.permission.ACCESS_COARSE_LOCATION"
} }
''',
'android/content/Context.kt': r'''package android.content
import android.content.pm.PackageManager
open class Context {
 open val packageName:String="com.test"
 open val packageManager:PackageManager=PackageManager()
 open fun checkSelfPermission(p:String):Int=PackageManager.PERMISSION_GRANTED
 open fun <T> getSystemService(c:Class<T>):T = c.getDeclaredConstructor().newInstance()
}
''',
'android/content/pm/PackageManager.kt': r'''package android.content.pm
open class PackageManager {
 companion object { const val PERMISSION_GRANTED=0 }
 class PackageInfoFlags private constructor() { companion object { fun of(v:Long)=PackageInfoFlags() } }
 open fun getPackageInfo(name:String, flags:Int)=PackageInfo()
 open fun getPackageInfo(name:String, flags:PackageInfoFlags)=PackageInfo()
}
class PackageInfo { var versionName:String?="0.27.0"; var versionCode:Int=27; var longVersionCode:Long=27 }
''',
'android/app/ActivityManager.kt': 'package android.app\nopen class ActivityManager { open val isBackgroundRestricted:Boolean=false }\n',
'android/bluetooth/BluetoothManager.kt': r'''package android.bluetooth
open class BluetoothManager { open val adapter:BluetoothAdapter?=BluetoothAdapter() }
open class BluetoothAdapter { open val isEnabled:Boolean=true }
''',
'android/location/LocationManager.kt': 'package android.location\nopen class LocationManager { open val isLocationEnabled:Boolean=true }\n',
'android/media/Audio.kt': r'''package android.media
open class AudioDeviceInfo(val type:Int=TYPE_BUILTIN_SPEAKER) { companion object {
 const val TYPE_BUILTIN_SPEAKER=2; const val TYPE_BUILTIN_EARPIECE=1; const val TYPE_WIRED_HEADPHONES=4; const val TYPE_WIRED_HEADSET=3
 const val TYPE_BLUETOOTH_A2DP=8; const val TYPE_BLUETOOTH_SCO=7; const val TYPE_USB_DEVICE=11; const val TYPE_USB_HEADSET=22
} }
open class AudioManager { companion object { const val GET_DEVICES_OUTPUTS=2 }; open fun getDevices(v:Int)=arrayOf(AudioDeviceInfo()); open val mode:Int=0; open val isMusicActive:Boolean=false }
''',
'android/os/Core.kt': r'''package android.os
object Build { var MANUFACTURER="x"; var MODEL="y"; object VERSION { var SDK_INT=35; var RELEASE="15" }; object VERSION_CODES { const val M=23 } }
open class PowerManager { open fun isIgnoringBatteryOptimizations(p:String)=false }
''',
'com/google/android/gms/common/Google.kt': r'''package com.google.android.gms.common
import android.content.Context
object ConnectionResult { const val SUCCESS=0 }
class GoogleApiAvailability private constructor() { companion object { fun getInstance()=GoogleApiAvailability() }; fun isGooglePlayServicesAvailable(c:Context)=0 }
''',
'com/aicompanion/localfirst/RuntimeDiagnosticStore.kt': r'''package com.aicompanion.localfirst
import android.content.Context
object RuntimeDiagnosticStore { fun snapshot(c:Context,limit:Int=120):List<Map<String,Any?>> = emptyList() }
''',
}
def main()->int:
    compiler=shutil.which('kotlinc')
    if not compiler:
        print('[SKIP] kotlinc unavailable'); return 0
    with tempfile.TemporaryDirectory(prefix='preflight-kotlin-v27-') as td:
        td=Path(td); src=td/'src'
        for rel,text in STUBS.items():
            p=src/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text)
        actual=ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/NativePreflightProbe.kt'
        cp=subprocess.run([compiler,str(src),str(actual),'-d',str(td/'out.jar')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        if cp.returncode:
            print(cp.stderr); return cp.returncode
    print('[OK] NativePreflightProbe Kotlin compiles against Android/Play-services API stubs')
    return 0
if __name__=='__main__': raise SystemExit(main())
