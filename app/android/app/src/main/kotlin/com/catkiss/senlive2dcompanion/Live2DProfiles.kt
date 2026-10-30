package com.catkiss.senlive2dcompanion

import android.content.Context

/** Avatar identity is unrelated to the chat provider named DeepSeek. */
object Live2DProfiles {
    const val CAICAI = "caicai"
    const val DEEPSEEK = "deepseek-avatar"
    const val REGISTRY = "live2d_profiles_v1"
    @Volatile private var requested: String? = null
    @Volatile var generation: Long = 0L
        private set

    fun valid(profile: String) = profile == CAICAI || profile == DEEPSEEK
    @Synchronized fun selected(context: Context): String {
        requested?.let { return it }
        val value = context.getSharedPreferences(REGISTRY, Context.MODE_PRIVATE).getString("active", CAICAI)
            .takeIf { it != null && valid(it) } ?: CAICAI
        requested = value
        return value
    }
    @Synchronized fun request(context: Context, profile: String) {
        require(valid(profile)) { "不支持的立绘模型" }
        requested = profile
        generation++
    }
    @Synchronized fun confirm(context: Context, profile: String, epoch: Long): Boolean {
        if (selected(context) != profile || generation != epoch) return false
        check(context.getSharedPreferences(REGISTRY, Context.MODE_PRIVATE).edit()
            .putString("active", profile).commit()) { "无法保存当前立绘" }
        return true
    }
    @Synchronized fun restored(context: Context) {
        val before = requested; requested = null
        if (before != null && before != selected(context)) generation++
    }
    fun stage(profile: String) = if (profile == CAICAI) "caicai_stage" else "deepseek_stage"
    fun index(profile: String) = if (profile == CAICAI) "caicai_live2d" else "deepseek_live2d"
    fun directory(profile: String) = if (profile == CAICAI) "caicai-live2d" else "deepseek-live2d"
}
