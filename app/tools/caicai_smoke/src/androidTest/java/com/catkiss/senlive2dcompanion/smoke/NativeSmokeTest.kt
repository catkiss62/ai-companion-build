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
import com.catkiss.senlive2dcompanion.CaicaiStagePreferences
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
    @Test fun settingsRestoreHotAppliesToTheSameRendererAndRestoresMissingKeyDefaults() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val prefs = context.getSharedPreferences("caicai_stage", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        try {
            ActivityScenario.launch(SmokeActivity::class.java).use { scenario ->
                lateinit var activity: SmokeActivity
                scenario.onActivity { activity = it }
                val original = activity.view
                fun frames() = original.surfaceDiagnostics().substringAfter("frames=").substringBefore(" ").toLong()
                val deadline = SystemClock.uptimeMillis() + 10000
                while (frames() == 0L && activity.error == null && SystemClock.uptimeMillis() < deadline) SystemClock.sleep(30)
                assertNull(activity.error)
                assertTrue(original.surfaceDiagnostics(), frames() > 0L)
                val contexts = original.surfaceDiagnostics().substringAfter("contexts=").substringBefore(" ")
                var releases = 0
                var refreshes = 0
                val portable = PortableCompanionState(context, CaicaiModelRepository(context), refreshPreferences = {
                    refreshes++
                    CaicaiStagePreferences.read(prefs).applyTo(original)
                }) { releases++ }
                fun restore(stage: Map<String, Any>, commit: Boolean) {
                    scenario.onActivity {
                        val lease = portable.begin()["token"] as String
                        val before = refreshes
                        portable.apply(lease, mapOf("caicai_stage" to stage,
                            "overlay_state" to emptyMap<String, Any>(), "companion_runtime" to emptyMap<String, Any>()), false)
                        assertEquals(before, refreshes)
                        portable.finish(lease, commit)
                        assertEquals(before + 1, refreshes)
                    }
                    val drained = java.util.concurrent.CountDownLatch(1)
                    original.queueEvent { drained.countDown() }
                    assertTrue("Renderer update drained", drained.await(5, java.util.concurrent.TimeUnit.SECONDS))
                    assertSame(original, activity.view)
                    assertEquals(contexts, original.surfaceDiagnostics().substringAfter("contexts=").substringBefore(" "))
                    assertEquals(0, releases)
                    assertFalse(portable.busy)
                }
                val values = mapOf<String, Any>("motionGain" to 1.25f, "motionSpeed" to 1.4f, "legPivot" to .94f,
                    "scale" to 2f, "x" to .4f, "y" to -.6f,
                    "headLeft" to .1f, "headTop" to .2f, "headRight" to .8f, "headBottom" to .9f,
                    "rightEarX" to .2f, "rightEarY" to -.3f, "rightEarRotation" to 12f)
                restore(values, true)
                assertArrayEquals(floatArrayOf(.1f, .2f, .8f, .9f), CaicaiStagePreferences.read(prefs).headBox(), .001f)
                val rendererField = original.javaClass.getDeclaredField("renderer").apply { isAccessible = true }
                val renderer = rendererField.get(original)
                fun rendererValue(name: String): Float = renderer.javaClass.getDeclaredField(name).apply { isAccessible = true }.getFloat(renderer)
                fun checkRenderer(gain: Float, speed: Float, pivot: Float, scale: Float, x: Float, y: Float) {
                    for ((name, expected) in mapOf("motionGain" to gain, "motionSpeed" to speed, "lowerLegPivot" to pivot,
                        "stageScale" to scale, "stageTranslateX" to x, "stageTranslateY" to y))
                        assertEquals(name, expected, rendererValue(name), .001f)
                }
                checkRenderer(1.25f, 1.4f, .94f, 2f, .4f, -.6f)
                assertEquals(.2f,rendererValue("rightEarAdjustX"),.001f)
                assertEquals(-.3f,rendererValue("rightEarAdjustY"),.001f)
                assertEquals(12f,rendererValue("rightEarAdjustRotation"),.001f)
                restore(mapOf("scale" to .5f), false)
                checkRenderer(1.25f, 1.4f, .94f, 2f, .4f, -.6f)
                assertEquals(.2f,rendererValue("rightEarAdjustX"),.001f)
                assertEquals(-.3f,rendererValue("rightEarAdjustY"),.001f)
                assertEquals(12f,rendererValue("rightEarAdjustRotation"),.001f)
                restore(emptyMap(), true)
                checkRenderer(1f, 1f, .88f, 1f, 0f, 0f)
                assertEquals(0f,rendererValue("rightEarAdjustX"),.001f)
                assertEquals(0f,rendererValue("rightEarAdjustY"),.001f)
                assertEquals(0f,rendererValue("rightEarAdjustRotation"),.001f)
                assertArrayEquals(floatArrayOf(.27f, .02f, .73f, .32f), CaicaiStagePreferences.read(prefs).headBox(), .001f)
                scenario.onActivity {
                    val before = refreshes
                    portable.finish(portable.begin()["token"] as String, true)
                    assertEquals("Export does not refresh", before, refreshes)
                }
            }
        } finally { prefs.edit().clear().commit() }
    }

    @Test fun settingsRefreshFailureKeepsErrorAndReleasesSnapshotLease() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val failure = java.io.IOException("refresh failed")
        var releases = 0
        val portable = PortableCompanionState(context, CaicaiModelRepository(context), refreshPreferences = { throw failure }) { releases++ }
        val lease = portable.begin()["token"] as String
        portable.apply(lease, mapOf("caicai_stage" to emptyMap<String, Any>(),
            "overlay_state" to emptyMap<String, Any>(), "companion_runtime" to emptyMap<String, Any>()), false)
        assertSame(failure, runCatching { portable.finish(lease, false) }.exceptionOrNull())
        assertEquals(0, releases)
        assertFalse(portable.busy)
        portable.finish(portable.begin()["token"] as String, true)
    }

    @Test fun durablePreferenceRecoveryPreservesTypesAndSettingsOnlyModelIdentity() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val stage = context.getSharedPreferences("caicai_stage", Context.MODE_PRIVATE)
        val index = context.getSharedPreferences("caicai_live2d", Context.MODE_PRIVATE)
        stage.edit().clear().putFloat("legPivot", .87f).commit()
        index.edit().clear().putString("maid", "external.model3.json").putInt("fixtureInt", 3)
            .putLong("fixtureLong", 922337203685477L).putFloat("fixtureFloat", .5f)
            .putBoolean("fixtureBool", true).putStringSet("fixtureSet", setOf("a", "b")).commit()
        var releases = 0
        var refreshes = 0
        val state = PortableCompanionState(context, CaicaiModelRepository(context),
            refreshPreferences = { refreshes++ }, releaseModel = { releases++ })
        val before = index.all.toMap()
        try {
            val snapshot = state.begin()
            state.apply(snapshot["token"] as String,
                mapOf("caicai_stage" to mapOf("legPivot" to .96),
                    "overlay_state" to emptyMap<String, Any>(),
                    "companion_runtime" to emptyMap<String, Any>()), false)
            state.finish(snapshot["token"] as String, true)
            PortableCompanionState.recover(context,
                snapshot["preferences"] as Map<*, *>, snapshot["recoveryState"] as Map<*, *>,
                false, false, releaseModel = { releases++ }, refreshPreferences = { refreshes++ })
            assertEquals(.87f, stage.getFloat("legPivot", 0f), .0001f)
            assertEquals(before, index.all)
            assertEquals(0, releases)
            assertEquals(2, refreshes)
            index.edit().clear().commit()
            PortableCompanionState.recover(context,
                snapshot["preferences"] as Map<*, *>, snapshot["recoveryState"] as Map<*, *>,
                true, false, releaseModel = { releases++ })
            assertEquals(before, index.all)
            assertEquals(1, releases)
        } finally { state.dispose(); stage.edit().clear().commit(); index.edit().clear().commit() }
    }

    @Test fun legacyModelRestoreStillReleasesAndRestoresIndexWithoutHotRefresh() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val repository = CaicaiModelRepository(context)
        repository.clearImportedModels()
        var releases = 0
        var refreshes = 0
        try {
            repository.importZip(Uri.fromFile(fixture(context, "legacy-portable")))
            repository.confirmPendingImport()
            val prefs = context.getSharedPreferences("caicai_live2d", Context.MODE_PRIVATE)
            val previous = prefs.all.toMap()
            val portable = PortableCompanionState(context, repository, refreshPreferences = { refreshes++ }) { releases++ }
            for (commit in listOf(true, false)) {
                val snapshot = portable.begin()
                portable.apply(snapshot["token"] as String, snapshot["preferences"] as Map<*, *>, true)
                portable.finish(snapshot["token"] as String, commit)
                if (!commit) assertEquals(previous, prefs.all)
                assertTrue(repository.currentModels().available)
                assertEquals(0, refreshes)
            }
            assertEquals(2, releases)
        } finally { repository.clearImportedModels() }
    }

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
        var refreshes = 0
        try {
            for (commit in listOf(true, false)) {
                val portable = PortableCompanionState(context, repository, refreshPreferences = {
                    refreshes++
                    assertEquals(if (commit) .96f else .87f, stagePrefs.getFloat("legPivot", 0f), .001f)
                }) { releases++ }
                val before = releases
                val beforeRefresh = refreshes
                val snapshot = portable.begin()
                assertEquals("Read-only snapshot does not release the model", before, releases)
                val lease = snapshot["token"] as String
                portable.apply(lease, mapOf("caicai_stage" to mapOf("legPivot" to .96f),
                    "overlay_state" to emptyMap<String, Any>(),
                    "companion_runtime" to emptyMap<String, Any>()), restoreModels = false)
                assertEquals("Temporary preferences do not touch the live stage", beforeRefresh, refreshes)
                portable.finish(lease, commit)
                assertEquals("Settings restore keeps the model", before, releases)
                assertEquals(beforeRefresh + 1, refreshes)
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
