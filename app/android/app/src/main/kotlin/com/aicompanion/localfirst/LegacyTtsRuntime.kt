package com.aicompanion.localfirst

import android.content.Context
import android.util.Base64
import dalvik.system.DexClassLoader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import java.util.zip.Deflater
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * Compatibility adapter for the user-validated multi-language LocalTTSEngine.
 *
 * The compiled Meju preprocessing/runtime remains isolated behind a controlled
 * child-first DexClassLoader. Only Java/Android platform classes and this host
 * bridge are delegated to the parent first; every class carried by the supplied
 * runtime DEX (including Kotlin, coroutines, AndroidX and obfuscated helpers) is
 * resolved from that DEX before falling back to the app. This keeps the runtime
 * binary-compatible without allowing it to shadow Android or the bridge.
 *
 * We also avoid reflecting Kotlin singleton fields such as
 * EmptyCoroutineContext.INSTANCE or COROUTINE_SUSPENDED. The continuation proxy
 * is built from the exact interfaces resolved by the isolated runtime.
 */
class LegacyTtsRuntime(private val context: Context) {
    private val appContext = context.applicationContext
    private val artifactVerifier = TtsArtifactVerifier(appContext)

    @Volatile
    private var classLoader: DexClassLoader? = null

    @Volatile
    private var engine: Any? = null

    @Volatile
    var lastError: String = ""
        private set

    @Volatile
    private var diagnosticTrace: List<String> = emptyList()

    val artifactsPresent: Boolean
        get() = artifactVerifier.quickArtifactsPresent()

    internal fun integrityResult(): TtsIntegrityResult = artifactVerifier.currentResult()

    internal fun verifyArtifacts(force: Boolean = false): TtsIntegrityResult =
        artifactVerifier.verify(force = force)

    internal fun diagnosticTrace(): List<String> = diagnosticTrace.toList()

    /** Redacted class-loading evidence; never includes the sentence being synthesized. */
    internal fun failureDiagnosticMetadata(error: Throwable): Map<String, Any?> {
        val types = ArrayList<String>()
        var target = ""
        var current: Throwable? = error
        var depth = 0
        while (current != null && depth < 8) {
            types += current.javaClass.name
            if (target.isEmpty()) {
                target = CLASS_TOKEN_REGEX.find(current.message.orEmpty())
                    ?.value
                    ?.replace('/', '.')
                    .orEmpty()
            }
            val next = current.cause
            current = if (next == null || next === current) null else next
            depth += 1
        }
        return linkedMapOf(
            "stage" to diagnosticTrace.lastOrNull().orEmpty(),
            "loaderPolicy" to LOADER_POLICY,
            "failureType" to types.joinToString(">"),
        ).apply {
            if (target.isNotEmpty()) put("failureTarget", target)
        }
    }

    internal fun resetDiagnosticTrace() {
        diagnosticTrace = emptyList()
    }

    internal fun markDiagnosticStage(stage: String) {
        synchronized(this) {
            if (diagnosticTrace.lastOrNull() != stage) {
                diagnosticTrace = diagnosticTrace + stage
            }
        }
    }

    @Synchronized
    fun initialize(): Boolean {
        resetDiagnosticTrace()
        return initializeInternal()
    }

