package com.aicompanion.localfirst

/**
 * Conservative local-first filter. It is intentionally applied before any text is
 * stored as a perception event. A user-editable package allow/deny list is still planned; this hard block is the fail-safe baseline.
 */
object PrivacyFilter {
    private val blockedFragments = listOf(
        "bank", "banking", "wallet", "payment", "paypay", "alipay",
        "password", "passwd", "authenticator", "otp", "sms", "mms",
        "messaging", "keychain", "keystore",
    )

    fun allowPackage(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false
        val p = packageName.lowercase()
        if (p == "com.aicompanion.localfirst") return false
        return blockedFragments.none { p.contains(it) }
    }

    fun sanitize(text: CharSequence?, max: Int = 500): String {
        val compact = text?.toString()
            ?.replace(Regex("\\s+"), " ")
            ?.trim()
            .orEmpty()
        return if (compact.length <= max) compact else compact.take(max) + "…"
    }
}
