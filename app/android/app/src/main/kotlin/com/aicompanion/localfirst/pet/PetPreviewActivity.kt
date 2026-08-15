package com.aicompanion.localfirst.pet

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView

class PetPreviewActivity : Activity() {
    private var player: PetAnimationPlayer? = null
    private var cache: PetFrameCache? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "桌宠播放器预览"
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
            setBackgroundColor(Color.rgb(24, 21, 28))
        }
        val status = TextView(this).apply {
            text = "正在读取皮肤…"
            textSize = 16f
            setTextColor(Color.WHITE)
        }
        root.addView(status, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
        val frameView = PetFrameView(this)
        root.addView(frameView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))

        try {
            val manifest = PetSkinManifest.load(assets)
            val frameCache = PetFrameCache(assets, ASSET_ROOT)
            cache = frameCache
            val animationPlayer = PetAnimationPlayer(
                manifest = manifest,
                cache = frameCache,
                onFrame = { frame, action, index ->
                    frameView.showFrame(frame)
                    status.text = "${manifest.name} · $action · frame ${index + 1}"
                },
                onActionChanged = { action -> status.text = "${manifest.name} · $action" },
            )
            player = animationPlayer

            val buttons = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
            }
            manifest.actions.keys.forEach { actionId ->
                buttons.addView(Button(this).apply {
                    text = actionId
                    isAllCaps = false
                    setOnClickListener {
                        val source = when (actionId) {
                            "dragging", "falling", "landing" -> PetActionSource.DRAG
                            "talk" -> PetActionSource.SPEAK
                            else -> PetActionSource.NOTICE
                        }
                        animationPlayer.play(actionId, source)
                    }
                })
            }
            root.addView(HorizontalScrollView(this).apply { addView(buttons) })
            animationPlayer.start()
        } catch (error: Throwable) {
            status.text = "桌宠皮肤读取失败：${error.message ?: error.javaClass.simpleName}"
            status.setTextColor(Color.rgb(255, 150, 150))
        }
        setContentView(root)
    }

    override fun onPause() {
        player?.setPaused(true)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        player?.setPaused(false)
    }

    override fun onDestroy() {
        player?.stop()
        cache?.clear()
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val ASSET_ROOT = "pets/dafeiyu"

        fun launch(context: Context) {
            context.startActivity(Intent(context, PetPreviewActivity::class.java))
        }
    }
}
