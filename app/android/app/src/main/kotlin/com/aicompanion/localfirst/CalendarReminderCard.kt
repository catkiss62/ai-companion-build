package com.aicompanion.localfirst

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

/** One presentation shared by the foreground/overlay and lock-screen activity. */
class CalendarReminderCard(context: Context, private val confirm: (String)->Unit): LinearLayout(context) {
    private val accent=Color.rgb(196,169,255)
    private val title=TextView(context)
    private val time=TextView(context)
    private val details=TextView(context)
    private val progress=ProgressBar(context,null,android.R.attr.progressBarStyleHorizontal)
    private var occurrence=""
    val confirmButton=Button(context).apply {
        text="确认"; textSize=17f; setTextColor(Color.rgb(28,19,43))
        backgroundTintList=android.content.res.ColorStateList.valueOf(accent)
        setOnClickListener { if(occurrence.isNotEmpty()) confirm(occurrence) }
    }
    init {
        orientation=VERTICAL
        val d=resources.displayMetrics.density
        setPadding((24*d).toInt(),(20*d).toInt(),(24*d).toInt(),(18*d).toInt())
        background=GradientDrawable().apply { setColor(Color.rgb(29,26,40)); cornerRadius=22*d; setStroke((1*d).toInt(),Color.rgb(70,60,91)) }
        elevation=14*d
        addView(TextView(context).apply { text="待办提醒"; setTextColor(accent); textSize=14f })
        title.setTextColor(Color.WHITE);title.textSize=23f;title.maxLines=3
        title.ellipsize=android.text.TextUtils.TruncateAt.END
        title.setPadding(0,(12*d).toInt(),0,(12*d).toInt());addView(title)
        time.setTextColor(accent);time.textSize=34f;time.typeface=Typeface.MONOSPACE;addView(time)
        details.setTextColor(Color.rgb(183,175,197));details.textSize=13f;addView(details)
        progress.max=1000;progress.progressTintList=android.content.res.ColorStateList.valueOf(accent)
        addView(progress,LayoutParams(LayoutParams.MATCH_PARENT,(16*d).toInt()).apply { topMargin=(12*d).toInt();bottomMargin=(12*d).toInt() })
        addView(confirmButton,LayoutParams(LayoutParams.MATCH_PARENT,LayoutParams.WRAP_CONTENT))
    }
    fun show(item: JSONObject, count: Int = 1) {
        occurrence=item.optString("occurrence");title.text=item.optString("title")
        val ringing=item.optString("status")=="ringing"
        val remaining=CalendarReminderRuntime.remaining(item)
        val seconds=(remaining+999)/1000
        time.text=if(ringing) String.format(Locale.ROOT,"%02d:%02d",seconds/60,seconds%60) else if(item.optString("status")=="timed_out") "超时未确认" else "提醒曾中断"
        val start=SimpleDateFormat("HH:mm",Locale.getDefault()).format(java.util.Date(item.optLong("startedAt")))
        details.text="$start 开始 · "+(if(ringing) "剩余响铃时间" else "确认后记为已收到")+(if(count>1) " · 共 $count 条" else "")
        progress.progress=if(ringing) ((CalendarReminderRuntime.FIVE_MINUTES-remaining)*1000/CalendarReminderRuntime.FIVE_MINUTES).toInt() else 1000
        confirmButton.isEnabled=true
    }
}
