package com.catkiss.senlive2dcompanion

import android.content.Context
import android.net.Uri
import com.aicompanion.localfirst.PortableCompanionState
import java.io.File
import java.nio.charset.Charset
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class CaicaiProfileIsolationTest {
    private lateinit var context: Context
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        for (name in listOf("caicai_live2d","deepseek_live2d","caicai_stage","deepseek_stage",
            "deepseek_appearance","deepseek_motion","caicai_appearance",Live2DProfiles.REGISTRY))
            context.getSharedPreferences(name,0).edit().clear().commit()
        File(context.filesDir,"caicai-live2d").deleteRecursively()
        File(context.filesDir,"deepseek-live2d").deleteRecursively()
        Live2DProfiles.restored(context)
    }
    private fun deepseekZip(valid: Boolean = true): File {
        val file=File(context.cacheDir,"model.zip")
        val refs=JSONObject().put("Moc","模型.moc3").put("Textures",JSONArray()).put("DisplayInfo","模型.cdi3.json")
        val ids=if(valid) listOf("AngleX","PositionX","LeanInput","Clothes2","Movement1","Movement2","Movement3","key13") else listOf("unknown")
        val cdi=JSONObject().put("Parameters",JSONArray(ids.map { JSONObject().put("Id",it) }))
        ZipOutputStream(file.outputStream(),Charset.forName("GBK")).use { zip ->
            for((name,text) in mapOf("模型.model3.json" to JSONObject().put("Version",3).put("FileReferences",refs).toString(),
                "模型.moc3" to "synthetic-moc-not-rendered", "模型.cdi3.json" to cdi.toString())) {
                zip.putNextEntry(ZipEntry(name));zip.write(text.toByteArray());zip.closeEntry()
            }
        }
        return file
    }
    @Test fun gbkImportIsIndependentAndDeleteLeavesCaicaiFilesAndSettings() {
        val sentinel=File(context.filesDir,"caicai-live2d/current/sentinel").apply {parentFile!!.mkdirs();writeText("keep")}
        context.getSharedPreferences("caicai_stage",0).edit().putFloat("scale",2f).commit()
        val repo=CaicaiModelRepository(context,Live2DProfiles.DEEPSEEK)
        assertTrue(repo.importZip(Uri.fromFile(deepseekZip())).available)
        assertEquals("模型.model3.json",repo.currentModels().maid!!.name)
        assertTrue(repo.isPending());repo.confirmPendingImport();assertFalse(repo.isPending())
        repo.clearImportedModels()
        assertEquals("keep",sentinel.readText())
        assertEquals(2f,context.getSharedPreferences("caicai_stage",0).getFloat("scale",0f),0f)
    }
    @Test fun wrongFamilyDoesNotReplaceTheWorkingDeepseek() {
        val repo=CaicaiModelRepository(context,Live2DProfiles.DEEPSEEK)
        repo.importZip(Uri.fromFile(deepseekZip()));repo.confirmPendingImport()
        val before=repo.fingerprint()
        assertThrows(Exception::class.java) { repo.importZip(Uri.fromFile(deepseekZip(false))) }
        assertTrue(repo.currentModels().available);assertEquals(before,repo.fingerprint())
    }
    @Test fun lateReadyFromTheFirstCaicaiCannotCommitAfterAToBToA() {
        Live2DProfiles.request(context,Live2DProfiles.CAICAI)
        val first=Live2DProfiles.generation
        Live2DProfiles.request(context,Live2DProfiles.DEEPSEEK)
        Live2DProfiles.request(context,Live2DProfiles.CAICAI)
        assertFalse(Live2DProfiles.confirm(context,Live2DProfiles.CAICAI,first))
        assertTrue(Live2DProfiles.confirm(context,Live2DProfiles.CAICAI,Live2DProfiles.generation))
    }
    private fun oldPreferences() = mapOf("caicai_stage" to mapOf("scale" to 1.5),
        "overlay_state" to emptyMap<String,Any>(),"companion_runtime" to emptyMap<String,Any>())
    private fun prepareDeepseekSettings() {
        context.getSharedPreferences("deepseek_stage",0).edit().putFloat("scale",2f).putFloat("anchorY",.3f).commit()
        context.getSharedPreferences("deepseek_appearance",0).edit().putFloat("Clothes1",.5f).commit()
        Live2DProfiles.request(context,Live2DProfiles.DEEPSEEK)
        assertTrue(Live2DProfiles.confirm(context,Live2DProfiles.DEEPSEEK,Live2DProfiles.generation))
    }
    @Test fun oldSaveDoesNotClearDeepseekAndCanChangeSelectionWithoutReleasingResources() {
        prepareDeepseekSettings()
        var release=0;var refresh=0
        val portable=PortableCompanionState(context,CaicaiModelRepository(context),
            releaseModel={release++},refreshPreferences={refresh++})
        val token=portable.begin()["token"] as String
        portable.apply(token,oldPreferences(),restoreModels=false);portable.finish(token,true)
        assertEquals(0,release);assertEquals(1,refresh)
        assertEquals(2f,context.getSharedPreferences("deepseek_stage",0).getFloat("scale",0f),0f)
        assertEquals(.5f,context.getSharedPreferences("deepseek_appearance",0).getFloat("Clothes1",0f),0f)
        assertEquals(Live2DProfiles.CAICAI,Live2DProfiles.selected(context))
    }
    @Test fun rollbackRestoresBothConfigurationAndSelection() {
        prepareDeepseekSettings()
        val portable=PortableCompanionState(context,CaicaiModelRepository(context),releaseModel={})
        val token=portable.begin()["token"] as String
        portable.apply(token,oldPreferences(),restoreModels=false);portable.finish(token,false)
        assertEquals(Live2DProfiles.DEEPSEEK,Live2DProfiles.selected(context))
        assertEquals(2f,context.getSharedPreferences("deepseek_stage",0).getFloat("scale",0f),0f)
    }
    @Test fun exportIsReadOnlyAndProfilePayloadRoundTrips() {
        prepareDeepseekSettings();val epoch=Live2DProfiles.generation
        var releases=0
        val portable=PortableCompanionState(context,CaicaiModelRepository(context),releaseModel={releases++})
        val snapshot=portable.begin();val preferences=snapshot["preferences"] as Map<*,*>
        assertTrue(preferences.containsKey("deepseek_stage"))
        assertEquals(preferences.keys,PortableCompanionState.validatedPreferences(preferences).keys)
        portable.finish(snapshot["token"] as String,true)
        assertEquals(epoch,Live2DProfiles.generation);assertEquals(0,releases)
    }
    @Test fun partialOrUnknownProfileVersionIsRejectedBeforeWriting() {
        val partial=oldPreferences()+mapOf("deepseek_stage" to mapOf("scale" to 2))
        assertThrows(IllegalArgumentException::class.java) {PortableCompanionState.validatedPreferences(partial)}
        val future=oldPreferences()+mapOf("live2d_profiles_v2" to emptyMap<String,Any>())
        assertThrows(IllegalArgumentException::class.java) {PortableCompanionState.validatedPreferences(future)}
    }
    @Test fun deepseekPendingImportAlsoBlocksPortableTransaction() {
        CaicaiModelRepository(context,Live2DProfiles.DEEPSEEK).importZip(Uri.fromFile(deepseekZip()))
        val portable=PortableCompanionState(context,CaicaiModelRepository(context),releaseModel={})
        assertThrows(IllegalArgumentException::class.java) {portable.begin()}
        CaicaiModelRepository(context,Live2DProfiles.DEEPSEEK).confirmPendingImport()
    }
}
