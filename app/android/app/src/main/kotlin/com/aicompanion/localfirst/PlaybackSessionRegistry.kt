package com.aicompanion.localfirst

/** Process-wide presentation identity; no inference or audio waits under its lock. */
object PlaybackSessionRegistry {
    private var lease = -1L
    private var host = ""
    private var message = ""
    private var phase = "idle"
    private var version = 0L
    private var cue = 0L
    private var cueHost = ""
    private var cueParent: Long? = null
    private var cancelCue: (() -> Unit)? = null
    @Synchronized fun claimCue(hostId: String, parent: Long?, stop: () -> Unit): Long {
        if (parent != null) check(matches(parent)) { "stale_cue_parent" }
        cancelCue?.invoke()
        cue++; cueHost = hostId; cueParent = parent; cancelCue = stop
        return cue
    }
    @Synchronized fun currentCue(value: Long, parent: Long?): Boolean =
        value == cue && (parent == null || matches(parent))
    @Synchronized fun stopCue(hostId: String, value: Long?) {
        if (cueHost != hostId || value != null && cue != value) return
        cue++; cancelCue?.invoke(); cancelCue = null
    }
    @Synchronized fun claim(value: Long, hostId: String, messageId: String) {
        cue++; cancelCue?.invoke(); cancelCue = null
        lease = value; host = hostId; message = messageId; phase = "synthesizing"; version++
    }
    @Synchronized fun invalidate(value: Long) {
        if (lease != value) return
        lease = -1L; phase = "idle"; version++
        if (cueParent == value) { cue++; cancelCue?.invoke(); cancelCue = null }
    }
    @Synchronized fun validForTail(value: Long): Boolean = lease == value || lease == -1L
    @Synchronized fun matches(value: Long): Boolean = value == lease
    @Synchronized fun current(value: Long): Boolean = value == lease && phase != "idle"
    @Synchronized fun phase(value: Long, next: String) { if (value == lease) { phase = next; version++ } }
    @Synchronized fun ownsHost(hostId: String): Long? = if (host == hostId && phase != "idle") lease else null
    @Synchronized fun snapshot(): Map<String, Any> = mapOf("lease" to lease, "host" to host,
        "message_id" to message, "phase" to phase, "version" to version)
}
