package com.aicompanion.localfirst

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer
import android.speech.RecognizerIntent
import android.widget.ImageView
import com.dsh.eye.LensCamera
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.Executors

class LensHost(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "ai_companion/lens")
    private val worker = Executors.newSingleThreadExecutor()
    private var owner = -1
    private var preview: ImageView? = null
    private var camera: LensCamera? = null
    private var permission: MethodChannel.Result? = null
    private var voice: MethodChannel.Result? = null
    private var resumed = false
    private var recognizer: SpeechRecognizer? = null
    private var awaitingMic = false
    private var startMicOnResume = false

    init {
        engine.platformViewsController.registry.registerViewFactory("ai_companion/lens_preview",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    detach()
                    val image = ImageView(context).apply {
                        scaleType = ImageView.ScaleType.FIT_CENTER
                        setBackgroundColor(Color.BLACK)
                    }
                    owner = viewId
                    preview = image
                    return object : PlatformView {
                        override fun getView() = image
                        override fun dispose() { if (owner == viewId) detach() }
                    }
                }
            })
        channel.setMethodCallHandler { call, result ->
            if (call.argument<Int>("id") != owner || owner == -1) {
                result.error("ended", "本场镜头已结束", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "permission" -> {
                    if (hasCamera()) result.success(true)
                    else if (permission != null) result.error("busy", "正在等待相机权限", null)
                    else {
                        permission = result
                        activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST)
                    }
                }
                "start" -> {
                    if (!hasCamera() || !resumed) result.success(false)
                    else {
                        if (camera == null) camera = LensCamera(activity, preview!!)
                        result.success(true)
                    }
                }
                "pause" -> { stopCamera(); if (recognizer != null) finishVoice(); result.success(null) }
                "take" -> {
                    val source = camera
                    val user = call.argument<Boolean>("user") == true
                    val statsOnly = call.argument<Boolean>("stats") == true
                    if (source == null) result.success(null)
                    else worker.execute {
                        try {
                            val data = source.take(user, statsOnly)
                            activity.runOnUiThread { result.success(if (source === camera) data else null) }
                        } catch (e: Exception) {
                            activity.runOnUiThread { result.error("frame", "暂时取不到画面", null) }
                        }
                    }
                }
                "voice" -> {
                    if (voice != null) result.error("busy", "正在语音输入", null)
                    else {
                        voice = result
                        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
                            try { activity.startActivityForResult(voiceIntent(), VOICE_REQUEST) }
                            catch (e: Exception) { voiceError("系统语音输入不可用，可以打字或使用输入法语音") }
                        } else if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            awaitingMic = true
                            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MIC_REQUEST)
                        } else listen()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasCamera() = activity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    private fun voiceIntent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        .putExtra(RecognizerIntent.EXTRA_PROMPT, "和小鲸鱼说话")

    private fun finishVoice(words: String? = null) {
        val old = recognizer
        recognizer = null
        old?.destroy()
        voice?.success(words)
        voice = null
    }
    private fun voiceError(message: String) {
        val pending = voice
        voice = null
        finishVoice()
        pending?.error("voice", message, null)
    }
    private fun listen() {
        if (voice == null) return
        if (!resumed) { startMicOnResume = true; return }
        startMicOnResume = false
        try {
            val listener = SpeechRecognizer.createSpeechRecognizer(activity)
            recognizer = listener
            listener.setRecognitionListener(object : RecognitionListener {
                override fun onResults(results: Bundle?) {
                    if (recognizer === listener) finishVoice(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull())
                }
                override fun onError(error: Int) {
                    if (recognizer === listener) voiceError("这次没有识别到语音，可以再说一次或打字")
                }
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            listener.startListening(voiceIntent())
        } catch (e: Exception) { voiceError("语音输入暂时不可用，可以使用输入法语音") }
    }
    fun onResume() {
        resumed = true
        if (startMicOnResume) listen()
    }
    fun onPause() {
        resumed = false
        stopCamera()
        if (recognizer != null) finishVoice()
    }
    fun permissionResult(code: Int) {
        if (code == CAMERA_REQUEST) { permission?.success(hasCamera()); permission = null }
        if (code == MIC_REQUEST && awaitingMic) {
            awaitingMic = false
            if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) listen()
            else voiceError("使用语音输入需要麦克风权限，也可以打字")
        }
    }
    fun voiceResult(code: Int, status: Int, intent: Intent?) {
        if (code != VOICE_REQUEST) return
        val words = if (status == Activity.RESULT_OK) intent?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null
        voice?.success(words)
        voice = null
    }
    private fun stopCamera() { camera?.stop(); camera = null }
    private fun detach() {
        stopCamera()
        permission?.success(false); permission = null
        awaitingMic = false
        startMicOnResume = false
        finishVoice()
        preview = null
        owner = -1
    }
    fun dispose() { detach(); channel.setMethodCallHandler(null); worker.shutdown() }
    companion object {
        private const val CAMERA_REQUEST = 0x6510
        private const val VOICE_REQUEST = 0x6511
        private const val MIC_REQUEST = 0x6512
    }
}
