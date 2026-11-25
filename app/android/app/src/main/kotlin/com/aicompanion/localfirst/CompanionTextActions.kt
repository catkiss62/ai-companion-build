package com.aicompanion.localfirst

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.view.ActionMode
import android.view.MenuItem
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.systemchannels.ProcessTextChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.text.ProcessTextPlugin

/** The standard Flutter menus for editable fields and selectable regions both
 * obtain their external entries from this engine channel. The stock plugin
 * still handles selected text, read-only flags and returned edits. */
internal class CompanionTextActions private constructor(
    private val activity: Activity,
    private val engine: FlutterEngine,
    private val stock: ProcessTextPlugin
) : ProcessTextChannel.ProcessTextMethodHandler {
    companion object {
        private const val DEEPSEEK = "com.deepseek.chat"
        private const val ASK = "ai_companion:ask_deepseek"
        private const val MORE = "ai_companion:more_selected_text"

        fun install(activity: Activity, engine: FlutterEngine): CompanionTextActions? {
            val stock = engine.plugins.get(ProcessTextPlugin::class.java) as? ProcessTextPlugin ?: return null
            return CompanionTextActions(activity, engine, stock).also { engine.processTextChannel.setMethodHandler(it) }
        }

        fun orderNative(mode: ActionMode) {
            val menu = mode.menu
            for (i in 0 until menu.size()) {
                val item = menu.getItem(i)
                val intent = item.intent ?: continue
                if (intent.action != Intent.ACTION_PROCESS_TEXT) continue
                val owner = intent.component?.packageName ?: intent.`package`
                item.setShowAsAction(if (owner == DEEPSEEK) MenuItem.SHOW_AS_ACTION_IF_ROOM else MenuItem.SHOW_AS_ACTION_NEVER)
            }
        }
    }

    private var dialog: AlertDialog? = null
    private var options: Map<String,String> = emptyMap()
    private var deepSeekId: String? = null

    private fun share(): Intent? {
        val intent = Intent(Intent.ACTION_SEND).setType("text/plain").setPackage(DEEPSEEK)
        return if (activity.packageManager.queryIntentActivities(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
                .any { it.activityInfo.exported && it.activityInfo.packageName == DEEPSEEK }) intent else null
    }

    override fun queryTextActions(): Map<String,String> {
        val all = stock.queryTextActions()
        val intent = Intent(Intent.ACTION_PROCESS_TEXT).setType("text/plain").setPackage(DEEPSEEK)
        deepSeekId = activity.packageManager.queryIntentActivities(intent, 0)
            .firstOrNull { it.activityInfo.exported && it.activityInfo.packageName == DEEPSEEK && all.containsKey(it.activityInfo.name) }
            ?.activityInfo?.name
        options = all.filterKeys { it != deepSeekId }
        return linkedMapOf<String,String>().apply {
            if (deepSeekId != null || share() != null) put(ASK, "询问 DeepSeek")
            if (options.isNotEmpty()) put(MORE, "⋯")
        }
    }

    override fun processTextAction(id: String, input: String, readOnly: Boolean, result: MethodChannel.Result) {
        queryTextActions()
        if (id == ASK) {
            val process = deepSeekId
            if (process != null) {
                stock.processTextAction(process,input,readOnly,result)
                return
            }
            val intent = share()
            if (intent == null) {
                result.success(null)
                return
            }
            try {
                activity.startActivity(intent.putExtra(Intent.EXTRA_TEXT,input))
                result.success(null)
            } catch (_: android.content.ActivityNotFoundException) {
                result.success(null)
            }
            return
        }
        if (id != MORE || options.isEmpty() || activity.isFinishing || activity.isDestroyed) {
            result.success(null)
            return
        }
        dialog?.dismiss()
        val items = options.entries.sortedBy { it.value }
        var forwarded = false
        dialog = AlertDialog.Builder(activity)
            .setTitle("更多文本操作")
            .setItems(items.map { it.value }.toTypedArray()) { _, index ->
                forwarded = true
                stock.processTextAction(items[index].key,input,readOnly,result)
            }
            .setOnDismissListener { if (!forwarded) result.success(null) }
            .show()
    }

    fun dispose() {
        dialog?.dismiss()
        dialog = null
        engine.processTextChannel.setMethodHandler(stock)
    }
}
