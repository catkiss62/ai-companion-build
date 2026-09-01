package com.aicompanion.localfirst

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrivacyFilterTest {
    @Test
    fun `one-time screen gate allows companion and ordinary apps`() {
        assertTrue(
            PrivacyFilter.allowScreenObservationPackage(
                "com.aicompanion.localfirst",
                "com.aicompanion.localfirst",
            ),
        )
        assertTrue(
            PrivacyFilter.allowScreenObservationPackage(
                "com.example.gallery",
                "com.aicompanion.localfirst",
            ),
        )
    }

    @Test
    fun `one-time screen gate blocks sensitive and system surfaces`() {
        for (packageName in listOf(
            "com.example.banking",
            "com.example.wallet",
            "com.example.authenticator",
            "com.android.permissioncontroller",
            "com.android.documentsui",
            "com.android.settings",
            "com.android.systemui",
            "com.tencent.mm",
            "org.telegram.messenger",
            "com.google.android.gm",
            "com.openai.chatgpt",
        )) {
            assertFalse(
                packageName,
                PrivacyFilter.allowScreenObservationPackage(
                    packageName,
                    "com.aicompanion.localfirst",
                ),
            )
        }
    }
}
