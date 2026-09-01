package com.aicompanion.localfirst

import android.content.Context

/**
 * Conservative local-first filter. It is intentionally applied before any text is
 * stored as a perception event. A user-editable package allow/deny list is still planned; this hard block is the fail-safe baseline.
 */
object PrivacyFilter {
    private val blockedFragments = listOf(
        "bank", "banking", "wallet", "payment", "paypay", "alipay",
        "password", "passwd", "authenticator", "otp", "sms", "mms",
        "messaging", "credential", "keychain", "keystore",
    )
    private val blockedScreenPackages = setOf(
        "com.tencent.mm",
        "com.tencent.mobileqq",
        "com.whatsapp",
        "org.telegram.messenger",
        "org.thoughtcrime.securesms",
        "com.google.android.gm",
        "com.openai.chatgpt",
        "com.microsoft.office.outlook",
        "com.xiaomi.account",
        "com.google.android.apps.authenticator2",
    )
    private val blockedScreenLabels = listOf(
        "bank",
        "finance",
        "wallet",
        "payment",
        "credit card",
        "authenticator",
        "银行",
        "支付",
        "钱包",
        "信用卡",
        "证券",
        "保险",
        "认证器",
    )

    fun allowPackage(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false
        val p = packageName.lowercase()
        if (p == "com.aicompanion.localfirst") return false
        return blockedFragments.none { p.contains(it) }
    }

    fun allowScreenObservationPackage(
        packageName: String?,
        companionPackageName: String,
    ): Boolean {
        if (packageName.isNullOrBlank()) return false
        val normalized = packageName.lowercase()
        if (normalized == companionPackageName.lowercase()) return true
        if (normalized in blockedScreenPackages) return false
        val systemSensitive = listOf(
            "systemui",
            "permissioncontroller",
            "packageinstaller",
            "documentsui",
            "settings",
            "keyguard",
        )
        if (systemSensitive.any(normalized::contains)) return false
        return blockedFragments.none(normalized::contains)
    }

    fun allowScreenObservationPackage(
        context: Context,
        packageName: String?,
        companionPackageName: String,
    ): Boolean {
        if (!allowScreenObservationPackage(packageName, companionPackageName)) {
            return false
        }
        if (packageName.equals(companionPackageName, ignoreCase = true)) {
            return true
        }
        val appLabel = runCatching {
            val info = context.packageManager.getApplicationInfo(packageName.orEmpty(), 0)
            context.packageManager.getApplicationLabel(info).toString().lowercase()
        }.getOrNull() ?: return false
        return blockedScreenLabels.none(appLabel::contains)
    }

    fun sanitize(text: CharSequence?, max: Int = 500): String {
        val compact = text?.toString()
            ?.replace(Regex("\\s+"), " ")
            ?.trim()
            .orEmpty()
        return if (compact.length <= max) compact else compact.take(max) + "…"
    }
}
