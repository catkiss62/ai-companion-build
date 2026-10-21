package com.catkiss.senlive2dcompanion.smoke

import android.app.Activity
import android.graphics.PixelFormat
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.ListView
import com.aicompanion.localfirst.OverlayHistoryRefreshState

/** Actual WindowManager attachment with the production read coordinator. */
class OverlayHistorySmokeActivity : Activity() {
    private val history = OverlayHistoryRefreshState()
    lateinit var list: ListView
    var reads = 0
    var ready = true
    var attachedAtFirstRequest = true
    private var epoch = 0L
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(android.widget.FrameLayout(this))
    }
    fun open(backendReady: Boolean) {
        ready = backendReady
        val current = ++epoch
        list = ListView(this)
        val target = list
        target.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                target.post { if (current == epoch) refresh(current, target) }
            }
            override fun onViewDetachedFromWindow(v: View) = Unit
        })
        val params = WindowManager.LayoutParams(300, 300,
            WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT)
        params.token = window.decorView.windowToken
        windowManager.addView(target, params)
        attachedAtFirstRequest = target.isAttachedToWindow
        refresh(current, target)
    }
    fun backendReady() { ready = true; refresh(epoch, list) }
    private fun refresh(current: Long, target: ListView) {
        val request = history.request(current, target.isAttachedToWindow && ready, true) ?: return
        reads++
        // Persistent fixture proves that a newly-created host does not rely on
        // a previous send or an in-memory list to show its first history.
        val rows = getSharedPreferences("overlay_history_smoke", MODE_PRIVATE)
            .getString("messages", "")!!.split('|').filter { it.isNotEmpty() }
        target.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, rows)
        history.finish(request)
    }
    fun closeWindow() {
        epoch++
        if (::list.isInitialized && list.isAttachedToWindow) windowManager.removeViewImmediate(list)
    }
    override fun onDestroy() { closeWindow(); super.onDestroy() }
}
