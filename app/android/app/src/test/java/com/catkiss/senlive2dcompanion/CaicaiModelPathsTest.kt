package com.catkiss.senlive2dcompanion

import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.file.Files

class CaicaiModelPathsTest {
    @Test fun canonicalAliasSurvivesPromotionAndIndexRecovery() {
        val temp = Files.createTempDirectory("caicai-path-test").toFile()
        try {
            val actual = File(temp, "actual").apply { mkdir() }
            val alias = File(temp, "alias")
            Files.createSymbolicLink(alias.toPath(), actual.toPath())
            val staging = File(alias, "staging").apply { mkdir() }
            val maid = File(staging, "嵌套/女仆.model3.json").apply { parentFile.mkdirs(); writeText("{}") }.canonicalFile
            val relative = CaicaiModelPaths.relative(staging, maid)
            assertEquals("嵌套/女仆.model3.json", relative)
            val current = File(alias, "current")
            assertTrue(staging.renameTo(current))
            val readback = CaicaiModelPaths.child(current, relative)!!
            assertTrue(readback.isFile)
            assertEquals(relative, CaicaiModelPaths.relative(current, readback))
            val backup = File(alias, "backup")
            assertTrue(current.renameTo(backup))
            assertTrue(CaicaiModelPaths.child(backup, relative)!!.isFile)
            assertTrue(backup.renameTo(current))
            assertTrue(CaicaiModelPaths.child(current, relative)!!.isFile)
        } finally { temp.deleteRecursively() }
    }

    @Test fun escapeAndAbsolutePathsRemainRejected() {
        val root = Files.createTempDirectory("caicai-root").toFile()
        try {
            assertNull(CaicaiModelPaths.child(root, "../outside"))
            assertNull(CaicaiModelPaths.child(root, "/absolute"))
            assertNull(CaicaiModelPaths.child(root, ""))
        } finally { root.deleteRecursively() }
    }
}
