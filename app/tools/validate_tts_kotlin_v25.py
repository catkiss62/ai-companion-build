#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

STUBS = {
    'android/content/Context.kt': '''package android.content
import android.content.pm.ApplicationInfo
import android.content.res.AssetManager
import java.io.File
open class Context {
    open val applicationContext: Context get() = this
    open val assets: AssetManager = AssetManager()
    open val applicationInfo: ApplicationInfo = ApplicationInfo()
    open val codeCacheDir: File = File(".")
    open val classLoader: ClassLoader = javaClass.classLoader ?: ClassLoader.getSystemClassLoader()
}
''',
    'android/content/res/AssetManager.kt': '''package android.content.res
import java.io.ByteArrayInputStream
import java.io.InputStream
open class AssetManager {
    open fun list(path: String): Array<String>? = emptyArray()
    open fun open(path: String): InputStream = ByteArrayInputStream(byteArrayOf())
}
''',
    'android/content/pm/ApplicationInfo.kt': '''package android.content.pm
open class ApplicationInfo { var nativeLibraryDir: String = "." }
''',
    'android/util/Base64.kt': '''package android.util
object Base64 { const val DEFAULT: Int = 0; fun decode(value: String, flags: Int): ByteArray = byteArrayOf() }
''',
    'android/os/Looper.kt': '''package android.os
class Looper { companion object { fun getMainLooper(): Looper = Looper() } }
''',
    'android/os/Handler.kt': '''package android.os
class Handler(looper: Looper) { fun post(r: () -> Unit): Boolean { r(); return true } }
''',
    'dalvik/system/DexClassLoader.kt': '''package dalvik.system
class DexClassLoader(dexPath: String, optimizedDirectory: String, librarySearchPath: String?, parent: ClassLoader?) : ClassLoader(parent)
''',
    'io/flutter/embedding/engine/FlutterEngine.kt': '''package io.flutter.embedding.engine
class FlutterEngine { val dartExecutor = DartExecutor(); class DartExecutor { val binaryMessenger: Any = Any() } }
''',
    'io/flutter/plugin/common/MethodChannel.kt': '''package io.flutter.plugin.common
class MethodChannel(messenger: Any, name: String) {
    class MethodCall(val method: String) { fun <T> argument(name: String): T? = null }
    interface Result { fun success(value: Any?); fun error(code: String, message: String?, details: Any?); fun notImplemented() }
    fun setMethodCallHandler(handler: ((MethodCall, Result) -> Unit)?) {}
}
''',
    'com/aicompanion/localfirst/WavAudioPlayer.kt': '''package com.aicompanion.localfirst
class WavAudioPlayer { fun stop(){}; fun pause(){}; fun resume(){}; fun setVolume(v: Float){}; fun play(b: ByteArray){} }
''',
    'com/aicompanion/localfirst/RuntimeDiagnosticStore.kt': '''package com.aicompanion.localfirst
import android.content.Context
object RuntimeDiagnosticStore {
    fun record(context: Context, category: String, phase: String, severity: String = "info", code: String = "", detail: String = "", metadata: Map<String, Any?> = emptyMap()) {}
}
''',
}

SOURCES = [
    'TtsGoldenBaseline.kt',
    'TtsArtifactVerifier.kt',
    'LegacyTtsRuntime.kt',
    'NativeTtsEngine.kt',
    'NativeTtsBridge.kt',
]


def main() -> int:
    compiler = shutil.which('kotlinc')
    if compiler is None:
        print('[SKIP] kotlinc not available')
        return 0
    with tempfile.TemporaryDirectory(prefix='tts-kotlin-v25-') as td:
        temp = Path(td)
        src_root = temp / 'src'
        for rel, text in STUBS.items():
            path = src_root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
        actual_root = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst'
        cmd = [compiler, str(src_root)] + [str(actual_root / name) for name in SOURCES] + ['-d', str(temp / 'out.jar')]
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    print('[OK] key Kotlin TTS runtime/bridge sources compile against API stubs')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
