package com.aicompanion.localfirst.qq

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.aicompanion.localfirst.MainActivity
import com.aicompanion.localfirst.R
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Standalone opt-in host. No overlay permission, window, TTS or screen control. */
class QqPrivateService : Service() {
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())
    private var alive = false
    private var dartReady = false

    override fun onCreate() {
        super.onCreate()
        if (!enabled(this)) { stopSelf(); return }
        alive = true
        live = this
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                getSystemService(NotificationManager::class.java).createNotificationChannel(
                    NotificationChannel(CHANNEL, "QQ 陪伴连接", NotificationManager.IMPORTANCE_LOW)
                )
            }
            val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                else Notification.Builder(this))
                .setSmallIcon(R.drawable.companion_launcher_icon)
                .setContentTitle("Little Whale · QQ 连接")
                .setContentText("独立连接已开启，可在 App 能力中关闭")
                .setContentIntent(open).setOngoing(true).build()
            if (Build.VERSION.SDK_INT >= 34) startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(ID, notification)
            writeStatus("connection", "starting")
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val created = FlutterEngine(applicationContext)
            engine = created
            channel = MethodChannel(created.dartExecutor.binaryMessenger, RUNTIME).also { ch ->
                ch.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "status" -> {
                            dartReady = true
                            val kind = call.argument<String>("kind")
                            val code = call.argument<String>("code").orEmpty()
                            if (alive && (kind == "connection" || kind == "task") && code.matches(Regex("[a-z_]{1,48}"))) {
                                writeStatus(kind!!, code)
                            }
                            result.success(null)
                        }
                        "enabled" -> result.success(alive && enabled(this))
                        "failed" -> {
                            prefs(this).edit().putBoolean("enabled", false).apply()
                            writeStatus("connection", "startup_failed")
                            result.success(null)
                            main.post { stopSelf() }
                        }
                        else -> result.notImplemented()
                    }
                }
            }
            created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "qqPrivateBackgroundMain"))
            main.postDelayed({
                if (alive && engine === created && !dartReady) {
                    writeStatus("connection", "startup_failed")
                    prefs(this).edit().putBoolean("enabled", false).apply()
                    stopSelf()
                }
            }, 30000)
        } catch (_: Throwable) {
            writeStatus("connection", "startup_failed")
            prefs(this).edit().putBoolean("enabled", false).apply()
            stopSelf()
        }
    }

    private fun writeStatus(kind: String, code: String) {
        prefs(this).edit().putString(kind, code).putLong("updated", System.currentTimeMillis()).apply()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!enabled(this)) { stopSelf(); return START_NOT_STICKY }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        alive = false
        if (live === this) live = null
        channel?.setMethodCallHandler(null)
        channel = null
        engine?.destroy()
        engine = null
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "qq_private_connection_v1"
        private const val ID = 41030
        const val RUNTIME = "ai_companion/qq_private_runtime"
        @Volatile private var live: QqPrivateService? = null
        private fun prefs(context: Context) = context.getSharedPreferences("qq_private_service_v1", Context.MODE_PRIVATE)
        fun enabled(context: Context) = prefs(context).getBoolean("enabled", false)
        fun snapshot(context: Context): Map<String, Any> {
            val p = prefs(context)
            return mapOf("enabled" to enabled(context), "running" to (live != null),
                "connection" to (if (enabled(context) && live == null) "not_running" else p.getString("connection", "stopped").orEmpty()),
                "task" to p.getString("task", "idle").orEmpty())
        }
        fun start(context: Context) {
            prefs(context).edit().putBoolean("enabled", true).apply()
            try {
                val intent = Intent(context, QqPrivateService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            } catch (error: Throwable) {
                prefs(context).edit().putBoolean("enabled", false).apply()
                throw error
            }
        }
        fun stop(context: Context, done: () -> Unit) {
            prefs(context).edit().putBoolean("enabled", false).putString("connection", "stopped").apply()
            val active = live
            var finished = false
            val finish = {
                if (!finished) {
                    finished = true
                    context.stopService(Intent(context, QqPrivateService::class.java))
                    done()
                }
            }
            if (active?.channel == null) { finish(); return }
            val watchdog = Handler(Looper.getMainLooper())
            watchdog.postDelayed({ finish() }, 2500)
            active.channel?.invokeMethod("shutdown", null, object : MethodChannel.Result {
                override fun success(result: Any?) { finish() }
                override fun error(code: String, message: String?, details: Any?) { finish() }
                override fun notImplemented() { finish() }
            })
        }
    }
}

class QqPrivateBridge(context: Context, engine: FlutterEngine) {
    init {
        val app = context.applicationContext
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "ai_companion/qq_private_control")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "snapshot" -> result.success(QqPrivateService.snapshot(app))
                    "start" -> { QqPrivateService.start(app); result.success(null) }
                    "stop" -> QqPrivateService.stop(app) { result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Throwable) { result.error("qq_service_failed", "QQ 后台服务启动失败，请回到设置重试。", null) }
        }
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() {}
            override fun onEngineWillDestroy() { channel.setMethodCallHandler(null) }
        })
    }
}
