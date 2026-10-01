package com.catkiss.senlive2dcompanion.smoke

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import android.os.ParcelFileDescriptor
import android.view.View
import android.view.ViewGroup
import android.view.InputDevice
import android.view.MotionEvent
import android.webkit.WebView
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
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
        assertTrue("Smoke WebView must match the production Internet permission",
            permissions.contains("android.permission.INTERNET"))
        val raw = "  <img src=x onerror=\"window.__unsafeMemory=1\">😀\u0000\n" +
            "原文 </script> & \\n 尾部  "
        val stars = JSONArray()
        repeat(640) { index ->
            stars.put(JSONObject()
                .put("id", "memory$index")
                .put("name", "真实记忆 $index")
                .put("domain", listOf("共同经历", "用户资料", "AI Self", "偏好/边界", "记忆")[index % 5])
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
            awaitJavaScriptTrue(scenario,
                "Number(getComputedStyle(document.getElementById('veil')).opacity)<0.05")
            captureActualGalaxy(context)
            scenario.onActivity { activity ->
                assertEquals("https://memory-galaxy.local/index.html",
                    findWebView(activity.window.decorView)!!.url)
            }
            assertEquals("https://memory-galaxy.local/index.html",
                jsString(scenario, "window.location.href"))
            assertEquals("true", javascript(scenario,
                "performance.getEntriesByType('resource').length>0 && " +
                    "performance.getEntriesByType('resource').every(e=>" +
                    "new URL(e.name).origin==='https://memory-galaxy.local')"))
            // A handled CSP rejection must never trigger the page's failure UI.
            // Unlike a network 404, connect-src rejection rejects the promise.
            javascript(scenario,
                "fetch('https://outside-galaxy.invalid/memory.json').then(" +
                    "()=>{window.__smokeExternalRejected=false;}," +
                    "()=>{window.__smokeExternalRejected=true;});true;")
            awaitJavaScriptTrue(scenario, "window.__smokeExternalRejected===true")
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

    @Test fun realLongPressOnEmptySkyFindsMemoryAndPaletteIsDistinct() {
        val domains = listOf("共同经历", "用户资料", "AI Self", "偏好/边界", "记忆")
        val colors = listOf("#ff7ec4", "#7ed9cc", "#b98cff", "#8f9fff", "#ffa18f")
        val stars = JSONArray()
        domains.forEachIndexed { index, domain ->
            stars.put(JSONObject().put("id", "pick$index").put("name", "记忆$index")
                .put("domain", domain).put("importance", 5).put("pinned", false)
                .put("created", "2026-09-30T13:00:00Z").put("content", "原文$index"))
        }
        withSnapshot(JSONObject().put("stars", stars).toString(), "long-press") { scenario, file ->
            val before = digest(file)
            awaitStatus(scenario) { it.optBoolean("started") && it.optInt("renderCount") > 1 }
            awaitJavaScriptTrue(scenario,
                "Number(getComputedStyle(document.getElementById('veil')).opacity)<0.05")
            // Check the actual page's category color mapping, not a fixture copy.
            domains.forEachIndexed { index, _ ->
                javascript(scenario, "window.openCard(${stars.getJSONObject(index)})")
                assertEquals(colors[index], jsString(scenario,
                    "document.querySelector('#cStar path').getAttribute('fill')"))
                javascript(scenario, "window.closeCard()")
            }
            var x = 0f; var y = 0f
            scenario.onActivity { activity ->
                val web = findWebView(activity.window.decorView)!!
                val location = IntArray(2); web.getLocationOnScreen(location)
                x = location[0] + web.width * .94f
                y = location[1] + web.height * .12f
            }
            var downTime = 0L
            fun touch(action: Int) {
                val now = SystemClock.uptimeMillis()
                if (action == MotionEvent.ACTION_DOWN) downTime = now
                val event = MotionEvent.obtain(downTime, now, action, x, y, 0)
                event.source = InputDevice.SOURCE_TOUCHSCREEN
                try {
                    assertTrue("Inject a real touch into the production WebView",
                        InstrumentationRegistry.getInstrumentation().uiAutomation.injectInputEvent(event, true))
                } finally { event.recycle() }
            }
            // This is an empty sky region: short tap still does not pick remotely.
            touch(MotionEvent.ACTION_DOWN); SystemClock.sleep(80); touch(MotionEvent.ACTION_UP)
            SystemClock.sleep(150)
            assertEquals("false", javascript(scenario,
                "document.getElementById('card').classList.contains('show')"))
            touch(MotionEvent.ACTION_DOWN)
            try {
                awaitJavaScriptTrue(scenario,
                    "document.getElementById('card').classList.contains('show')")
                assertTrue(jsString(scenario, "document.getElementById('cTitle').textContent")
                    .matches(Regex("记忆[0-4]")))
            } finally { touch(MotionEvent.ACTION_UP) }
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
                "document.getElementById('loading')?.textContent.includes('记忆加载失败')===true")
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
        fail("Galaxy state timed out: $last; " + bootstrapState(scenario))
        throw AssertionError("unreachable")
    }

    private fun awaitJavaScriptTrue(scenario: ActivityScenario<NativeMemoryGalaxyActivity>, script: String) {
        val deadline = SystemClock.uptimeMillis() + 45000
        while (SystemClock.uptimeMillis() < deadline) {
            if (javascript(scenario, script) == "true") return
            SystemClock.sleep(100)
        }
        fail("Galaxy DOM condition timed out: " + bootstrapState(scenario))
    }

    private fun bootstrapState(scenario: ActivityScenario<NativeMemoryGalaxyActivity>): String =
        javascript(scenario, "JSON.stringify({ready:document.readyState,config:typeof CONFIG," +
            "failure:typeof window.galaxyFailed,importmap:HTMLScriptElement.supports?.('importmap')," +
            "header:!!document.getElementById('hTitle')?.textContent," +
            "loading:document.getElementById('loading')?.textContent," +
            "scripts:Array.from(document.scripts).map(s=>({type:s.type,src:s.src}))," +
            "resources:performance.getEntriesByType('resource').map(e=>({name:e.name," +
            "duration:e.duration,size:e.transferSize}))})")

    private fun digest(file: File): String =
        MessageDigest.getInstance("SHA-256").digest(file.readBytes())
            .joinToString("") { "%02x".format(it) }

    private fun captureActualGalaxy(context: Context) {
        val screenshot = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        assertNotNull("Capture the actual emulator galaxy display", screenshot)
        // UiAutomation may return a hardware-backed bitmap; sample a software copy.
        val copied = screenshot!!.copy(Bitmap.Config.ARGB_8888, false)
        assertNotNull("Read the captured galaxy pixels", copied)
        val bitmap = copied!!
        try {
            val colors = HashSet<Int>()
            val left = bitmap.width / 5
            val right = bitmap.width * 4 / 5
            val top = bitmap.height / 5
            val bottom = bitmap.height * 4 / 5
            val xStep = maxOf(1, (right - left) / 100)
            val yStep = maxOf(1, (bottom - top) / 100)
            for (y in top until bottom step yStep) {
                for (x in left until right step xStep) {
                    val pixel = bitmap.getPixel(x, y)
                    colors.add(Color.rgb(Color.red(pixel), Color.green(pixel), Color.blue(pixel)))
                }
            }
            assertTrue("Rendered particles and glow must vary from a blank central canvas",
                colors.size >= 8)
            val directory = context.getExternalFilesDir(null)
            assertNotNull("Keep the emulator render available for visual QA", directory)
            File(directory!!, "memory-galaxy-640-render.png").outputStream().use { output ->
                assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
            }
            // UTP uninstalls the test app after this suite, including its external
            // files. Copy this verified render while the app still owns it.
            // Both paths are fixed test artifacts; no memory data enters the shell.
            val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
            // UiAutomation uses Runtime.exec(String), so pass one command each:
            // operators such as && would become arguments rather than shell syntax.
            val copiedFile = automation.executeShellCommand(
                "cp /sdcard/Android/data/com.catkiss.senlive2dcompanion.smoke/files/" +
                    "memory-galaxy-640-render.png /data/local/tmp/memory-galaxy-640-render.png",
            )
            ParcelFileDescriptor.AutoCloseInputStream(copiedFile).use { it.readBytes() }
            val retainedFile = automation.executeShellCommand(
                "cat /data/local/tmp/memory-galaxy-640-render.png",
            )
            val retainedBytes = ParcelFileDescriptor.AutoCloseInputStream(retainedFile)
                .use { it.readBytes() }
            assertArrayEquals("Retain the exact actual PNG before test app cleanup",
                File(directory, "memory-galaxy-640-render.png").readBytes(), retainedBytes)
        } finally {
            bitmap.recycle()
            screenshot.recycle()
        }
    }
}
