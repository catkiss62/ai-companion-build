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
    'dalvik/system/DexClassLoader.kt': '''package dalvik.system
class DexClassLoader(dexPath: String, optimizedDirectory: String, librarySearchPath: String?, parent: ClassLoader?) : ClassLoader(parent)
''',
}

PROBE = r'''package probe

import android.content.Context
import com.aicompanion.localfirst.LegacyTtsRuntime

interface FakeContext {
    fun fold(initial: Any?, operation: Any?): Any?
    fun get(key: Any?): Any?
    fun minusKey(key: Any?): FakeContext
    fun plus(other: FakeContext): FakeContext
}

class OtherContext : FakeContext {
    override fun fold(initial: Any?, operation: Any?) = initial
    override fun get(key: Any?) = null
    override fun minusKey(key: Any?) = this
    override fun plus(other: FakeContext) = other
}

enum class FakeMarker { COROUTINE_SUSPENDED }
class RenamedFailure(val z: Throwable)

fun main() {
    val runtime = LegacyTtsRuntime(Context())
    val create = LegacyTtsRuntime::class.java.getDeclaredMethod(
        "createEmptyCoroutineContext", Class::class.java, ClassLoader::class.java,
    ).apply { isAccessible = true }
    val empty = create.invoke(runtime, FakeContext::class.java, FakeContext::class.java.classLoader) as FakeContext
    check(empty.fold("seed", Any()) == "seed")
    check(empty.get(Any()) == null)
    check(empty.minusKey(Any()) === empty)
    val other = OtherContext()
    check(empty.plus(other) === other)

    val suspended = LegacyTtsRuntime::class.java.getDeclaredMethod(
        "isCoroutineSuspended", Any::class.java,
    ).apply { isAccessible = true }
    check(suspended.invoke(runtime, FakeMarker.COROUTINE_SUSPENDED) == true)
    check(suspended.invoke(runtime, "audio") == false)

    val decode = LegacyTtsRuntime::class.java.getDeclaredMethod(
        "decodeLegacyResult", Any::class.java,
    ).apply { isAccessible = true }
    val boom = IllegalStateException("boom")
    val outcome = decode.invoke(runtime, RenamedFailure(boom))
    val errorGetter = outcome.javaClass.getMethod("getError").apply { isAccessible = true }
    check(errorGetter.invoke(outcome) === boom)

    println("[OK] synthetic coroutine context proxy / suspend marker / R8-style failure box")
}
'''


def main() -> int:
    kotlinc = shutil.which('kotlinc')
    kotlin = shutil.which('kotlin')
    if kotlinc is None or kotlin is None:
        print('[SKIP] Kotlin JVM runner unavailable')
        return 0
    with tempfile.TemporaryDirectory(prefix='v0285-coroutine-proxy-') as td:
        td = Path(td)
        src = td / 'src'
        for rel, text in STUBS.items():
            p = src / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding='utf-8')
        probe = src / 'probe/Probe.kt'
        probe.parent.mkdir(parents=True, exist_ok=True)
        probe.write_text(PROBE, encoding='utf-8')
        actual = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst'
        out = td / 'out.jar'
        cmd = [
            kotlinc,
            str(src),
            str(actual / 'TtsGoldenBaseline.kt'),
            str(actual / 'TtsArtifactVerifier.kt'),
            str(actual / 'LegacyTtsRuntime.kt'),
            '-d', str(out),
        ]
        cp = subprocess.run(cmd, text=True, capture_output=True)
        if cp.returncode:
            print(cp.stdout)
            print(cp.stderr)
            raise SystemExit(cp.returncode)
        rp = subprocess.run([kotlin, '-classpath', str(out), 'probe.ProbeKt'], text=True, capture_output=True)
        print(rp.stdout, end='')
        if rp.returncode:
            print(rp.stderr)
            raise SystemExit(rp.returncode)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
