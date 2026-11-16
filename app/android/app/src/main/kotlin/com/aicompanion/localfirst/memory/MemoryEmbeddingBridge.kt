package com.aicompanion.localfirst.memory

import android.content.Context
import android.os.Handler
import android.os.Looper
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.nio.LongBuffer
import java.util.concurrent.Executors
import kotlin.math.sqrt

/** One shared CPU worker. Never closes the process-wide ORT environment used by TTS. */
class MemoryEmbeddingBridge(context: Context, engine: FlutterEngine) {
    init {
        val app = context.applicationContext
        val main = Handler(Looper.getMainLooper())
        MethodChannel(engine.dartExecutor.binaryMessenger, "ai_companion/memory_embedding")
            .setMethodCallHandler { call, result ->
                if (call.method != "embed") { result.notImplemented(); return@setMethodCallHandler }
                val texts = call.argument<List<String>>("texts")
                if (texts == null || texts.size !in 1..8 || texts.any { it.length > 16000 }) {
                    result.error("invalid_embedding_input", "Invalid embedding batch", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        val cold = session == null
                        val loadStart = System.nanoTime()
                        initialize(app)
                        val inferenceStart = System.nanoTime()
                        val vectors = texts.map { embed(it) }
                        val inferenceMs = (System.nanoTime() - inferenceStart) / 1_000_000
                        main.post {
                            result.success(mapOf(
                                "vectors" to vectors,
                                "loadMs" to if (cold) (inferenceStart - loadStart) / 1_000_000 else null,
                                "inferenceMs" to inferenceMs
                            ))
                        }
                    } catch (e: Exception) {
                        main.post { result.error("local_embedding_failed", e.javaClass.simpleName, null) }
                    }
                }
            }
    }
    companion object {
        private val worker = Executors.newSingleThreadExecutor { r ->
            Thread(r, "memory-embedding").apply { priority = Thread.MIN_PRIORITY }
        }
        private var session: OrtSession? = null
        private var tokenizer: BgeTokenizer? = null
        private val env by lazy { OrtEnvironment.getEnvironment() }
        private fun initialize(context: Context) {
            if (session != null) return
            val dir = File(context.noBackupFilesDir, "bge-small-75c43b0-mean-v1").apply { mkdirs() }
            val model = File(dir, "model.onnx")
            if (!model.exists() || model.length() != 24010842L) {
                val tmp = File(dir, "model.tmp")
                context.assets.open("memory_embedding/model.onnx").use { input ->
                    tmp.outputStream().use { input.copyTo(it) }
                }
                check(tmp.renameTo(model))
            }
            val json = context.assets.open("memory_embedding/tokenizer.json").bufferedReader().use { it.readText() }
            val vocabJson = JSONObject(json).getJSONObject("model").getJSONObject("vocab")
            val vocab = mutableMapOf<String, Int>()
            vocabJson.keys().forEach { vocab[it] = vocabJson.getInt(it) }
            val options = OrtSession.SessionOptions()
            try {
                options.setIntraOpNumThreads(1)
                options.setInterOpNumThreads(1)
                tokenizer = BgeTokenizer(vocab)
                session = env.createSession(model.absolutePath, options)
            } finally { options.close() }
        }
        private fun embed(text: String): FloatArray {
            val ids = tokenizer!!.encode(text)
            val shape = longArrayOf(1L, ids.size.toLong())
            val tensors = mapOf(
                "input_ids" to OnnxTensor.createTensor(env, LongBuffer.wrap(ids), shape),
                "attention_mask" to OnnxTensor.createTensor(env, LongBuffer.wrap(LongArray(ids.size) { 1 }), shape),
                "token_type_ids" to OnnxTensor.createTensor(env, LongBuffer.wrap(LongArray(ids.size)), shape))
            try {
                session!!.run(tensors).use { output ->
                    val buffer = (output[0] as OnnxTensor).floatBuffer
                    val vector = FloatArray(512)
                    for (token in ids.indices) for (d in vector.indices) vector[d] += buffer.get()
                    var sum = 0.0
                    for (d in vector.indices) { vector[d] /= ids.size.toFloat(); sum += vector[d].toDouble() * vector[d] }
                    val norm = sqrt(sum).toFloat()
                    check(norm > 0 && norm.isFinite())
                    for (d in vector.indices) vector[d] /= norm
                    return vector
                }
            } finally { tensors.values.forEach { it.close() } }
        }
    }
}
