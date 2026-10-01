package com.aicompanion.localfirst

import android.content.Context
import android.content.SharedPreferences
import com.catkiss.senlive2dcompanion.CaicaiModelRepository
import com.catkiss.senlive2dcompanion.CaicaiRuntime
import java.io.File
import java.io.IOException

/** Portable user preferences only. Runtime receipts, unread counters and leases stay local. */
class PortableCompanionState(private val context: Context, private val models: CaicaiModelRepository) {
    private var token: String? = null
    private var previous = emptyMap<String, Map<String, Any?>>()
    private var previousIndex = emptyMap<String, Any?>()
    private var applied = false
    private var modelsTouched = false
    val busy: Boolean get() = token != null

    fun begin(): Map<String, Any> {
        check(!busy) { "存档操作正在进行" }
        val lease = models.beginPortableSnapshot()
        try {
            previous = fields.mapValues { (group, keys) ->
                val all = prefs(group).all
                keys.keys.filter { all.containsKey(it) }.associateWith { all[it] }
            }
            previousIndex = prefs("caicai_live2d").all.toMap()
            token = lease
            applied = false
            modelsTouched = false
            // New exports read preferences only. Legacy restore validates its
            // incoming model tree separately; neither needs the old tree valid.
            return mapOf("token" to lease, "live2dDirectory" to models.portableDirectory(lease, validateInstalled = false).path,
                "preferences" to previous)
        } catch (error: Throwable) {
            models.endPortableSnapshot(lease)
            token = null; applied = false; previous = emptyMap(); previousIndex = emptyMap()
            throw error
        }
    }

    fun validate(lease: String, directory: String) {
        requireToken(lease)
        val file = File(directory).canonicalFile
        require(file.path.startsWith(context.filesDir.canonicalPath + File.separator) ||
            file.path.startsWith(context.cacheDir.canonicalPath + File.separator)) { "模型暂存路径无效" }
        models.validatePortableDirectory(file)
    }

    fun apply(lease: String, raw: Map<*, *>, restoreModels: Boolean = true) {
        requireToken(lease)
        val values = validatedPreferences(raw) // Validate the entire input before any write.
        CaicaiRuntime.releaseModel()
        applied = true // Partial preference/index writes must also roll back.
        for ((group, keys) in fields) replace(prefs(group), keys.keys, values.getValue(group))
        if (restoreModels) {
            modelsTouched = true
            models.installPortableIndex(lease)
        }
    }

    fun finish(lease: String, commit: Boolean) {
        requireToken(lease)
        try {
            if (applied && !commit) {
                for ((group, keys) in fields) replace(prefs(group), keys.keys, previous.getValue(group))
                if (modelsTouched) replace(prefs("caicai_live2d"), prefs("caicai_live2d").all.keys.union(previousIndex.keys), previousIndex)
            }
            if (modelsTouched && commit) models.finishPortableInstall(lease)
        } finally {
            models.endPortableSnapshot(lease)
            token = null; applied = false; modelsTouched = false; previous = emptyMap(); previousIndex = emptyMap()
        }
    }

    fun dispose() { token?.let { runCatching { finish(it, false) } } }
    private fun requireToken(lease: String) { require(token == lease && lease.isNotEmpty()) { "存档租约失效" } }
    private fun prefs(group: String) = context.getSharedPreferences(group, Context.MODE_PRIVATE)

    private fun replace(prefs: SharedPreferences, keys: Set<String>, values: Map<String, Any?>) {
        val edit = prefs.edit()
        keys.forEach { edit.remove(it) }
        values.forEach { (key, value) -> when (value) {
            is Float -> edit.putFloat(key, value)
            is Int -> edit.putInt(key, value)
            is Long -> edit.putLong(key, value)
            is Boolean -> edit.putBoolean(key, value)
            is String -> edit.putString(key, value)
            null -> edit.remove(key)
            else -> throw IOException("不支持的存档设置类型")
        } }
        if (!edit.commit()) throw IOException("无法写入存档设置")
    }

    companion object {
        // Ranges mirror the existing stage/pet controls; no permission or identity is portable.
        private val fields: Map<String, Map<String, Any>> = mapOf(
            "caicai_stage" to mapOf("motionGain" to .5f..1.5f, "motionSpeed" to .65f..1.6f,
                "legPivot" to .65f.. .98f, "scale" to .01f..100f, "x" to -100f..100f, "y" to -100f..100f,
                "headLeft" to -100f..100f, "headTop" to -100f..100f, "headRight" to -100f..100f, "headBottom" to -100f..100f),
            "overlay_state" to mapOf("entry_mode" to setOf("bubble", "pet"),
                "dialogue_color" to setOf("purple", "gold", "pink"),
                "pet_size" to setOf("small", "medium", "large"),
                "pet_motion_mode" to setOf("free", "edge", "half_top", "half_bottom", "half_left", "half_right"),
                "pet_mobility_mode" to setOf("mobile", "stationary"), "pet_dock_edge" to setOf("", "left", "right", "top", "bottom"),
                "bubble_x" to -100000..100000, "bubble_y" to -100000..100000,
                "pet_x" to -100000..100000, "pet_y" to -100000..100000,
                "bubble_retracted_left" to true,
                "pet_wide_window_position_migrated" to true, "pet_visual_width_restored_v278" to true,
                "pet_standing_touch_window_v280" to true, "pet_alpha_wide_window_v281" to true,
                "pet_square_window_position_restored" to true,
                "pet_experimental_scale" to .5f..2.5f, "pet_experimental_width_scale" to .5f..1.5f,
                "pet_experimental_x_dp" to -80f..80f, "pet_experimental_y_dp" to -80f..80f,
                "pet_experimental_gamma" to .5f..1.25f, "pet_experimental_levels_black" to 0..100,
                "pet_experimental_levels_white" to 150..255, "pet_experimental_saturation" to .5f..2f),
            "companion_runtime" to mapOf("overlay_user_enabled" to true),
        )
        fun validatedPreferences(raw: Map<*, *>): Map<String, Map<String, Any?>> {
            require(raw.keys == fields.keys) { "存档缺少本机显示设置" }
            return fields.mapValues { (group, keys) ->
                val values = raw[group] as? Map<*, *> ?: throw IOException("存档设置格式无效")
                require(values.keys.all { it in keys }) { "存档包含未知本机设置" }
                values.entries.associate { (name, value) ->
                    val key = name as String
                    val rule = keys.getValue(key)
                    val converted: Any = when (rule) {
                        is IntRange -> {
                            val n = value as? Number ?: throw IOException("设置必须为整数")
                            require(n.toDouble().isFinite() && n.toDouble() == n.toInt().toDouble() && n.toInt() in rule)
                            n.toInt()
                        }
                        is ClosedFloatingPointRange<*> -> {
                            val n = (value as? Number)?.toFloat() ?: throw IOException("设置必须为数值")
                            @Suppress("UNCHECKED_CAST") val range = rule as ClosedFloatingPointRange<Float>
                            require(n.isFinite() && n in range); n
                        }
                        is Set<*> -> { require(value is String && value in rule); value }
                        else -> { require(value is Boolean); value }
                    }
                    key to converted
                }
            }
        }
    }
}