    private fun initializeInternal(): Boolean {
        if (isReady()) {
            markDiagnosticStage("engine_ready")
            lastError = ""
            return true
        }
        if (!artifactsPresent) {
            lastError = "legacy TTS runtime/model assets are missing"
            return false
        }
        val integrity = verifyArtifacts()
        if (!integrity.ok) {
            lastError = integrity.detail
            return false
        }
        markDiagnosticStage("artifact_integrity")

        return runCatching {
            val loader = classLoader ?: buildClassLoader().also { classLoader = it }
            markDiagnosticStage("legacy_classloader")

            val clazz = loader.loadClass(ENGINE_CLASS)
            markDiagnosticStage("engine_class")

            val languageClass = loader.loadClass(LANGUAGE_CLASS)
            val chinese = languageClass.getField("ZH").get(null)

            val instance = engine ?: clazz.getConstructor(Context::class.java)
                .newInstance(appContext)
                .also { engine = it }
            markDiagnosticStage("engine_instance")

            clazz.getMethod("setLanguageOverride", languageClass)
                .invoke(instance, chinese)
            markDiagnosticStage("language_zh")

            val initialize = findLegacySuspendMethod(
                clazz = clazz,
                name = "initialize",
                leadingParameterTypes = emptyList(),
            )
            markDiagnosticStage("initialize_signature")
            invokeLegacySuspendBlocking(instance, initialize, timeoutSeconds = 300)

            val ready = clazz.getMethod("isReady").invoke(instance) as? Boolean ?: false
            if (!ready) error("Meju LocalTTSEngine finished initialize() but isReady=false")
            markDiagnosticStage("engine_ready")
            lastError = ""
            true
        }.getOrElse {
            lastError = rootMessage(it)
            false
        }
    }

    fun isReady(): Boolean {
        val instance = engine ?: return false
        return runCatching {
            instance.javaClass.getMethod("isReady").invoke(instance) as? Boolean ?: false
        }.getOrDefault(false)
    }

    fun generateWavBytes(text: String): ByteArray {
        require(text.isNotBlank()) { "TTS text is blank" }
        if (!isReady() && !initialize()) {
            error("TTS initialization failed: $lastError")
        }
        return generateWavBytesInternal(text)
    }

    /** Same real inference path as speak(), but without AudioTrack playback. */
    fun diagnoseWavBytes(text: String): ByteArray {
        require(text.isNotBlank()) { "TTS diagnostic text is blank" }
        resetDiagnosticTrace()
        if (!initializeInternal()) {
            error("TTS initialization failed: $lastError")
        }
        return generateWavBytesInternal(text)
    }

    private fun generateWavBytesInternal(text: String): ByteArray {
        val instance = engine ?: error("Meju TTS engine is unavailable")
        return runCatching {
            val method = findLegacySuspendMethod(
                clazz = instance.javaClass,
                name = "generateTTS",
                leadingParameterTypes = listOf(String::class.java),
            )
            markDiagnosticStage("generate_signature")
            val value = invokeLegacySuspendBlocking(
                instance,
                method,
                text,
                timeoutSeconds = 1_200,
            )
            val wav = when (value) {
                is ByteArray -> value
                is String -> {
                    val encoded = value.substringAfter("base64,", value).trim()
                    if (encoded.isEmpty()) error("Meju generateTTS returned empty Base64 audio")
                    Base64.decode(encoded, Base64.DEFAULT)
                }
                null -> error(
                    "Meju generateTTS returned null; the sentence may exceed the ZH 300-phone limit",
                )
                else -> error("Meju generateTTS returned ${value.javaClass.name}")
            }
            validateWav(wav)
            markDiagnosticStage("wav_bytes")
            lastError = ""
            wav
        }.getOrElse {
            lastError = rootMessage(it)
            throw it
        }
    }

    private fun validateWav(wav: ByteArray) {
        val riff = wav.size >= 12 &&
            wav[0] == 'R'.code.toByte() && wav[1] == 'I'.code.toByte() &&
            wav[2] == 'F'.code.toByte() && wav[3] == 'F'.code.toByte() &&
            wav[8] == 'W'.code.toByte() && wav[9] == 'A'.code.toByte() &&
            wav[10] == 'V'.code.toByte() && wav[11] == 'E'.code.toByte()
        if (!riff) error("Meju generateTTS returned invalid WAV bytes: ${wav.size}")
    }

    fun setLengthScale(value: Float) {
        val instance = engine ?: return
        runCatching {
            val method = findLegacySuspendMethod(
                clazz = instance.javaClass,
                name = "setLengthScale",
                leadingParameterTypes = listOf(Float::class.javaPrimitiveType!!),
            )
            invokeLegacySuspendBlocking(instance, method, value, timeoutSeconds = 60)
        }.onFailure { lastError = rootMessage(it) }
    }

