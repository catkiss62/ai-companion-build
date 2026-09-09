package com.aicompanion.localfirst

import android.content.Context
import com.catkiss62.geniettsbenchmark.BackendMode
import com.catkiss62.geniettsbenchmark.ChineseFrontend
import com.catkiss62.geniettsbenchmark.EnglishFrontend
import com.catkiss62.geniettsbenchmark.EngineConfig
import com.catkiss62.geniettsbenchmark.GenieBenchmarkEngine
import com.catkiss62.geniettsbenchmark.ModelLoadInfo
import com.catkiss62.geniettsbenchmark.NativeJapaneseFrontend
import com.catkiss62.geniettsbenchmark.PreparedText
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/** Production adapter around the v0.6.4 verified Genie inference core. */
class GenieTtsRuntime(private val context: Context) : AutoCloseable {
    private val engine = GenieBenchmarkEngine(context)
    private var root: File? = null
    private var modelLoad = ModelLoadInfo(false, 0L)
    private var modelsReady = false
    private var activeLanguage = ""
    private var chinese: ChineseFrontend? = null
    private var english: EnglishFrontend? = null
    private var japanese: NativeJapaneseFrontend? = null

    val artifactsPresent: Boolean
        get() = runCatching {
            context.assets.open("benchmark/manifest.json").close()
            true
        }.getOrDefault(false)

    val isReady: Boolean
        get() = activeLanguage in SUPPORTED_LANGUAGES && when (activeLanguage) {
            "zh" -> chinese != null
            "en" -> english != null
            "ja" -> japanese != null
            else -> false
        }

    val acousticModelsReady: Boolean
        get() = modelsReady

    fun statusDetail(): String = when {
        !artifactsPresent -> "Genie v0.6.4 TTS 本体尚未装入 APK"
        activeLanguage.isEmpty() -> "Genie 资源存在；语言前端等待选择"
        !modelsReady -> "Genie 当前仅保留 $activeLanguage 前端；声学模型按需加载"
        else -> "Genie 声学模型已初始化；当前仅保留 $activeLanguage 前端"
    }

    fun verifyPackagedArtifacts(): Int {
        check(artifactsPresent) { "Genie v0.6.4 manifest 缺失" }
        val manifest = engine.readManifest()
        var checked = 1
        for (relative in manifest.assetFiles) {
            if (relative == manifest.frontend.roberta) continue
            context.assets.open("benchmark/$relative").use { input ->
                check(input.read() >= 0) { "Genie 资源为空：$relative" }
            }
            checked += 1
        }
        return checked
    }

    fun initialize(language: String, progress: (String) -> Unit = {}): Boolean {
        require(language in SUPPORTED_LANGUAGES) { "不支持的 TTS 语言：$language" }
        if (root == null) root = engine.prepareAssets(progress)
        prepareLanguage(language, progress)
        return isReady
    }

    fun prepareLanguage(language: String, progress: (String) -> Unit = {}) {
        require(language in SUPPORTED_LANGUAGES) { "不支持的 TTS 语言：$language" }
        val preparedRoot = root ?: engine.prepareAssets(progress).also { root = it }
        if (activeLanguage == language && isReady) return
        // The verified v0.6.4 app never keeps another language frontend alive
        // while constructing the next one. Drop the acoustic sessions too so
        // switching to Chinese cannot overlap their peak with RoBERTa startup.
        if (modelsReady) {
            engine.unloadModels()
            modelsReady = false
            modelLoad = ModelLoadInfo(false, 0L)
            System.gc()
        }
        releaseFrontend()
        when (language) {
            "zh" -> {
                GenieFrontendAdapter.prepareChineseAssets(engine, preparedRoot, progress)
                check(engine.hasFrontendModel(preparedRoot)) {
                    "请先导入与 Genie v0.6.4 配套的 Chinese RoBERTa"
                }
                chinese = ChineseFrontend(engine)
            }
            "en" -> english = EnglishFrontend(context)
            "ja" -> japanese = NativeJapaneseFrontend(context)
        }
        activeLanguage = language
    }

    fun importChineseRoberta(source: File, progress: (String) -> Unit = {}) {
        require(source.isFile && source.length() > 0L) { "所选 RoBERTa 文件无效" }
        val preparedRoot = root ?: engine.prepareAssets(progress).also { root = it }
        GenieFrontendAdapter.importRoberta(engine, context.filesDir, source, progress)
        if (activeLanguage == "zh") {
            releaseFrontend()
            prepareLanguage("zh", progress)
        }
    }

