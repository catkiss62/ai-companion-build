package com.aicompanion.localfirst

import android.content.Context
import java.io.File
import java.io.InputStream
import java.security.MessageDigest

internal data class TtsIntegrityResult(
    val state: String,
    val ok: Boolean,
    val checked: Int,
    val detail: String,
)

/**
 * Verifies the packaged local-TTS payload against the user-validated upgraded
 * Chinese Meju runtime fingerprints before JNI/model initialization.
 *
 * The expensive full scan is cached for the process lifetime. `force=true` is
 * reserved for the explicit Settings -> 检查 TTS action.
 */
internal class TtsArtifactVerifier(context: Context) {
    private val appContext = context.applicationContext

    @Volatile
    private var cached: TtsIntegrityResult? = null

    fun quickArtifactsPresent(): Boolean = runCatching {
        TtsGoldenBaseline.assets.keys.all { path ->
            // Two valid houbb-pinyin definition resources are intentionally
            // zero bytes. Successfully opening the asset is the presence test;
            // the full verifier below owns its exact size/hash check.
            appContext.assets.open(path).use { true }
        } && TtsGoldenBaseline.nativeLibraries.keys.all { name ->
            File(appContext.applicationInfo.nativeLibraryDir, name).isFile
        }
    }.getOrDefault(false)

    fun currentResult(): TtsIntegrityResult = cached ?: TtsIntegrityResult(
        state = "unchecked",
        ok = false,
        checked = 0,
        detail = "尚未执行 TTS 资源校验",
    )

    @Synchronized
    fun verify(force: Boolean = false): TtsIntegrityResult {
        if (!force) cached?.let { return it }

        val failures = mutableListOf<String>()
        var checked = 0
        for ((path, expected) in TtsGoldenBaseline.assets) {
            val actual = try {
                appContext.assets.open(path).use { input -> sha256AndSize(input) }
            } catch (t: Throwable) {
                failures += "$path: missing/unreadable (${t.javaClass.simpleName})"
                null
            }
            if (actual == null) continue
            checked++
            if (actual.first != expected.sha256 || actual.second != expected.size) {
                failures += "$path: fingerprint mismatch"
            }
        }

        val nativeDir = File(appContext.applicationInfo.nativeLibraryDir)
        for ((name, expected) in TtsGoldenBaseline.nativeLibraries) {
            val file = File(nativeDir, name)
            if (!file.isFile) {
                failures += "$name: native library missing"
                continue
            }
            val digest = try {
                sha256(file)
            } catch (t: Throwable) {
                failures += "$name: unreadable (${t.javaClass.simpleName})"
                null
            }
            if (digest == null) continue
            checked++
            if (file.length() != expected.size || digest != expected.sha256) {
                failures += "$name: fingerprint mismatch"
            }
        }

        val result = if (failures.isEmpty() && checked == TtsGoldenBaseline.TOTAL_ARTIFACTS) {
            TtsIntegrityResult(
                state = "verified",
                ok = true,
                checked = checked,
                detail = "TTS 资源校验通过：$checked/${TtsGoldenBaseline.TOTAL_ARTIFACTS} · ${TtsGoldenBaseline.GOLDEN_REFERENCE}",
            )
        } else {
            val preview = failures.take(3).joinToString("; ")
            TtsIntegrityResult(
                state = "failed",
                ok = false,
                checked = checked,
                detail = "TTS 资源校验失败：$preview",
            )
        }
        cached = result
        return result
    }

    private fun sha256AndSize(input: InputStream): Pair<String, Long> {
        val md = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            if (read > 0) {
                md.update(buffer, 0, read)
                total += read
            }
        }
        val digest = md.digest().joinToString("") { "%02x".format(it) }
        return digest to total
    }

    companion object {
        fun sha256(file: File): String = file.inputStream().use { input ->
            val md = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                if (read > 0) md.update(buffer, 0, read)
            }
            md.digest().joinToString("") { "%02x".format(it) }
        }
    }
}
