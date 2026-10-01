package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import android.content.ContextWrapper
import android.net.Uri
import android.os.SystemClock
import android.system.Os
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.catkiss.senlive2dcompanion.CaicaiModelRepository
import com.aicompanion.localfirst.PortableCompanionState
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@RunWith(AndroidJUnit4::class)
class NativeSmokeTest {
    @Test fun preferencesOnlySnapshotPreservesExternalModelFilesAndIndexOnCommitAndRollback() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val repository = CaicaiModelRepository(context)
        val modelPrefs = context.getSharedPreferences("caicai_live2d", Context.MODE_PRIVATE)
        val stagePrefs = context.getSharedPreferences("caicai_stage", Context.MODE_PRIVATE)
        val root = java.io.File(context.filesDir, "caicai-live2d")
        root.deleteRecursively()
        val external = java.io.File(root, "current/external-model.bin")
        external.parentFile!!.mkdirs()
        external.writeText("EXTERNAL_RESOURCE_KEEP")
        modelPrefs.edit().clear().putString("maid", "external.model3.json").commit()
        stagePrefs.edit().clear().putFloat("legPivot", .87f).commit()
        val indexBefore = modelPrefs.all.toMap()
        var releases = 0
        try {
            for (commit in listOf(true, false)) {
                val portable = PortableCompanionState(context, repository) { releases++ }
                val before = releases
                val snapshot = portable.begin()
                assertEquals("Read-only snapshot does not release the model", before, releases)
                val lease = snapshot["token"] as String
                portable.apply(lease, mapOf("caicai_stage" to mapOf("legPivot" to .96f),
                    "overlay_state" to emptyMap<String, Any>(),
                    "companion_runtime" to emptyMap<String, Any>()), restoreModels = false)
                portable.finish(lease, commit)
                assertEquals(before + 1, releases)
                assertEquals(indexBefore, modelPrefs.all)
                assertEquals("EXTERNAL_RESOURCE_KEEP", external.readText())
                assertEquals(if (commit) .96f else .87f, stagePrefs.getFloat("legPivot", 0f), .001f)
                stagePrefs.edit().putFloat("legPivot", .87f).commit()
            }
        } finally {
            root.deleteRecursively(); modelPrefs.edit().clear().commit(); stagePrefs.edit().clear().commit()
        }
    }
    @Test fun nativeConstructorDrawPauseResumeAndReplacement() {
        repeat(4) {
            ActivityScenario.launch(SmokeActivity::class.java).use { scenario ->
                lateinit var activity: SmokeActivity
                scenario.onActivity { activity = it }
                fun frames() = activity.view.surfaceDiagnostics().substringAfter("frames=").substringBefore(" ").toLong()
                fun awaitFrames(previous: Long) {
                    val deadline = SystemClock.uptimeMillis() + 10000
                    while (frames() <= previous && activity.error == null && SystemClock.uptimeMillis() < deadline) {
                        SystemClock.sleep(50)
                    }
                    assertNull("Native renderer error", activity.error)
                    assertTrue(activity.view.surfaceDiagnostics(), frames() > previous)
                    assertTrue(activity.status, activity.status.contains("OpenGL"))
                }
                awaitFrames(0)
                scenario.moveToState(Lifecycle.State.CREATED)
                val pausedFrames = frames()
                scenario.moveToState(Lifecycle.State.RESUMED)
                awaitFrames(pausedFrames)
                val beforeReparent = frames()
                scenario.onActivity { it.reparentView() }
                awaitFrames(beforeReparent)
                // Release a paused owner too: GLSurfaceView must drain teardown
                // before detach or the next owner will wait forever on Cubism.
                scenario.onActivity { it.view.onHostPause(); it.replaceView() }
                awaitFrames(0)
                scenario.onActivity { it.detachThenReplaceView() }
                awaitFrames(0)
            }
        }
    }

    @Test fun resizeRetainsContextAndTracksActualBuffer() {
        ActivityScenario.launch(SmokeActivity::class.java).use { scenario ->
            lateinit var activity: SmokeActivity
            scenario.onActivity { activity=it }
            fun awaitSize(height:Int) {
                val deadline=SystemClock.uptimeMillis()+10000
                while((activity.view.renderSize().substringAfter("x").toInt()!=height ||
                    !activity.view.surfaceDiagnostics().contains("frames=")) && SystemClock.uptimeMillis()<deadline) SystemClock.sleep(30)
                assertNull(activity.error)
                assertEquals(height,activity.view.renderSize().substringAfter("x").toInt())
            }
            scenario.onActivity { it.resizeView(800) }; awaitSize(800)
            val contexts=activity.view.surfaceDiagnostics().substringAfter("contexts=").substringBefore(" ")
            for(height in listOf(560,320,560,800)) {
                scenario.onActivity { it.resizeView(height) }; awaitSize(height)
                assertEquals(contexts,activity.view.surfaceDiagnostics().substringAfter("contexts=").substringBefore(" "))
            }
        }
    }

    @Test fun importThroughAliasPromotionRecoveryRollbackAndReimport() {
        val base = ApplicationProvider.getApplicationContext<Context>()
        val actual = File(base.cacheDir, "import-real").apply { mkdirs() }
        val alias = File(base.cacheDir, "import-alias")
        alias.delete()
        Os.symlink(actual.path, alias.path)
        val context = object : ContextWrapper(base) {
            override fun getApplicationContext(): Context = this
            override fun getFilesDir(): File = alias
        }
        val repository = CaicaiModelRepository(context)
        repository.clearImportedModels()
        try {
            val first = fixture(base, "first")
            assertTrue(repository.importZip(Uri.fromFile(first)).available)
            assertTrue(repository.isPending())
            val reopened = CaicaiModelRepository(context)
            assertTrue(reopened.currentModels().available)
            assertFalse(reopened.currentModels().maid!!.path.contains("staging"))
            reopened.confirmPendingImport()
            val original = reopened.currentModels().maid!!.readText()
            val broken = File(base.cacheDir, "broken.zip").apply { writeText("broken") }
            assertTrue(runCatching { reopened.importZip(Uri.fromFile(broken)) }.isFailure)
            assertEquals(original, reopened.currentModels().maid!!.readText())
            assertTrue(reopened.importZip(Uri.fromFile(fixture(base, "second"))).available)
            assertTrue(reopened.rollbackPendingImport())
            assertEquals(original, reopened.currentModels().maid!!.readText())
            base.getSharedPreferences("caicai_live2d", 0).edit()
                .putString("maid", "../staging/old").putString("accessory", "../staging/old").commit()
            assertTrue(CaicaiModelRepository(context).currentModels().available)
            assertFalse(base.getSharedPreferences("caicai_live2d", 0).getString("maid", "")!!.contains(".."))
            reopened.clearImportedModels()
            assertFalse(reopened.currentModels().available)
            assertTrue(reopened.importZip(Uri.fromFile(first)).available)
        } finally {
            repository.clearImportedModels()
            alias.delete()
            actual.deleteRecursively()
        }
    }

    @Test fun portableModelLeaseValidationAndIndexReconstruction() {
        val base = ApplicationProvider.getApplicationContext<Context>()
        val folder = File(base.cacheDir, "portable-fixture").apply { mkdirs() }
        val context = object : ContextWrapper(base) {
            override fun getApplicationContext(): Context = this
            override fun getFilesDir(): File = folder
        }
        val repository = CaicaiModelRepository(context)
        repository.clearImportedModels()
        var token: String? = null
        try {
            repository.importZip(Uri.fromFile(fixture(base, "portable")))
            assertTrue(runCatching { repository.beginPortableSnapshot() }.isFailure)
            repository.confirmPendingImport()
            val lease = repository.beginPortableSnapshot()
            token = lease
            val current = repository.portableDirectory(lease)
            assertTrue(repository.validatePortableDirectory(current).available)
            assertTrue(runCatching { repository.importZip(Uri.fromFile(fixture(base, "blocked"))) }.isFailure)
            assertTrue(runCatching { repository.clearImportedModels() }.isFailure)
            base.getSharedPreferences("caicai_live2d",0).edit().clear().commit()
            repository.installPortableIndex(lease)
            assertTrue(repository.currentModels().available)
            assertFalse(repository.isPending())
            val moc = current.walkTopDown().first { it.name == "model.moc3" }
            val saved = moc.readBytes(); moc.delete()
            assertTrue(runCatching { repository.validatePortableDirectory(current) }.isFailure)
            assertEquals(current, repository.portableDirectory(lease, validateInstalled = false))
            assertTrue(runCatching { repository.portableDirectory(lease, validateInstalled = true) }.isFailure)
            moc.writeBytes(saved)
            repository.finishPortableInstall(lease)
        } finally {
            token?.let { repository.endPortableSnapshot(it) }
            repository.clearImportedModels(); folder.deleteRecursively()
        }
    }

    // Structural import fixture only; fake moc/texture bytes are never rendered.
    private fun fixture(context: Context, marker: String): File {
        val file = File(context.cacheDir, "$marker.zip")
        ZipOutputStream(file.outputStream()).use { zip ->
            fun entry(name: String, text: String) {
                zip.putNextEntry(ZipEntry("嵌套/$name")); zip.write(text.toByteArray()); zip.closeEntry()
            }
            entry("accessory-lab.json", """{"mainModel":"女仆/model.model3.json","accessoryModel":"配件/model.model3.json"}""")
            for ((folder, count) in listOf("女仆" to 1, "配件" to 26)) {
                val textures = JSONArray((0 until count).map { "texture-$it.png" })
                entry("$folder/model.model3.json", JSONObject().put("marker", marker).put("FileReferences",
                    JSONObject().put("Moc", "model.moc3").put("Textures", textures)).toString())
                entry("$folder/model.moc3", marker)
                for (i in if (count == 1) listOf(0) else listOf(6, 16, 19)) entry("$folder/texture-$i.png", marker)
            }
        }
        return file
    }
}
