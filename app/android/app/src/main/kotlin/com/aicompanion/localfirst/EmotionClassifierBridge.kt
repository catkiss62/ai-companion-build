package com.aicompanion.localfirst

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.exp

/**
 * Local 19-label expression normalizer.
 *
 * The 60 MB ONNX payload is injected by CI from the pinned ModelScope source.
 * Failure is reported to Dart and always falls back to the lightweight
 * heuristic; it must never block a completed companion reply.
 */
class EmotionClassifierBridge(
    context: Context,
    engine: FlutterEngine,
) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val environment = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null
    private var tokenizer: EmotionWordPieceTokenizer? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "classify" -> {
                    val text = call.argument<String>("text").orEmpty().trim()
                    if (text.isEmpty()) {
                        result.error("empty_text", "Emotion text is empty.", null)
                    } else {
                        worker.execute {
                            runCatching { classify(text) }
                                .onSuccess { value -> mainHandler.post { result.success(value) } }
                                .onFailure { error ->
                                    mainHandler.post {
                                        result.error(
                                            "emotion_classifier_failed",
                                            error.message ?: error.javaClass.simpleName,
                                            null,
                                        )
                                    }
                                }
                        }
                    }
                }
                "status" -> worker.execute {
                    val value = runCatching {
                        ensureRuntime()
                        mapOf(
                            "available" to true,
                            "engine" to "lingchat-19emo-onnx-int8-o2",
                            "labels" to LABELS.size,
                        )
                    }.getOrElse { error ->
                        mapOf(
                            "available" to false,
                            "engine" to "lingchat-19emo-onnx-int8-o2",
                            "detail" to (error.message ?: error.javaClass.simpleName),
                        )
                    }
                    mainHandler.post { result.success(value) }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
        runCatching { session?.close() }
        session = null
        tokenizer = null
    }

    private fun ensureRuntime() {
        if (session != null && tokenizer != null) return
        val directory = File(appContext.noBackupFilesDir, "emotion_model_19emo")
        directory.mkdirs()
        val model = File(directory, "model.onnx")
        if (!model.isFile || model.length() != MODEL_BYTES) {
            val temporary = File(directory, "model.onnx.tmp")
            appContext.assets.open("$ASSET_ROOT/model.onnx").use { input ->
                temporary.outputStream().use { output -> input.copyTo(output) }
            }
            check(temporary.length() == MODEL_BYTES) {
                "19emo model size mismatch: ${temporary.length()}"
            }
            if (model.exists()) model.delete()
            check(temporary.renameTo(model)) { "Unable to install 19emo model." }
        }
        val vocabulary = appContext.assets.open("$ASSET_ROOT/vocab.txt")
            .bufferedReader(Charsets.UTF_8)
            .useLines { lines ->
                lines.mapIndexed { index, token -> token to index }.toMap()
            }
        tokenizer = EmotionWordPieceTokenizer(vocabulary)
        session = environment.createSession(
            model.absolutePath,
            OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(2)
                setInterOpNumThreads(1)
            },
        )
    }

    private fun classify(text: String): Map<String, Any> {
        ensureRuntime()
        val ids = requireNotNull(tokenizer).encode(text, MAX_LENGTH)
        val mask = FloatArray(MAX_LENGTH) { index -> if (ids[index] == 0L) 0f else 1f }
        OnnxTensor.createTensor(
            environment,
            LongBuffer.wrap(ids),
            longArrayOf(1, MAX_LENGTH.toLong()),
        ).use { inputIds ->
            OnnxTensor.createTensor(
                environment,
                FloatBuffer.wrap(mask),
                longArrayOf(1, MAX_LENGTH.toLong()),
            ).use { attentionMask ->
                val activeSession = requireNotNull(session)
                activeSession.run(
                    mapOf(
                        "input_ids" to inputIds,
                        "attention_mask" to attentionMask,
                    ),
                ).use { output ->
                    val rows = output[0].value as Array<*>
                    val logits = rows.firstOrNull() as? FloatArray
                        ?: error("Unexpected 19emo logits output.")
                    return resultMap(logits)
                }
            }
        }
    }

    private fun resultMap(logits: FloatArray): Map<String, Any> {
        require(logits.size == LABELS.size) {
            "Unexpected 19emo label count: ${logits.size}"
        }
        val max = logits.maxOrNull() ?: 0f
        val weights = DoubleArray(logits.size) { index -> exp((logits[index] - max).toDouble()) }
        val total = weights.sum().coerceAtLeast(1e-12)
        val order = logits.indices.sortedByDescending { weights[it] }.take(3)
        val first = order.first()
        val confidence = weights[first] / total
        val second = order.getOrNull(1)?.let { weights[it] / total } ?: 0.0
        return mapOf(
            "label" to LABELS[first],
            "confidence" to confidence,
            "margin" to (confidence - second),
            "top3" to order.map { index ->
                mapOf(
                    "label" to LABELS[index],
                    "confidence" to (weights[index] / total),
                )
            },
        )
    }

    companion object {
        private const val CHANNEL = "ai_companion/emotion_classifier"
        private const val ASSET_ROOT = "emotion_model_19emo"
        private const val MAX_LENGTH = 128
        private const val MODEL_BYTES = 60_004_728L
        private val LABELS = listOf(
            "兴奋", "厌恶", "哭泣", "害怕", "害羞", "平静", "心动",
            "惊讶", "慌张", "担心", "无奈", "生气", "疑惑", "紧张",
            "自信", "认真", "调皮", "难为情", "高兴",
        )
    }
}

