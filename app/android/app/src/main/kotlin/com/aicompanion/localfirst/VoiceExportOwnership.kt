package com.aicompanion.localfirst

/** Pure ownership state for silent media export; never a playback lease. */
class VoiceExportOwnership {
    private data class Ticket(val id: Long, val host: String, val generation: Long)
    private var next = 0L
    private var active: Ticket? = null

    @Synchronized fun claim(host: String, generation: Long, playbackIdle: Boolean): Long? {
        if (!playbackIdle || active != null) return null
        val ticket = Ticket(++next, host, generation)
        active = ticket
        return ticket.id
    }
    @Synchronized fun current(host: String, id: Long, generation: Long): Boolean =
        active?.let { it.id == id && it.host == host && it.generation == generation } == true
    @Synchronized fun finish(host: String, id: Long, generation: Long): Boolean {
        if (!current(host, id, generation)) return false
        active = null
        return true
    }
    @Synchronized fun invalidate() { active = null }
    @Synchronized fun owned(host: String): Long? = active?.takeIf { it.host == host }?.id
}
