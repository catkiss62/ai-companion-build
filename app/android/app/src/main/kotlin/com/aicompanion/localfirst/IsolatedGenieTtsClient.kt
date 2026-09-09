package com.aicompanion.localfirst

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.RemoteException
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Main-process client. Model bytes and ONNX objects never enter this process. */
class IsolatedGenieTtsClient(private val context: Context) {
    private val connectionLock = Any()
    @Volatile private var remote: IGenieTtsIsolatedService? = null
    @Volatile private var connectionLatch = CountDownLatch(1)
    @Volatile private var binding = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            synchronized(connectionLock) {
                remote = IGenieTtsIsolatedService.Stub.asInterface(service)
                binding = false
                connectionLatch.countDown()
            }
            runCatching {
                service?.linkToDeath({ handleDeath("binder_died") }, 0)
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) = handleDeath("service_disconnected")
        override fun onBindingDied(name: ComponentName?) = handleDeath("binding_died")
        override fun onNullBinding(name: ComponentName?) = handleDeath("null_binding")
    }

    fun status(): Map<String, Any> = parse(call { it.statusJson() })
    fun verifyArtifacts(): Map<String, Any> = parse(call { it.verifyArtifactsJson() })
    fun initialize(language: String): Map<String, Any> = parse(call { it.initializeJson(language) })
    fun prepareLanguage(language: String): Map<String, Any> = parse(call { it.prepareLanguageJson(language) })
    fun importChineseRoberta(path: String): Map<String, Any> =
        parse(call { it.importChineseRobertaJson(path) })

    fun generateToFile(text: String, language: String, voice: String, speed: Double): String =
        call { it.generateToFile(text, language, voice, speed) }

    fun stop() {
        runCatching { remote?.stop() }
    }

    fun releaseRuntime() {
        runCatching { remote?.releaseRuntime() }
    }

    private fun <T> call(block: (IGenieTtsIsolatedService) -> T): T {
        val service = ensureConnected()
        return try {
            block(service)
        } catch (error: RemoteException) {
            handleDeath(error.javaClass.simpleName)
            throw IllegalStateException("Genie TTS 子进程已退出，请重试", error)
        }
    }

    private fun ensureConnected(): IGenieTtsIsolatedService {
        remote?.let { return it }
        val latch: CountDownLatch
        synchronized(connectionLock) {
            remote?.let { return it }
            if (!binding) {
                binding = true
                connectionLatch = CountDownLatch(1)
                val intent = Intent(context, GenieTtsIsolatedService::class.java)
                if (!context.bindService(intent, connection, Context.BIND_AUTO_CREATE)) {
                    binding = false
                    error("无法启动 Genie TTS 子进程")
                }
            }
            latch = connectionLatch
        }
        check(latch.await(10, TimeUnit.SECONDS)) { "连接 Genie TTS 子进程超时" }
        return remote ?: error("Genie TTS 子进程连接失败")
    }

    private fun handleDeath(reason: String) {
        synchronized(connectionLock) {
            remote = null
            binding = false
            connectionLatch.countDown()
        }
        val checkpoint = TtsProcessCheckpoint.read(context)
        RuntimeDiagnosticStore.record(
            context,
            category = "tts",
            phase = "child_process_exit",
            severity = "error",
            code = reason,
            metadata = mapOf("stage" to checkpoint["stage"]),
            durable = true,
        )
    }

    private fun parse(json: String): Map<String, Any> = jsonObjectToMap(JSONObject(json))

    private fun jsonObjectToMap(value: JSONObject): Map<String, Any> {
        val result = linkedMapOf<String, Any>()
        value.keys().forEach { key ->
            jsonValue(value.get(key))?.let { result[key] = it }
        }
        return result
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> List(value.length()) { index -> jsonValue(value.get(index)) }
        else -> value
    }
}
