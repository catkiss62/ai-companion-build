package com.catkiss62.geniettsbenchmark

/**
 * Stable names for the reference-audio profiles contained in the private benchmark bundle.
 *
 * Keep [id] aligned with manifest.json. The AI companion should migrate only entries whose
 * [includeInCompanion] is true. Benchmark-only candidates are removed from the
 * production manifest before the AI Companion APK is built.
 */
data class VoiceProfileDefinition(
    val id: String,
    val key: String,
    val displayName: String,
    val intendedUse: String,
    val includeInCompanion: Boolean,
)

object VoiceProfileCatalog {
    val profiles = listOf(
        VoiceProfileDefinition("ref01", "daily", "日常认真（主音色）", "正常、认真与无法判断时的稳定默认", true),
        VoiceProfileDefinition("ref02", "gentle", "温柔轻声", "安慰、平静、担心与低强度亲密表达", true),
        VoiceProfileDefinition("ref04", "lively", "活泼可爱", "高兴、兴奋与惊讶", true),
        VoiceProfileDefinition("ref06", "cute", "日常可爱", "调皮、无奈与慌张", true),
    )

    private val byId = profiles.associateBy { it.id }

    fun resolve(id: String): VoiceProfileDefinition? = byId[id]

    fun displayName(id: String, fallback: String): String = resolve(id)?.displayName ?: fallback
}
