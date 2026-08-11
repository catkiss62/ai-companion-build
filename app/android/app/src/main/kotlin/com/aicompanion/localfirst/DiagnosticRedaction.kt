package com.aicompanion.localfirst

import java.security.MessageDigest

/** Pure redaction helpers shared by native diagnostic writers and JVM tests. */
object DiagnosticRedaction {
    fun fingerprint(raw: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8))
        return digest.take(6).joinToString("") { "%02x".format(it) }
    }

    fun safeToken(raw: String, max: Int): String = raw
        .replace(Regex("[^A-Za-z0-9_.:/-]"), "_")
        .take(max)

    fun sanitizeDetail(raw: String): String {
        if (raw.isBlank()) return ""
        return raw
            .replace(Regex("(?i)[0-9a-f]{32,}"), "<fingerprint>")
            .replace(Regex("(?i)[0-9a-f]{8}-[0-9a-f-]{27,}"), "<id>")
            .replace(Regex("[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9._/-]{4,}"), "<token>")
            .replace(Regex("(?:/[^\\s:]+)+"), "<path>")
            .replace(Regex("[\\r\\n\\t]+"), " ")
            .take(180)
    }
}
