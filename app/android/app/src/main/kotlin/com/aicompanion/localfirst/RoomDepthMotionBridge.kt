package com.aicompanion.localfirst

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import com.catkiss.senlive2dcompanion.CaicaiRuntime
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/** One foreground sensor owner shared by the Flutter and native room renderers. */
internal class RoomDepthMotionBridge(private val activity: Activity, engine: FlutterEngine) :
    EventChannel.StreamHandler, SensorEventListener {
    private val channel = EventChannel(engine.dartExecutor.binaryMessenger, "ai_companion/room_tilt")
    private val manager = activity.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val sensor = manager?.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        ?: manager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private var pendant: ((Float, Float, Boolean) -> Unit)? = null
    private var sink: EventChannel.EventSink? = null
    private var resumed = false
    private var registered = false
    private var rotation = -1
    private var lastEvent = 0L
    private val raw = FloatArray(9)
    private val screen = FloatArray(9)
    private val filter = RoomTiltFilter()

    init { channel.setStreamHandler(this) }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events; filter.reset(); rotation = -1; start()
    }
    override fun onCancel(arguments: Any?) { CaicaiRuntime.backgroundMotion(0f, 0f, true); sink = null; if (pendant == null) stop() }
    fun onResume() { resumed = true; start() }
    fun onPause() { resumed = false; stop() }
    fun setPendantListener(listener: ((Float, Float, Boolean) -> Unit)?) {
        pendant = listener
        if (listener == null && sink == null) stop() else start()
    }
    fun dispose() { pendant = null; sink = null; stop(); channel.setStreamHandler(null) }

    private fun start() {
        if (!resumed || (sink == null && pendant == null) || registered) return
        filter.reset(); rotation = -1; lastEvent = 0
        registered = sensor != null && manager?.registerListener(this, sensor, 16667) == true
        if (!registered) emit(0f, 0f, reset = true)
    }
    private fun stop() {
        if (registered) manager?.unregisterListener(this)
        registered = false; filter.reset(); lastEvent = 0
        emit(0f, 0f, reset = true)
    }
    private fun emit(x: Float, y: Float, reset: Boolean = false) {
        if (sink != null) CaicaiRuntime.backgroundMotion(x, y, reset)
        if (reset) pendant?.invoke(0f, 0f, true)
        sink?.success(mapOf("x" to x.toDouble(), "y" to y.toDouble(), "available" to registered, "reset" to reset))
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    @Suppress("DEPRECATION")
    override fun onSensorChanged(event: SensorEvent) {
        if (!registered || !resumed || (sink == null && pendant == null) || event.timestamp-lastEvent < 15_000_000) return
        lastEvent = event.timestamp
        val nextRotation = activity.windowManager.defaultDisplay.rotation
        val recalibrated = rotation != nextRotation
        if (recalibrated) { rotation = nextRotation; filter.reset() }
        SensorManager.getRotationMatrixFromVector(raw, event.values)
        val axes = when (rotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        if (SensorManager.remapCoordinateSystem(raw, axes.first, axes.second, screen) &&
            filter.update(screen, event.timestamp)) {
            emit(filter.x, filter.y, reset = recalibrated)
            // World down projected into the screen plane. Android's screen Y
            // points up in this matrix, whereas the canvas Y points down.
            pendant?.invoke(-screen[6], screen[7], false)
        }
    }
}
