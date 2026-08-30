package com.aicompanion.localfirst

import android.content.Context
import java.io.File

object SnapshotCacheCleaner {
    private const val STALE_AFTER_MS = 24L * 60L * 60L * 1000L
    private val prefixes = listOf(
        "companion_snapshot_work_",
        "companion_import_",
        "ai_companion_received_",
        "ai_companion_manual_",
        "ai_companion_backup_",
        "ai_companion_20",
    )

    fun clean(
        context: Context,
        nowMs: Long = System.currentTimeMillis(),
        activePaths: Set<String> = emptySet(),
    ): Int {
        val cache = context.cacheDir.canonicalFile
        val protected = activePaths.mapNotNull { path ->
            runCatching { File(path).canonicalPath }.getOrNull()
        }.toSet()
        var removed = 0
        cache.listFiles()?.forEach { entry ->
            if (prefixes.none { prefix -> entry.name.startsWith(prefix) }) return@forEach
            val canonical = runCatching { entry.canonicalFile }.getOrNull() ?: return@forEach
            if (canonical.parentFile != cache || canonical.path in protected) return@forEach
            val age = nowMs - canonical.lastModified()
            if (age < STALE_AFTER_MS) return@forEach
            if (runCatching { canonical.deleteRecursively() }.getOrDefault(false)) removed += 1
        }
        return removed
    }
}
