package com.aicompanion.localfirst.pet

import android.content.res.AssetManager
import org.json.JSONObject

data class PetActionLabel(
    val name: String,
    val hint: String,
)

object PetActionLabels {
    private const val PATH = "pets/dafeiyu/action_labels_zh-CN.json"

    fun load(assets: AssetManager): Map<String, PetActionLabel> {
        val json = assets.open(PATH)
            .bufferedReader(Charsets.UTF_8)
            .use { JSONObject(it.readText()) }
        val result = linkedMapOf<String, PetActionLabel>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val id = keys.next()
            val item = json.getJSONObject(id)
            result[id] = PetActionLabel(
                name = item.getString("name"),
                hint = item.optString("hint"),
            )
        }
        return result
    }
}
