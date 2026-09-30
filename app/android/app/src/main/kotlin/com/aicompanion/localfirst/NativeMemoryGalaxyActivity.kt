package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException

/** Bundled galaxy rendering in its own native surface; it has no memory-writing bridge. */
class NativeMemoryGalaxyActivity : Activity() {
    private lateinit var galaxy: WebView
    private var snapshot: File? = null
    private var pagePaused = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = BACKGROUND
        window.navigationBarColor = BACKGROUND
        snapshot = try {
            MemoryGalaxyFiles.snapshot(cacheDir, intent.getStringExtra(EXTRA_DATA_PATH))
        } catch (_: Exception) {
            fail("snapshot_unavailable")
            return
        }
        setResult(RESULT_OK)

        galaxy = WebView(this).apply {
            setBackgroundColor(BACKGROUND)
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = false
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.allowFileAccessFromFileURLs = false
            settings.allowUniversalAccessFromFileURLs = false
            settings.cacheMode = android.webkit.WebSettings.LOAD_NO_CACHE
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                    request.url.toString() != PAGE_URL

                override fun shouldInterceptRequest(
                    view: WebView,
                    request: WebResourceRequest,
                ): WebResourceResponse {
                    val uri = request.url
                    if (request.method != "GET" || uri.scheme != "https" ||
                        uri.host != LOCAL_HOST || uri.port != -1) return missingResource()
                    val path = MemoryGalaxyFiles.assetPath(uri.path) ?: return missingResource()
                    return try {
                        val stream = if (path == "memory.json") {
                            snapshot?.inputStream() ?: return missingResource()
                        } else {
                            assets.open("$ASSET_ROOT/$path")
                        }
                        val mime = mimeType(path)
                        WebResourceResponse(
                            mime,
                            if (mime.startsWith("text/") || mime == "application/javascript" ||
                                mime == "application/json") "UTF-8" else null,
                            200,
                            "OK",
                            RESPONSE_HEADERS,
                            stream,
                        )
                    } catch (_: IOException) {
                        missingResource()
                    }
                }

                override fun onPageFinished(view: WebView, url: String) {
                    if (pagePaused) view.evaluateJavascript("window.galaxyPause?.();", null)
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    if (request.isForMainFrame) fail("page_unavailable")
                }

                override fun onReceivedHttpError(
                    view: WebView,
                    request: WebResourceRequest,
                    errorResponse: WebResourceResponse,
                ) {
                    if (request.isForMainFrame) fail("page_unavailable")
                }

                override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                    fail("renderer_unavailable")
                    return true
                }
            }
        }
        setContentView(galaxy)
        galaxy.loadUrl(PAGE_URL)
    }

    override fun onPause() {
        pagePaused = true
        if (::galaxy.isInitialized) {
            galaxy.evaluateJavascript("window.galaxyPause?.();", null)
            galaxy.onPause()
        }
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        pagePaused = false
        if (::galaxy.isInitialized) {
            galaxy.onResume()
            galaxy.evaluateJavascript("window.galaxyResume?.();", null)
        }
    }

    override fun onDestroy() {
        if (::galaxy.isInitialized) {
            galaxy.stopLoading()
            (galaxy.parent as? ViewGroup)?.removeView(galaxy)
            galaxy.destroy()
        }
        // A configuration recreation still owns this snapshot. Normal close,
        // failure and process-restored close discard the temporary projection.
        if (!isChangingConfigurations) snapshot?.delete()
        snapshot = null
        super.onDestroy()
    }

    private fun fail(code: String) {
        if (isFinishing) return
        setResult(RESULT_CANCELED, Intent().putExtra(EXTRA_ERROR, code))
        finish()
    }

    companion object {
        const val EXTRA_DATA_PATH = "ai_companion_memory_galaxy_data_path"
        const val EXTRA_ERROR = "ai_companion_memory_galaxy_error"
        private const val LOCAL_HOST = "memory-galaxy.local"
        private const val PAGE_URL = "https://$LOCAL_HOST/index.html"
        private const val ASSET_ROOT = "flutter_assets/assets/memory_galaxy"
        private val BACKGROUND = Color.rgb(6, 4, 14)
        private val RESPONSE_HEADERS = mapOf(
            "Cache-Control" to "no-store",
            "Content-Security-Policy" to
                "default-src 'none'; script-src 'self' 'unsafe-inline'; " +
                "style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data:; " +
                "connect-src 'self'; object-src 'none'; base-uri 'none'; frame-src 'none'",
        )

        private fun mimeType(path: String): String = when (path.substringAfterLast('.').lowercase()) {
            "html" -> "text/html"
            "js", "mjs" -> "application/javascript"
            "json" -> "application/json"
            "css" -> "text/css"
            "woff2" -> "font/woff2"
            "woff" -> "font/woff"
            "ttf" -> "font/ttf"
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "webp" -> "image/webp"
            "svg" -> "image/svg+xml"
            else -> "application/octet-stream"
        }

        private fun missingResource() = WebResourceResponse(
            "text/plain", "UTF-8", 404, "Not Found", RESPONSE_HEADERS,
            ByteArrayInputStream("Resource unavailable".toByteArray(Charsets.UTF_8)),
        )
    }
}
