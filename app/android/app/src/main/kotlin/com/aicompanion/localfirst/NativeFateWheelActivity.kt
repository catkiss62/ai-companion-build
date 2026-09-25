package com.aicompanion.localfirst

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.TextView

/** Direct Android WebView comparison for the exact HTML used by FateWheelPage. */
class NativeFateWheelActivity : Activity() {
    private lateinit var wheel: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = BACKGROUND
        window.navigationBarColor = BACKGROUND

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(BACKGROUND)
        }
        val header = TextView(this).apply {
            text = "‹  返回当前版       命运之轮 · 原生对照"
            textSize = 16f
            setTextColor(Color.rgb(231, 196, 99))
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), 0, dp(8), 0)
            setOnClickListener { finish() }
        }
        layout.addView(header, LinearLayout.LayoutParams(-1, dp(45)))

        wheel = WebView(this).apply {
            setBackgroundColor(BACKGROUND)
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = false
            settings.allowFileAccessFromFileURLs = false
            settings.allowUniversalAccessFromFileURLs = false
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val url = request.url.toString()
                    if (url == TRUSTED_URL || url == "about:blank") return false
                    if (url == ATTRIBUTION_URL) {
                        startActivity(Intent(Intent.ACTION_VIEW, request.url))
                    }
                    return true
                }
            }
            addJavascriptInterface(ResultBridge(), "FateWheelBridge")
        }
        layout.addView(wheel, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(layout)
        wheel.loadUrl(TRUSTED_URL)
    }

    private inner class ResultBridge {
        @JavascriptInterface
        fun postMessage(message: String) {
            if (message.length > 4096) return
            runOnUiThread {
                if (isFinishing || wheel.url != TRUSTED_URL) return@runOnUiThread
                setResult(RESULT_OK, Intent().putExtra(EXTRA_RESULT, message))
                finish()
            }
        }
    }

    override fun onDestroy() {
        if (::wheel.isInitialized) {
            wheel.removeJavascriptInterface("FateWheelBridge")
            (wheel.parent as? LinearLayout)?.removeView(wheel)
            wheel.destroy()
        }
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()

    companion object {
        const val EXTRA_RESULT = "ai_companion_fate_wheel_result"
        private const val TRUSTED_URL = "file:///android_asset/flutter_assets/assets/fate_wheel/index.html"
        private const val ATTRIBUTION_URL = "https://github.com/29-Cu/Ruota-della-Fortuna"
        private val BACKGROUND = Color.rgb(7, 5, 4)
    }
}