    fun generate(
        text: String,
        language: String,
        voice: String,
        speed: Double,
        shouldCancel: () -> Boolean,
        onStage: (String) -> Unit = {},
    ): ByteArray {
        initialize(language)
        val preparedRoot = checkNotNull(root)
        val manifest = engine.readManifest()
        val referenceId = VOICE_CASES[voice] ?: VOICE_CASES.getValue("daily")
        val voiceCase = manifest.cases.firstOrNull { it.id == referenceId }
            ?: error("Genie 音色资源缺失：$referenceId")
        onStage("prepare_frontend_$language")
        val prepared = when (language) {
            "zh" -> checkNotNull(chinese).prepare(
                preparedRoot,
                GenieFrontendAdapter.normalizeChineseText(text),
            ) {}
            "en" -> checkNotNull(english).prepare(text, manifest.frontend.bertDim) {}
            "ja" -> checkNotNull(japanese).prepare(text, manifest.frontend.bertDim) {}
            else -> error("不支持的 TTS 语言：$language")
        }
        onStage("frontend_ready_$language")
        check(!shouldCancel()) { "TTS generation cancelled" }
        if (!modelsReady) {
            onStage("load_acoustic_models")
            modelLoad = engine.loadModels(
                preparedRoot,
                EngineConfig(BackendMode.CPU, TARGET_THREADS),
            )
            modelsReady = true
            onStage("acoustic_models_ready")
        }
        onStage("infer_$language")
        val result = engine.runPrepared(
            preparedRoot,
            voiceCase,
            prepared,
            modelLoad,
            System.nanoTime(),
            shouldCancel = shouldCancel,
        )
        modelLoad = ModelLoadInfo(false, 0L)
        onStage("wav_encode")
        val audio = resampleForSpeed(result.audio, speed)
        return pcm16Wav(audio, manifest.sampleRate, voiceCase.playbackGainDb)
    }

    private fun resampleForSpeed(input: FloatArray, speed: Double): FloatArray {
        val ratio = speed.coerceIn(0.5, 2.0)
        if (ratio == 1.0 || input.size < 2) return input
        val size = (input.size / ratio).roundToInt().coerceAtLeast(1)
        return FloatArray(size) { index ->
            val source = index * ratio
            val left = source.toInt().coerceIn(0, input.lastIndex)
            val right = (left + 1).coerceAtMost(input.lastIndex)
            val fraction = (source - left).toFloat()
            input[left] * (1f - fraction) + input[right] * fraction
        }
    }

    private fun pcm16Wav(audio: FloatArray, sampleRate: Int, gainDb: Double): ByteArray {
        val dataBytes = audio.size * 2
        val output = ByteArrayOutputStream(44 + dataBytes)
        fun ascii(value: String) = output.write(value.toByteArray(Charsets.US_ASCII))
        fun le16(value: Int) = output.write(
            ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort(value.toShort()).array(),
        )
        fun le32(value: Int) = output.write(
            ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(value).array(),
        )
        ascii("RIFF"); le32(36 + dataBytes); ascii("WAVE")
        ascii("fmt "); le32(16); le16(1); le16(1)
        le32(sampleRate); le32(sampleRate * 2); le16(2); le16(16)
        ascii("data"); le32(dataBytes)
        val pcm = ByteBuffer.allocate(dataBytes).order(ByteOrder.LITTLE_ENDIAN)
        val requestedGain = 10.0.pow(gainDb / 20.0)
        val peak = audio.maxOfOrNull { abs(it).toDouble() } ?: 0.0
        val safeGain = if (peak > 0.0) min(requestedGain, 0.98 / peak) else requestedGain
        for (sample in audio) {
            pcm.putShort(
                (sample.toDouble() * safeGain)
                    .coerceIn(-1.0, 1.0)
                    .times(Short.MAX_VALUE)
                    .roundToInt()
                    .toShort(),
            )
        }
        output.write(pcm.array())
        return output.toByteArray()
    }

    private fun releaseFrontend() {
        chinese?.close()
        japanese?.close()
        chinese = null
        english = null
        japanese = null
        activeLanguage = ""
        System.gc()
    }

    override fun close() {
        releaseFrontend()
        engine.close()
        modelsReady = false
    }

    companion object {
        private const val TARGET_THREADS = 8
        private val SUPPORTED_LANGUAGES = setOf("zh", "ja", "en")
        private val VOICE_CASES = mapOf(
            "daily" to "ref01",
            "gentle" to "ref02",
            "lively" to "ref04",
            "cute" to "ref06",
        )
    }
}
