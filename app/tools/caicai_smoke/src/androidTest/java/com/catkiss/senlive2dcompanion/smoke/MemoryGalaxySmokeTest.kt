package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.aicompanion.localfirst.NativeMemoryGalaxyActivity
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Exercises the production Activity and bundled HTML on the real Android WebView. */
@RunWith(AndroidJUnit4::class)
class MemoryGalaxySmokeTest {
    @Test fun all640MemoriesRenderOfflineRawTextStaysTextAndLifecycleStopsFrames() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        @Suppress("DEPRECATION")
        val permissions = context.packageManager.getPackageInfo(
            context.packageName, PackageManager.GET_PERMISSIONS,
        ).requestedPermissions ?: emptyArray()
        assertFalse("Smoke app must render without Internet permission",
            permissions.contains("android.permission.INTERNET"))
        val raw = "  <img src=x onerror=\"window.__unsafeMemory=1\">😀\u0000\n" +
            "原文 </script> & \\n 尾部  "
        val stars = JSONArray()
        repeat(640) { index ->
            stars.put(JSONObject()
                .put("id", "memory$index")
                .put("name", "真实记忆 $index")
                .put("domain", "共同经历")
                .put("importance", 5)
                .put("pinned", false)
                .put("created", "2026-09-30T13:00:00.000Z")
                .put("displayDate", "2026-10-01")
                .put("semanticLabel", "共同经历")
                .put("content", if (index == 0) raw else "真实存储原文 $index"))
        }
        withSnapshot(JSONObject().put("stars", stars).toString(), "populated") { scenario, file ->
            val before = digest(file)
            val rendered = awaitStatus(scenario) {
                it.optBoolean("started") && it.optInt("renderCount") > 1
            }
            assertEquals(640, rendered.getInt("memoryCount"))
            assertEquals("none", jsString(scenario,
                "document.getElementById('loading').style.display"))
            // Read the same intercepted private JSON used by the production page,
            // then exercise its real card renderer without exposing a native bridge.
            javascript(scenario, "fetch('memory.json').then(r=>r.json()).then(d=>{" +
                "window.openCard(d.stars[0]);window.cardLike();" +
                "window.__smokeCardReady=true;});true;")
            awaitJavaScriptTrue(scenario, "window.__smokeCardReady===true")
            assertEquals(raw, jsString(scenario,
                "document.getElementById('cBody').textContent"))
            assertEquals("记录于 2026.10.01", jsString(scenario,
                "document.getElementById('cDate').textContent"))
            assertEquals("0", javascript(scenario,
                "document.getElementById('cBody').children.length"))
            assertEquals("true", javascript(scenario, "typeof window.__unsafeMemory==='undefined'"))
            assertEquals(before, digest(file))

            javascript(scenario, "window.galaxyPause();true;")
            val paused = awaitStatus(scenario) { it.optBoolean("paused") }
            SystemClock.sleep(400)
            assertEquals(paused.getInt("renderCount"), status(scenario)!!.getInt("renderCount"))
            javascript(scenario, "window.galaxyResume();true;")
            awaitStatus(scenario) {
                !it.optBoolean("paused") && it.optInt("renderCount") > paused.getInt("renderCount")
            }

            scenario.moveToState(Lifecycle.State.CREATED)
            val background = awaitStatus(scenario) { it.optBoolean("paused") }
            SystemClock.sleep(400)
            assertEquals(background.getInt("renderCount"), status(scenario)!!.getInt("renderCount"))
            assertTrue("Pausing keeps the private snapshot available", file.isFile)
            scenario.moveToState(Lifecycle.State.RESUMED)
            awaitStatus(scenario) {
                !it.optBoolean("paused") && it.optInt("renderCount") > background.getInt("renderCount")
            }
            assertEquals(before, digest(file))
        }
    }

    @Test fun emptySnapshotShowsEmptyStateWithoutDemoMemories() {
        withSnapshot("{\"stars\":[]}", "empty") { scenario, _ ->
            val ready = awaitStatus(scenario) {
                it.optBoolean("started") && it.optInt("renderCount") > 0
            }
            assertEquals(0, ready.getInt("memoryCount"))
            assertTrue(jsString(scenario, "document.getElementById('hint').textContent")
                .contains("还没有可展示的记忆"))
            assertEquals("", jsString(scenario, "document.getElementById('cBody').textContent"))
            assertEquals("0", javascript(scenario, "document.getElementById('labels').children.length"))
        }
    }

    @Test fun malformedSnapshotShowsFailureAndNeverSubstitutesExamples() {
        withSnapshot("{ malformed JSON", "invalid") { scenario, _ ->
            awaitJavaScriptTrue(scenario,
                "document.getElementById('loading').textContent.includes('记忆加载失败')")
            val failed = awaitStatus(scenario) { it.optBoolean("paused") }
            assertEquals(0, failed.getInt("memoryCount"))
            assertEquals(0, failed.getInt("renderCount"))
            assertFalse(failed.getBoolean("started"))
            assertEquals("flex", jsString(scenario, "document.getElementById('loading').style.display"))
            assertEquals("", jsString(scenario, "document.getElementById('cBody').textContent"))
        }
    }

    private fun withSnapshot(
        json: String,
        label: String,
        block: (ActivityScenario<NativeMemoryGalaxyActivity>, File) -> Unit,
    ) {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val directory = File(context.cacheDir, "memory_galaxy").apply { mkdirs() }
        val file = File(directory, "galaxy-${System.currentTimeMillis()}-$label-${UUID.randomUUID()}.json")
        file.writeText(json, Charsets.UTF_8)
        try {
            val intent = Intent(context, NativeMemoryGalaxyActivity::class.java)
                .putExtra(NativeMemoryGalaxyActivity.EXTRA_DATA_PATH, file.absolutePath)
            ActivityScenario.launch<NativeMemoryGalaxyActivity>(intent).use { scenario ->
                block(scenario, file)
            }
            assertFalse("Closing the Activity removes its private temporary snapshot", file.exists())
        } finally {
            file.delete()
        }
    }

    private fun findWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findWebView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private fun javascript(scenario: ActivityScenario<NativeMemoryGalaxyActivity>, script: String): String {
        val returned = CountDownLatch(1)
        var result = "null"
        scenario.onActivity { activity ->
            val webView = findWebView(activity.window.decorView)
            assertNotNull("Production WebView must exist", webView)
            webView!!.evaluateJavascript(script) { value ->
                result = value ?: "null"
                returned.countDown()
            }
        }
        assertTrue("WebView JavaScript callback timed out", returned.await(5, TimeUnit.SECONDS))
        return result
    }

    private fun jsString(scenario: ActivityScenario<NativeMemoryGalaxyActivity>, script: String): String =
        JSONObject("{\"value\":${javascript(scenario, script)}}").getString("value")

    private fun status(scenario: ActivityScenario<NativeMemoryGalaxyActivity>): JSONObject? {
        val raw = javascript(scenario, "window.galaxyStatus ? window.galaxyStatus() : null")
        return if (raw == "null") null else JSONObject(raw)
    }

    private fun awaitStatus(
        scenario: ActivityScenario<NativeMemoryGalaxyActivity>,
        condition: (JSONObject) -> Boolean,
    ): JSONObject {
        val deadline = SystemClock.uptimeMillis() + 45000
        var last: JSONObject? = null
        while (SystemClock.uptimeMillis() < deadline) {
            last = status(scenario)
            if (last != null && condition(last)) return last
            SystemClock.sleep(100)
        }
        fail("Galaxy state timed out: $last; " + jsString(scenario,
            "document.getElementById('loading').textContent"))
        throw AssertionError("unreachable")
    }

    private fun awaitJavaScriptTrue(scenario: ActivityScenario<NativeMemoryGalaxyActivity>, script: String) {
        val deadline = SystemClock.uptimeMillis() + 45000
        while (SystemClock.uptimeMillis() < deadline) {
            if (javascript(scenario, script) == "true") return
            SystemClock.sleep(100)
        }
        fail("Galaxy DOM condition timed out")
    }

    private fun digest(file: File): String =
        MessageDigest.getInstance("SHA-256").digest(file.readBytes())
            .joinToString("") { "%02x".format(it) }
}
