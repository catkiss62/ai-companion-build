package com.aicompanion.localfirst

import com.catkiss62.geniettsbenchmark.GenieBenchmarkEngine
import java.io.File
import java.security.MessageDigest

/** Companion-only I/O and pronunciation policy kept outside the pinned Genie core. */
object GenieFrontendAdapter {
    // The final syllable of 拖肯 and the second/fourth syllables of 地铺西咳
    // use the verified Genie neutral-tone phone IDs.
    private val hotwordPhones = linkedMapOf(
        "拖肯" to "252,290|222,144",
        "地铺西咳" to "127,169|245,259|317,166|222,134",
    )

    fun prepareChineseAssets(engine: GenieBenchmarkEngine, root: File, progress: (String) -> Unit) {
        engine.prepareFrontendAssets(root, progress)
        val relative = engine.readManifest().frontend.phrasePhones
        val target = File(root, relative)
        val retained = target.readLines().filterNot { line ->
            hotwordPhones.keys.any { key -> line.startsWith("$key\t") }
        }
        target.writeText(
            buildString {
                retained.forEach { appendLine(it) }
                hotwordPhones.forEach { (word, phones) -> appendLine("$word\t$phones") }
            },
        )
    }

    fun normalizeChineseText(text: String): String =
        // The pinned frontend expands Latin C to 西 before matching the
        // normalized 地铺西咳 phrase-phone override above.
        text.replace(Regex("DeepSeek", RegexOption.IGNORE_CASE), "地铺C咳")

    fun importRoberta(
        engine: GenieBenchmarkEngine,
        contextFilesDir: File,
        source: File,
        progress: (String) -> Unit,
    ) {
        val frontend = engine.readManifest().frontend
        val target = File(contextFilesDir, "genie-benchmark/shared/${File(frontend.roberta).name}")
        val incoming = File(target.parentFile, "${target.name}.incoming")
        target.parentFile?.mkdirs()
        incoming.delete()
        val digest = MessageDigest.getInstance("SHA-256")
        var copied = 0L
        try {
            source.inputStream().buffered().use { input ->
                incoming.outputStream().buffered().use { output ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                        copied += count
                        if (copied % (32L * 1024L * 1024L) < count) {
                            progress("正在导入 RoBERTa：${copied / 1024L / 1024L} MB")
                        }
                    }
                }
            }
            val sha = digest.digest().joinToString("") { "%02x".format(it) }
            check(copied == frontend.robertaBytes) {
                "模型大小不匹配：$copied / ${frontend.robertaBytes}"
            }
            check(sha.equals(frontend.robertaSha256, ignoreCase = true)) {
                "模型 SHA-256 不匹配，请选择配套的 v0.3.2 文件"
            }
            target.delete()
            check(incoming.renameTo(target)) { "无法保存 RoBERTa 模型" }
            File(target.parentFile, "${target.name}.sha256").writeText(sha)
        } catch (error: Throwable) {
            incoming.delete()
            throw error
        }
    }
}
