package com.catkiss62.geniettsbenchmark

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VerifiedRuntimeConfigTest {
    @Test
    fun autoAffinityMatchesVerifiedV084Contract() {
        val config = VerifiedRuntimeConfig.AUTO_AFFINITY
        assertEquals(BackendMode.CPU, config.backend)
        assertEquals(0, config.threads)
        assertEquals(1, config.interOpThreads)
        assertEquals(GraphExecutionMode.SEQUENTIAL, config.executionMode)
        assertTrue(config.allowSpinning == true)
        assertEquals("auto_affinity_v084", config.profileId)
    }
}
