package com.aicompanion.localfirst

import java.io.File

/** Restricts the read-only snapshot to the private directory owned by this viewer. */
internal object MemoryGalaxyFiles {
    private val snapshotName = Regex("galaxy-[0-9]+-[A-Za-z0-9_-]+\\.json")
    private val assetName = Regex("[A-Za-z0-9_./-]+")

    fun snapshot(cacheDirectory: File, suppliedPath: String?): File {
        require(!suppliedPath.isNullOrBlank()) { "Missing memory snapshot" }
        val supplied = File(suppliedPath)
        require(supplied.isAbsolute) { "Snapshot path must be absolute" }
        val cache = cacheDirectory.canonicalFile
        val expectedDirectory = File(cache, "memory_galaxy")
        require(expectedDirectory.canonicalFile == expectedDirectory) {
            "Snapshot directory must remain in the private cache"
        }
        val snapshot = supplied.canonicalFile
        require(snapshot.parentFile == expectedDirectory && snapshotName.matches(snapshot.name)) {
            "Snapshot is outside the memory viewer cache"
        }
        require(snapshot.isFile && snapshot.length() > 0) { "Memory snapshot is unavailable" }
        return snapshot
    }

    /** A decoded WebView path must never escape the bundled asset directory. */
    fun assetPath(decodedPath: String?): String? {
        if (decodedPath == null || !decodedPath.startsWith('/')) return null
        val relative = decodedPath.substring(1)
        if (relative.isEmpty() || !assetName.matches(relative)) return null
        if (relative.split('/').any { it.isEmpty() || it == "." || it == ".." }) return null
        return relative
    }
}
