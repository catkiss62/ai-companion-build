package com.aicompanion.localfirst

/** Closed categories only; exception text and speech text never leave here. */
internal object TtsFailureCategory {
    fun of(error: Throwable): String {
        val causes=generateSequence(error) { it.cause }.take(8).toList()
        val types=causes.joinToString(" ") { it.javaClass.simpleName }.lowercase()
        val hint=causes.joinToString(" ") { it.message.orEmpty() }.lowercase()
        return when {
            "deadobject" in types || "remoteexception" in types || "子进程" in hint -> "child_connection"
            "outofmemory" in types || "out of memory" in hint -> "memory_allocation"
            "cancel" in types || "cancel" in hint -> "cancelled"
            "ortexception" in types || "onnx" in hint -> "inference_runtime"
            "phoneme" in hint || "phone index" in hint -> "phoneme_input"
            "initialize" in hint || "initialization" in hint -> "initialization"
            else -> "unclassified"
        }
    }
}