    fun setSpeakerId(value: Int) {
        val instance = engine ?: return
        runCatching {
            instance.javaClass.getMethod("setSpeakerId", Int::class.javaPrimitiveType!!)
                .invoke(instance, value)
        }.onFailure { lastError = rootMessage(it) }
    }

    @Synchronized
    fun release() {
        val instance = engine
        if (instance != null) {
            runCatching {
                val method = findLegacySuspendMethod(
                    clazz = instance.javaClass,
                    name = "release",
                    leadingParameterTypes = emptyList(),
                )
                invokeLegacySuspendBlocking(instance, method, timeoutSeconds = 60)
            }
                .onFailure { lastError = rootMessage(it) }
        }
        engine = null
        classLoader = null
        resetDiagnosticTrace()
    }

    private fun buildClassLoader(): DexClassLoader {
        val versionDir = File(appContext.codeCacheDir, RUNTIME_CACHE_DIR)
        if (!versionDir.exists() && !versionDir.mkdirs()) {
            error("Unable to create ${versionDir.absolutePath}")
        }
        val optimized = File(versionDir, "opt").apply { mkdirs() }

        val assetNames = appContext.assets.list(RUNTIME_ASSET_DIR)
            .orEmpty()
            .filter { it.endsWith(".jar") }
            .sorted()
        if (assetNames.isEmpty()) error("No legacy runtime jars found")

        val runtimeFiles = assetNames.map { assetName ->
            val target = File(versionDir, assetName)
            val assetPath = "$RUNTIME_ASSET_DIR/$assetName"
            val expected = TtsGoldenBaseline.assets[assetPath]
                ?: error("Missing golden fingerprint for $assetPath")
            val injectPinyin = assetName == PINYIN_RUNTIME_JAR
            val cachedValid = target.isFile && if (injectPinyin) {
                target.length() > expected.size
            } else {
                target.length() == expected.size &&
                    runCatching { TtsArtifactVerifier.sha256(target) == expected.sha256 }
                        .getOrDefault(false)
            }
            if (!cachedValid) {
                val temp = File(versionDir, "$assetName.tmp")
                runCatching { temp.delete() }
                if (injectPinyin) {
                    buildRuntimeJarWithPinyin(assetPath, temp)
                } else {
                    appContext.assets.open(assetPath).use { input ->
                        temp.outputStream().use { output -> input.copyTo(output) }
                    }
                }
                val copiedValid = if (injectPinyin) {
                    temp.length() > expected.size
                } else {
                    temp.length() == expected.size &&
                        TtsArtifactVerifier.sha256(temp) == expected.sha256
                }
                if (!copiedValid) {
                    temp.delete()
                    error("Runtime copy fingerprint mismatch: $assetName")
                }
                if (target.exists()) {
                    target.setWritable(true)
                    if (!target.delete()) error("Unable to replace ${target.absolutePath}")
                }
                if (!temp.renameTo(target)) {
                    temp.delete()
                    error("Unable to publish runtime cache: ${target.absolutePath}")
                }
            }
            if (!target.setReadOnly()) {
                error("Unable to mark runtime read-only: ${target.absolutePath}")
            }
            target
        }

        return RuntimeDexClassLoader(
            runtimeFiles.joinToString(File.pathSeparator) { it.absolutePath },
            optimized.absolutePath,
            appContext.applicationInfo.nativeLibraryDir,
            appContext.classLoader,
        )
    }