internal class EmotionWordPieceTokenizer(
    private val vocabulary: Map<String, Int>,
) {
    private val unknownId = vocabulary["[UNK]"] ?: 100
    private val clsId = vocabulary["[CLS]"] ?: 101
    private val sepId = vocabulary["[SEP]"] ?: 102
    private val padId = vocabulary["[PAD]"] ?: 0

    fun encode(text: String, maxLength: Int): LongArray {
        require(maxLength >= 2)
        val pieces = mutableListOf<Int>()
        for (token in basicTokens(text)) {
            pieces += wordPieces(token)
            if (pieces.size >= maxLength - 2) break
        }
        val ids = LongArray(maxLength) { padId.toLong() }
        ids[0] = clsId.toLong()
        pieces.take(maxLength - 2).forEachIndexed { index, id ->
            ids[index + 1] = id.toLong()
        }
        ids[(pieces.size.coerceAtMost(maxLength - 2)) + 1] = sepId.toLong()
        return ids
    }

    private fun basicTokens(text: String): List<String> {
        val tokens = mutableListOf<String>()
        val current = StringBuilder()
        fun flush() {
            if (current.isNotEmpty()) {
                tokens += current.toString().lowercase(Locale.ROOT)
                current.clear()
            }
        }
        text.forEach { char ->
            when {
                char.isWhitespace() -> flush()
                isCjk(char) || isPunctuation(char) -> {
                    flush()
                    tokens += char.toString()
                }
                else -> current.append(char)
            }
        }
        flush()
        return tokens
    }

    private fun wordPieces(token: String): List<Int> {
        vocabulary[token]?.let { return listOf(it) }
        if (token.length > 100) return listOf(unknownId)
        val result = mutableListOf<Int>()
        var start = 0
        while (start < token.length) {
            var end = token.length
            var matched: Int? = null
            while (start < end) {
                val piece = (if (start == 0) "" else "##") + token.substring(start, end)
                val id = vocabulary[piece]
                if (id != null) {
                    matched = id
                    break
                }
                end--
            }
            if (matched == null) return listOf(unknownId)
            result += matched
            start = end
        }
        return result
    }

    private fun isCjk(char: Char): Boolean =
        char.code in 0x3400..0x4DBF || char.code in 0x4E00..0x9FFF

    private fun isPunctuation(char: Char): Boolean =
        Character.getType(char) in setOf(
            Character.CONNECTOR_PUNCTUATION.toInt(),
            Character.DASH_PUNCTUATION.toInt(),
            Character.START_PUNCTUATION.toInt(),
            Character.END_PUNCTUATION.toInt(),
            Character.INITIAL_QUOTE_PUNCTUATION.toInt(),
            Character.FINAL_QUOTE_PUNCTUATION.toInt(),
            Character.OTHER_PUNCTUATION.toInt(),
        )
}
