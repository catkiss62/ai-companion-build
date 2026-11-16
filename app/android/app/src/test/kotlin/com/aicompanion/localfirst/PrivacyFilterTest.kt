package com.aicompanion.localfirst

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrivacyFilterTest {
    @Test
    fun `ordinary apps remain eligible for application event filtering`() {
        assertTrue(PrivacyFilter.allowPackage("com.example.gallery"))
        assertFalse(PrivacyFilter.allowPackage("com.aicompanion.localfirst"))
        assertFalse(PrivacyFilter.allowPackage(null))
    }

    @Test
    fun `sensitive application events stay filtered`() {
        for (packageName in listOf(
            "com.example.banking",
            "com.example.wallet",
            "com.example.authenticator",
        )) {
            assertFalse(packageName, PrivacyFilter.allowPackage(packageName))
        }
    }
}