    /**
     * Android's normal DexClassLoader is parent-first. That is unsafe for this
     * payload because its two DEX files contain their own Kotlin/coroutines and
     * obfuscated state-machine classes, while the Flutter host contains another
     * version of the same dependencies. Keep platform/bridge identity shared;
     * isolate every other payload class and fall back only when absent from DEX.
     */
    private class RuntimeDexClassLoader(
        dexPath: String,
        optimizedDirectory: String,
        librarySearchPath: String?,
        parent: ClassLoader,
    ) : DexClassLoader(dexPath, optimizedDirectory, librarySearchPath, parent) {
        override fun loadClass(name: String, resolve: Boolean): Class<*> {
            synchronized(this) {
                findLoadedClass(name)?.let { loaded ->
                    if (resolve) resolveClass(loaded)
                    return loaded
                }

                val loaded = if (isAlwaysParentFirstClass(name)) {
                    super.loadClass(name, false)
                } else {
                    try {
                        findClass(name)
                    } catch (_: ClassNotFoundException) {
                        super.loadClass(name, false)
                    }
                }
                if (resolve) resolveClass(loaded)
                return loaded
            }
        }
    }

    /** Inject the five APK-root houbb-pinyin dictionaries into its class path. */
    private fun buildRuntimeJarWithPinyin(runtimeAsset: String, output: File) {
        ZipInputStream(appContext.assets.open(runtimeAsset)).use { input ->
            ZipOutputStream(FileOutputStream(output)).use { stream ->
                stream.setLevel(Deflater.NO_COMPRESSION)
                while (true) {
                    val entry = input.nextEntry ?: break
                    stream.putNextEntry(ZipEntry(entry.name))
                    if (!entry.isDirectory) copyStream(input, stream)
                    stream.closeEntry()
                    input.closeEntry()
                }

                val dictionaries = appContext.assets.list(PINYIN_ASSET_DIR)
                    .orEmpty()
                    .sorted()
                if (dictionaries.size != 5) {
                    error("Expected 5 houbb-pinyin dictionaries, found ${dictionaries.size}")
                }
                for (name in dictionaries) {
                    stream.putNextEntry(ZipEntry(name))
                    appContext.assets.open("$PINYIN_ASSET_DIR/$name").use { dictionary ->
                        copyStream(dictionary, stream)
                    }
                    stream.closeEntry()
                }
            }
        }
    }

