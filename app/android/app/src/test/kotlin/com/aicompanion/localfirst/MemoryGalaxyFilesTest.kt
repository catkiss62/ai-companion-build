package com.aicompanion.localfirst

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class MemoryGalaxyFilesTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test
    fun acceptsOnlyNonemptyNamedSnapshotsInsideItsPrivateDirectory() {
        val cache = temporary.newFolder("cache")
        val directory = File(cache, "memory_galaxy").apply { mkdir() }
        val data = File(directory, "galaxy-123-abc_456.json").apply { writeText("{\"stars\":[]}") }
        assertEquals(data.canonicalFile, MemoryGalaxyFiles.snapshot(cache, data.path))
        assertEquals("{\"stars\":[]}", data.readText())
        assertRejected { MemoryGalaxyFiles.snapshot(cache, null) }
        assertRejected { MemoryGalaxyFiles.snapshot(cache, "memory_galaxy/${data.name}") }
        assertRejected { MemoryGalaxyFiles.snapshot(cache, File(directory, "other.json").apply { writeText("{}") }.path) }
        assertRejected { MemoryGalaxyFiles.snapshot(cache, File(directory, "galaxy-123-empty.json").apply { createNewFile() }.path) }
        assertRejected { MemoryGalaxyFiles.snapshot(cache, File(directory, "galaxy-123-directory.json").apply { mkdir() }.path) }
    }

    @Test
    fun rejectsOtherCachesAndDirectoryOrFileSymlinksEscapingTheViewer() {
        val cache = temporary.newFolder("cache")
        val outside = temporary.newFolder("outside")
        val outsideData = File(outside, "galaxy-1-other.json").apply { writeText("{}") }
        assertRejected { MemoryGalaxyFiles.snapshot(cache, outsideData.path) }
        val directory = File(cache, "memory_galaxy")
        Files.createSymbolicLink(directory.toPath(), outside.toPath())
        assertRejected { MemoryGalaxyFiles.snapshot(cache, File(directory, outsideData.name).path) }
        assertTrue(directory.delete())
        assertTrue(directory.mkdir())
        val link = File(directory, "galaxy-1-linked.json")
        Files.createSymbolicLink(link.toPath(), outsideData.toPath())
        assertRejected { MemoryGalaxyFiles.snapshot(cache, link.path) }
        assertEquals("{}", outsideData.readText())
    }

    @Test
    fun localAssetPathsExcludeTraversalAndDecodedEncodedEscapes() {
        assertEquals("index.html", MemoryGalaxyFiles.assetPath("/index.html"))
        assertEquals("vendor/three/three.module.js", MemoryGalaxyFiles.assetPath("/vendor/three/three.module.js"))
        assertEquals("fonts/noto-serif-sc.ttf", MemoryGalaxyFiles.assetPath("/fonts/noto-serif-sc.ttf"))
        listOf(null, "index.html", "/", "//index.html", "/../memory.json", "/vendor/./secret", "/vendor/../../secret", "/vendor/%2e%2e/secret", "/vendor/secret?x=1", "/vendor\\secret").forEach {
            assertNull(it, MemoryGalaxyFiles.assetPath(it))
        }
    }

    private fun assertRejected(block: () -> Unit) {
        try {
            block()
            throw AssertionError("Expected a rejected snapshot")
        } catch (_: IllegalArgumentException) {
            // Expected: validation performs no mutation or deletion.
        }
    }
}
