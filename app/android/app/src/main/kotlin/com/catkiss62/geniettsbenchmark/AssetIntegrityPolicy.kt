package com.catkiss62.geniettsbenchmark

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest

internal object AssetIntegrityPolicy {
    fun canReuse(output: File, marker: File, expected: AssetIntegrity?): Boolean {
        val validLength = output.isFile && output.length() > 0L &&
            (expected == null || output.length() == expected.bytes)
        if (!validLength) return false
        if (expected == null) return true
        if (marker.isFile && marker.readText().trim().equals(expected.sha256, ignoreCase = true)) {
            return true
        }
        if (!sha256(output).equals(expected.sha256, ignoreCase = true)) return false
        marker.parentFile?.mkdirs()
        marker.writeText(expected.sha256)
        return true
    }

    fun verifyIncoming(
        incoming: File,
        relative: String,
        expected: AssetIntegrity?,
        actualSha: String = sha256(incoming),
    ) {
        check(incoming.length() > 0L) { "资源释放为空：$relative" }
        if (expected == null) return
        check(incoming.length() == expected.bytes) {
            "资源大小不完整：$relative · ${incoming.length()} / ${expected.bytes}"
        }
        check(actualSha.equals(expected.sha256, ignoreCase = true)) {
            "资源 SHA-256 不匹配：$relative"
        }
    }

    fun replaceIncoming(incoming: File, output: File) {
        try {
            Files.move(
                incoming.toPath(), output.toPath(),
                StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE,
            )
        } catch (_: Throwable) {
            Files.move(incoming.toPath(), output.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(1024 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
