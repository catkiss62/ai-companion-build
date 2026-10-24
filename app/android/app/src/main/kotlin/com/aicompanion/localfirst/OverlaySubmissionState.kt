package com.aicompanion.localfirst

import java.util.UUID

/** A command owns its cleanup even when the visible window is replaced. */
class OverlaySubmissionState(private val newId: () -> String = { UUID.randomUUID().toString() }) {
    data class Submission(val epoch: Long, val requestId: String, val text: String)
    private var epoch = 0L
    private var current: Submission? = null
    private var retry: Submission? = null
    val retryText: String? get() = retry?.text
    val activeRequestId: String? get() = current?.requestId

    fun restore(requestId: String, text: String) {
        if (requestId.isNotBlank() && text.isNotBlank() && current == null) {
            retry = Submission(epoch, requestId, text)
        }
    }

    fun begin(text: String): Submission {
        val id = retry?.takeIf { it.text == text }?.requestId ?: newId()
        retry = null
        return Submission(++epoch, id, text).also { current = it }
    }

    fun matches(value: Long): Boolean = value == epoch

    fun finish(value: Submission, accepted: Boolean): Boolean {
        if (!matches(value.epoch)) return false
        retry = if (accepted) null else value
        current = null
        epoch++
        return true
    }

    fun beginCancel(): Long {
        current = null
        retry = null
        return ++epoch
    }

    fun finishCancel(value: Long): Boolean {
        if (!matches(value)) return false
        epoch++
        return true
    }

    fun engineLost() {
        current?.let { retry = it }
        current = null
        epoch++
    }
}
