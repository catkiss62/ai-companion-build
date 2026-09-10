package com.aicompanion.localfirst

import android.content.Context
import android.util.AtomicFile
import com.catkiss62.geniettsbenchmark.GenieBenchmarkEngine
import java.io.File

/**
 * Makes the first companion run use a complete Naiyou V2 runtime extraction.
 *
 * The pinned Genie test app always starts with a fresh filesDir. Companion
 * upgrades do not: v0.41.53/v0.41.54 may have left a non-empty partial model
 * or frontend file behind, and Genie's original copier intentionally skips any
 * non-empty destination. Purge only that reproducible version directory once,
 * then let the byte-for-byte pinned core extract it again. The imported
 * Chinese RoBERTa lives in the sibling shared/ directory and is preserved.
 */
object GenieRuntimeAssetStore {
    private const val MIGRATION_ID = "ai-companion-v04157-build201-naiyou-runtime-v1"

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
            progress("正在刷新 Genie 奶油 V2 运行资源……")
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
