package com.aicompanion.localfirst

import org.junit.Assert.assertEquals
import org.junit.Test

class TtsFailureCategoryTest {
    @Test fun emitsOnlyCategoriesAndChecksNestedCauses() {
        assertEquals("inference_runtime",TtsFailureCategory.of(IllegalStateException("wrapper",RuntimeException("ONNX tensor shape mismatch"))))
        assertEquals("memory_allocation",TtsFailureCategory.of(OutOfMemoryError("private input")))
        assertEquals("unclassified",TtsFailureCategory.of(IllegalStateException("private text and key=fixture-secret")))
        assertEquals("cancelled",TtsFailureCategory.of(IllegalStateException("generation_cancelled")))
    }
}
