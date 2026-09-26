package com.aicompanion.localfirst.pet

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import com.aicompanion.localfirst.OverlayBubbleService
import kotlin.math.pow
import kotlin.math.roundToInt

/** In-app reference alignment; the live overlay continues using its old hit geometry. */
class PetCalibrationActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var frame: PetFrameView
    private lateinit var cache: PetFrameCache
    private lateinit var manifest: PetSkinManifest
    private lateinit var curve: CurveGraph
    private var calibration = PetExperimentalCalibration()
    private var targetHeight = 238
    private var selected = PetExperimentalClips.STAND
    private var compare = true
    private var frameIndex = 0

    private val tick = object : Runnable {
        override fun run() {
            render()
            frameIndex++
            handler.postDelayed(this, if (selected == PetExperimentalClips.CLICK) 111L else 167L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "新桌宠动画对齐"
        val prefs = getSharedPreferences(OverlayBubbleService.PREFS, MODE_PRIVATE)
        calibration = PetExperimentalCalibration.load(prefs)
        manifest = PetSkinManifest.load(assets)
        cache = PetFrameCache(assets)
        cache.setExperimentalGamma(calibration.gamma)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(14), dp(12), dp(14), dp(24))
            setBackgroundColor(Color.rgb(27, 29, 38))
        }
        root.addView(label("旧站立在下层；新站立半透明叠在上层。对齐脚底和身体大小后，可切换预览其他三段与点击。"))
        frame = PetFrameView(this).apply {
            setPreviewWindowDp(PetOverlaySizing.windowDp(PetOverlaySizing.MEDIUM))
            setExperimentalCalibration(calibration)
            setBackgroundColor(Color.rgb(48, 52, 65))
        }
        root.addView(frame, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(330)))
        root.addView(row(listOf("小", "中", "大")) { index ->
            val size = listOf(PetOverlaySizing.SMALL, PetOverlaySizing.MEDIUM, PetOverlaySizing.LARGE)[index]
            targetHeight = PetOverlaySizing.assetHeight(size)
            frame.setPreviewWindowDp(PetOverlaySizing.windowDp(size))
            render()
        })
        root.addView(row(listOf("双层站立对齐", "哼歌", "伸懒腰", "魔方", "点击")) { index ->
            selected = listOf(
                PetExperimentalClips.STAND,
                PetExperimentalClips.IDLE[0],
                PetExperimentalClips.IDLE[1],
                PetExperimentalClips.IDLE[2],
                PetExperimentalClips.CLICK,
            )[index]
            compare = index == 0
            frameIndex = 0
            render()
        })
        root.addView(slider("新动画缩放", 200, ((calibration.scale - 0.5f) * 100).roundToInt(),
            { "${(0.5f + it / 100f).times(100).roundToInt()}%" }) {
            calibration = calibration.copy(scale = 0.5f + it / 100f)
            update()
        })
        root.addView(slider("水平位置", 160, calibration.xDp.roundToInt() + 80,
            { "${it - 80} dp" }) {
            calibration = calibration.copy(xDp = (it - 80).toFloat())
            update()
        })
        root.addView(slider("垂直位置", 160, calibration.yDp.roundToInt() + 80,
            { "${it - 80} dp" }) {
            calibration = calibration.copy(yDp = (it - 80).toFloat())
            update()
        })
        root.addView(label("提亮曲线 · 提高中间调，透明边缘和纯白/纯黑保持不变"))
        curve = CurveGraph().apply { gamma = calibration.gamma }
        root.addView(curve, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(110)))
        root.addView(slider("中间调", 100,
            ((1.25f - calibration.gamma) / 0.0075f).roundToInt(),
            { "γ %.2f".format(1.25f - it * 0.0075f) }) {
            calibration = calibration.copy(gamma = 1.25f - it * 0.0075f)
            curve.gamma = calibration.gamma
            cache.setExperimentalGamma(calibration.gamma)
            update()
        })
        root.addView(Button(this).apply {
            text = "保存到桌宠实验动画"
            setOnClickListener {
                calibration.save(prefs)
                Toast.makeText(this@PetCalibrationActivity, "已保存，悬浮桌宠将同步使用", Toast.LENGTH_SHORT).show()
            }
        })
        val scroll = ScrollView(this)
        scroll.addView(root)
        setContentView(scroll)
    }

    private fun update() {
        frame.setExperimentalCalibration(calibration)
        render()
    }

    private fun render() {
        if (!::frame.isInitialized) return
        val old = layer("IDLE", 0)
        val next = layer(selected, frameIndex)
        if (compare) {
            frame.setCalibrationComparison(old, next)
        } else {
            frame.setCalibrationComparison(null, null)
            frame.showSnapshot(PetRenderSnapshot(
                current = next,
                previous = null,
                currentOpacity = 1f,
                previousOpacity = 0f,
                elapsedSeconds = 0f,
                effect = manifest.requireAction(selected).effect,
                selectedSize = next.bitmap.height,
                phase = PetAnimationPhase.BODY,
            ))
        }
    }

    private fun layer(id: String, index: Int): PetRenderLayer {
        val clip = manifest.clipFor(id, targetHeight, "down")
        return PetRenderLayer(
            bitmap = cache.get(clip.frames[index % clip.frames.size]),
            actionId = id,
            assetId = clip.assetId,
            frameIndex = index % clip.frames.size,
            anchor = clip.anchor,
            phase = PetAnimationPhase.BODY,
            mirrored = clip.mirrored,
        )
    }

    override fun onResume() {
        super.onResume()
        if (::frame.isInitialized) handler.post(tick)
    }

    override fun onPause() {
        handler.removeCallbacks(tick)
        super.onPause()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (::cache.isInitialized) cache.clear()
        super.onDestroy()
    }

    private fun row(titles: List<String>, click: (Int) -> Unit) = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        titles.forEachIndexed { index, title ->
            addView(Button(this@PetCalibrationActivity).apply {
                text = title
                textSize = 10f
                isAllCaps = false
                setOnClickListener { click(index) }
            }, LinearLayout.LayoutParams(0, dp(47), 1f))
        }
    }

    private fun slider(
        title: String,
        max: Int,
        initial: Int,
        describe: (Int) -> String,
        change: (Int) -> Unit,
    ) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        val description = label("$title · ${describe(initial)}")
        addView(description)
        addView(SeekBar(this@PetCalibrationActivity).apply {
            this.max = max
            progress = initial.coerceIn(0, max)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (!fromUser) return
                    description.text = "$title · ${describe(progress)}"
                    change(progress)
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
                override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
            })
        })
    }

    private fun label(value: String) = TextView(this).apply {
        text = value
        textSize = 13f
        setTextColor(Color.WHITE)
        setPadding(dp(4), dp(9), dp(4), dp(5))
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

    private inner class CurveGraph : View(this@PetCalibrationActivity) {
        var gamma = 1f
            set(value) { field = value; invalidate() }
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeWidth = dp(2).toFloat() }
        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val left = dp(12).toFloat()
            val top = dp(8).toFloat()
            val right = width - left
            val bottom = height - top
            paint.color = Color.rgb(110, 115, 130)
            canvas.drawLine(left, bottom, right, top, paint)
            val path = Path()
            repeat(65) { point ->
                val x = point / 64f
                val y = x.toDouble().pow(gamma.toDouble()).toFloat()
                if (point == 0) path.moveTo(left, bottom)
                else path.lineTo(left + x * (right - left), bottom - y * (bottom - top))
            }
            paint.color = Color.rgb(106, 210, 255)
            canvas.drawPath(path, paint)
        }
    }
}
