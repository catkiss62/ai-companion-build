package com.aicompanion.localfirst

import android.content.Context
import android.util.AtomicFile
import com.catkiss62.geniettsbenchmark.GenieBenchmarkEngine
import java.io.File

/**
 * Makes the first companion run use a complete, verified Tiandou extraction.
 *
 * The pinned Genie test app always starts with a fresh filesDir. Companion
 * upgrades do not: older packages may have left mixed voice files or a
 * non-empty partial model behind. Purge only that reproducible version
 * directory once, then let the integrity-aware copier extract Tiandou again.
 * The imported Chinese RoBERTa lives in sibling shared/ and is preserved.
 */
object GenieRuntimeAssetStore {
    private const val MIGRATION_ID = "ai-companion-v04159-build203-tiandou-integrity-v1"

    fun prepare(
        context: Context,
        engine: GenieBenchmarkEngine,
        progress: (String) -> Unit = {},
    ): File {
        val manifest = engine.readManifest()
        val base = File(context.filesDir, "genie-benchmark")
        val root = File(base, manifest.version)
        val marker = AtomicFile(File(base, ".$MIGRATION_ID.ready"))

        if (!marker.baseFile.isFile) {
            val canonicalBase = base.canonicalFile
            val canonicalRoot = root.canonicalFile
            check(canonicalRoot.parentFile == canonicalBase) {
                "拒绝清理非 Genie 运行目录"
            }
            progress("正在校验并刷新 Genie 恬豆运行资源……")
            if (canonicalRoot.exists()) {
                check(canonicalRoot.deleteRecursively()) {
                    "无法清理旧 Genie 运行资源"
                }
            }
            val prepared = engine.prepareAssets(progress)
            // Complete this small frontend extraction before marking the
            // migration ready, so a killed copy is retried from a clean root.
            engine.prepareFrontendAssets(prepared, progress)
            writeMarker(marker, manifest.version)
            return prepared
        }
        return engine.prepareAssets(progress)
    }

    private fun writeMarker(marker: AtomicFile, version: String) {
        marker.baseFile.parentFile?.mkdirs()
        val output = marker.startWrite()
        try {
            output.write("$MIGRATION_ID\n$version\n".toByteArray(Charsets.UTF_8))
            marker.finishWrite(output)
        } catch (error: Throwable) {
            marker.failWrite(output)
            throw error
        }
    }
}