    private fun copyStream(input: InputStream, output: OutputStream) {
        val buffer = ByteArray(64 * 1024)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (count > 0) output.write(buffer, 0, count)
        }
    }

    /** Resolve suspend methods from the loaded legacy engine, never host Kotlin. */
    private fun findLegacySuspendMethod(
        clazz: Class<*>,
        name: String,
        leadingParameterTypes: List<Class<*>>,
    ): Method {
        val candidates = clazz.methods.filter { method ->
            if (method.name != name) return@filter false
            val params = method.parameterTypes
            if (params.size != leadingParameterTypes.size + 1) return@filter false
            if (params.lastOrNull()?.name != LEGACY_CONTINUATION_CLASS) return@filter false
            leadingParameterTypes.indices.all { index ->
                params[index] == leadingParameterTypes[index]
            }
        }
        if (candidates.size != 1) {
            val signatures = clazz.methods
                .filter { it.name == name }
                .joinToString("; ") { method ->
                    method.parameterTypes.joinToString(
                        prefix = "${method.name}(",
                        postfix = ")",
                    ) { it.name }
                }
            error(
                "Unable to resolve legacy suspend $name; " +
                    "matches=${candidates.size}; available=$signatures",
            )
        }
        return candidates.single()
    }

    private data class LegacySuspendOutcome(
        val value: Any? = null,
        val error: Throwable? = null,
    )

    private fun invokeLegacySuspendBlocking(
        target: Any,
        method: Method,
        vararg args: Any?,
        timeoutSeconds: Long,
    ): Any? {
        val continuationType = method.parameterTypes.lastOrNull()
            ?: error("Legacy suspend method ${method.name} has no continuation parameter")
        if (continuationType.name != LEGACY_CONTINUATION_CLASS || !continuationType.isInterface) {
            error(
                "Unexpected continuation type for ${method.name}: " +
                    continuationType.name,
            )
        }

        val continuationLoader = continuationType.classLoader
            ?: target.javaClass.classLoader
            ?: error("Legacy TTS class loader is unavailable")
        val getContextMethod = continuationType.methods.singleOrNull { candidate ->
            candidate.parameterCount == 0 &&
                candidate.returnType.name == LEGACY_COROUTINE_CONTEXT_CLASS
        } ?: error("Legacy Continuation CoroutineContext accessor not found")
        val contextType = getContextMethod.returnType
        if (!contextType.isInterface) {
            error("Legacy CoroutineContext is not an interface: ${contextType.name}")
        }

        val emptyContext = createEmptyCoroutineContext(contextType, continuationLoader)
        markDiagnosticStage("coroutine_context")

        val latch = CountDownLatch(1)
        val outcome = AtomicReference<LegacySuspendOutcome?>()
        val continuation = Proxy.newProxyInstance(
            continuationLoader,
            arrayOf(continuationType),
        ) { proxy, called, callArgs ->
            when {
                called.declaringClass == Any::class.java && called.name == "toString" ->
                    "LegacyContinuationProxy(${method.name})"
                called.declaringClass == Any::class.java && called.name == "hashCode" ->
                    System.identityHashCode(proxy)
                called.declaringClass == Any::class.java && called.name == "equals" ->
                    proxy === callArgs?.getOrNull(0)
                called.parameterCount == 0 && called.returnType == contextType -> emptyContext
                called.parameterCount == 1 && called.returnType == Void.TYPE -> {
                    val raw = callArgs?.getOrNull(0)
                    outcome.compareAndSet(null, decodeLegacyResult(raw))
                    latch.countDown()
                    null
                }
                else -> error(
                    "Unexpected legacy Continuation method: ${called.name}/" +
                        "${called.parameterCount}->${called.returnType.name}",
                )
            }
        }
        markDiagnosticStage("continuation_proxy")

        val immediate = try {
            method.invoke(target, *args, continuation)
        } catch (e: InvocationTargetException) {
            throw e.targetException ?: e
        }
        markDiagnosticStage("${method.name}_invoked")

        if (!isCoroutineSuspended(immediate)) {
            markDiagnosticStage("${method.name}_completed")
            return immediate
        }
        if (!latch.await(timeoutSeconds, TimeUnit.SECONDS)) {
            error("Timed out waiting for ${method.name} (${timeoutSeconds}s)")
        }
        val completed = outcome.get()
            ?: error("Legacy ${method.name} resumed without an outcome")
        completed.error?.let { throw it }
        markDiagnosticStage("${method.name}_completed")
        return completed.value
    }

    /**
     * Build the exact CoroutineContext interface resolved by the legacy
     * Continuation. EmptyCoroutineContext is a Kotlin object whose INSTANCE
     * field can be shadowed/renamed by the host release runtime, so no static
     * singleton reflection is used here.
     */
    private fun createEmptyCoroutineContext(
        contextType: Class<*>,
        loader: ClassLoader,
    ): Any = Proxy.newProxyInstance(loader, arrayOf(contextType)) { proxy, called, args ->
        when {
            called.declaringClass == Any::class.java && called.name == "toString" ->
                "LegacyEmptyCoroutineContextProxy"
            called.declaringClass == Any::class.java && called.name == "hashCode" -> 0
            called.declaringClass == Any::class.java && called.name == "equals" ->
                proxy === args?.getOrNull(0)
            // CoroutineContext.fold(initial, operation) on Empty returns initial.
            called.parameterCount == 2 -> args?.getOrNull(0)
            // plus(context) returns the supplied context.
            called.parameterCount == 1 && called.parameterTypes[0] == contextType ->
                args?.getOrNull(0)
            // minusKey(key) returns Empty itself.
            called.parameterCount == 1 && called.returnType == contextType -> proxy
            // get(key) returns no element.
            called.parameterCount == 1 -> null
            else -> error(
                "Unexpected legacy CoroutineContext method: ${called.name}/" +
                    "${called.parameterCount}->${called.returnType.name}",
            )
        }
    }

    /**
     * Kotlin's suspend marker is an enum singleton. For the only two supported
     * legacy methods, legitimate immediate values are Unit/null (initialize)
     * or ByteArray (generateTTS), so an enum value is unambiguously suspension.
     * Name/toString fallbacks cover a non-enum compatibility runtime without
     * reflecting IntrinsicsKt or a static COROUTINE_SUSPENDED field.
     */
    private fun isCoroutineSuspended(value: Any?): Boolean {
        if (value == null) return false
        if (value is Enum<*>) return true
        val className = value.javaClass.name
        if (className.contains("CoroutineSingleton", ignoreCase = true)) return true
        return runCatching { value.toString() == "COROUTINE_SUSPENDED" }.getOrDefault(false)
    }

    private fun decodeLegacyResult(raw: Any?): LegacySuspendOutcome {
        if (raw == null) return LegacySuspendOutcome(value = null)
        if (raw is Throwable) return LegacySuspendOutcome(error = raw)
        // The only successful resume payloads used by this bridge are the
        // generated ByteArray/String and Kotlin Unit. Avoid reflective field scans for
        // those normal hot-path values.
        if (raw is ByteArray || raw is String || raw.javaClass.name == "kotlin.Unit") {
            return LegacySuspendOutcome(value = raw)
        }

        // Kotlin Result.Failure may come from a legacy or parent-loaded runtime.
        // Do not depend on its class or field name after R8; inspect for a
        // Throwable-valued instance field instead.
        var current: Class<*>? = raw.javaClass
        while (current != null && current != Any::class.java) {
            for (field in current.declaredFields) {
                val candidate = runCatching {
                    field.isAccessible = true
                    field.get(raw)
                }.getOrNull()
                if (candidate is Throwable) {
                    return LegacySuspendOutcome(error = candidate)
                }
            }
            current = current.superclass
        }
        return LegacySuspendOutcome(value = raw)
    }

    private fun rootMessage(error: Throwable): String {
        var current = error
        while (current.cause != null && current.cause !== current) {
            current = current.cause!!
        }
        return "${current.javaClass.simpleName}: ${current.message ?: "unknown error"}"
    }

    companion object {
        private const val LOADER_POLICY = "payload_child_first"
        private val CLASS_TOKEN_REGEX = Regex(
            "(?:[A-Za-z_$][A-Za-z0-9_$]*[./])+[A-Za-z_$][A-Za-z0-9_$]*",
        )
        private val ALWAYS_PARENT_FIRST_PREFIXES = listOf(
            "java.",
            "javax.",
            "android.",
            "dalvik.",
            "libcore.",
            "sun.",
            "org.w3c.",
            "org.xml.",
            "org.json.",
            "com.android.",
            "com.aicompanion.localfirst.",
        )

        internal fun isAlwaysParentFirstClass(name: String): Boolean =
            ALWAYS_PARENT_FIRST_PREFIXES.any(name::startsWith)

        private const val ENGINE_CLASS =
            "com.gamedeveloper.urbanfriendshipstory.tts.LocalTTSEngine"
        private const val LANGUAGE_CLASS =
            "com.gamedeveloper.urbanfriendshipstory.tts.TtsLanguage"
        private const val RUNTIME_ASSET_DIR = "legacy_tts/runtime"
        private const val PINYIN_ASSET_DIR = "legacy_tts/pinyin"
        private const val PINYIN_RUNTIME_JAR = "runtime_01.jar"
        private const val RUNTIME_CACHE_DIR = "meju_tts_v395_b72ebc85"
        private const val LEGACY_CONTINUATION_CLASS = "kotlin.coroutines.Continuation"
        private const val LEGACY_COROUTINE_CONTEXT_CLASS = "kotlin.coroutines.CoroutineContext"
    }
}
