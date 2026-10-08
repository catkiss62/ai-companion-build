package com.aicompanion.localfirst

import android.app.Activity
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import org.json.JSONObject

class CalendarReminderRingingService : Service() {
    private var player: MediaPlayer?=null
    private var vibrator: Vibrator?=null
    private var audioRunning=false
    private var audioMode = -1
    private var overlay: CalendarReminderCard?=null
    private var notificationKey=""
    private val handler=Handler(Looper.getMainLooper())
    private val tick=object: Runnable { override fun run() { refresh(); if(running) handler.postDelayed(this,1000) } }
    override fun onBind(intent: Intent?): IBinder?=null
    override fun onCreate() { super.onCreate();running=true }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val first=unconfirmed(this).firstOrNull()
        if(first==null) { stopSelf();return START_NOT_STICKY }
        startForeground(41020,notification(first))
        handler.removeCallbacks(tick);handler.post(tick)
        return START_NOT_STICKY
    }
    private fun refresh() {
        CalendarReminderAlarm.state(this)
        val items=unconfirmed(this)
        if(items.isEmpty()) { stopAudio();removeOverlay();running=false;stopSelf();return }
        val item=items.first()
        val ringing=items.any { it.optString("status")=="ringing" }
        val currentMode = getSystemService(AudioManager::class.java).ringerMode
        if (ringing && (!audioRunning || audioMode != currentMode)) { stopAudio(); startAudio() }
        if(!ringing) stopAudio()
        val key=item.optString("occurrence")+":"+item.optString("status")
        if(key!=notificationKey) {
            notificationKey=key
            getSystemService(NotificationManager::class.java).notify(41020,notification(item))
        }
        val locked=getSystemService(KeyguardManager::class.java).isKeyguardLocked
        if(!locked && !CalendarReminderCardHost.foregroundVisible && !CalendarReminderAlertActivity.visible && Settings.canDrawOverlays(this)) {
            if(overlay==null) {
                val card=CalendarReminderCard(this) { CalendarReminderAlarm.confirm(this,it) }
                val width=(resources.displayMetrics.widthPixels-32*resources.displayMetrics.density).toInt()
                val params=WindowManager.LayoutParams(width.coerceAtMost((280*resources.displayMetrics.density).toInt()),
                    WindowManager.LayoutParams.WRAP_CONTENT,WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                    PixelFormat.TRANSLUCENT).apply { gravity=Gravity.BOTTOM or Gravity.RIGHT;x=(12*resources.displayMetrics.density).toInt();y=(12*resources.displayMetrics.density).toInt() }
                runCatching { getSystemService(WindowManager::class.java).addView(card,params);overlay=card }
            }
            overlay?.show(item,items.size)
        } else removeOverlay()
        // A missed reminder remains in the journal/card, without keeping an
        // invisible service alive when the system offers no overlay surface.
        if(!ringing && overlay==null && !CalendarReminderAlertActivity.visible) { running=false;stopSelf() }
    }
    private fun startAudio() {
        audioRunning=true
        val audio = getSystemService(AudioManager::class.java)
        audioMode = audio.ringerMode
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        if (audioMode == AudioManager.RINGER_MODE_NORMAL) runCatching {
            player=MediaPlayer().apply {
                setAudioAttributes(attributes)
                setDataSource(this@CalendarReminderRingingService,CalendarReminderAlarm.ringingSound(this@CalendarReminderRingingService))
                isLooping=true;prepare();start()
            }
        }
        @Suppress("DEPRECATION")
        val vibrate = audioMode == AudioManager.RINGER_MODE_VIBRATE ||
            (audioMode == AudioManager.RINGER_MODE_NORMAL && audio.shouldVibrate(AudioManager.VIBRATE_TYPE_RINGER))
        if (vibrate) {
            vibrator=getSystemService(Vibrator::class.java)
            // Ringtone attributes let the system apply call vibration / DND policy.
            @Suppress("DEPRECATION")
            vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0,700,900),0), attributes)
        }
    }
    private fun stopAudio() {
        runCatching { player?.stop() };runCatching { player?.release() };player=null
        vibrator?.cancel();vibrator=null;audioRunning=false
    }
    private fun removeOverlay() { overlay?.let { runCatching { getSystemService(WindowManager::class.java).removeView(it) } };overlay=null }
    private fun notification(item: JSONObject): Notification {
        val screen=Intent(this,CalendarReminderAlertActivity::class.java)
            .putExtra(CalendarReminderAlarm.EXTRA_OCCURRENCE,item.optString("occurrence"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending=PendingIntent.getActivity(this,41020,screen,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val ringing=item.optString("status")=="ringing"
        val builder=Notification.Builder(this,CalendarReminderAlarm.channel(this))
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle(item.optString("title"))
            .setContentText(if(ringing) "正在响铃 · 打开提醒卡片" else "提醒未确认 · 打开卡片查看")
            .setCategory(Notification.CATEGORY_ALARM).setOngoing(true).setOnlyAlertOnce(true).setContentIntent(pending)
        // An unlocked device uses the existing screen or overlay, never launches a new page.
        if(ringing && getSystemService(KeyguardManager::class.java).isKeyguardLocked) builder.setFullScreenIntent(pending,true)
        return builder.build()
    }
    override fun onDestroy() {
        running=false;handler.removeCallbacks(tick);stopAudio();removeOverlay()
        stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy()
    }
    companion object {
        const val START="calendar_start"
        @Volatile var running=false
            private set
        fun refreshIfRunning(context: Context) {
            if(running) runCatching { context.startService(Intent(context,CalendarReminderRingingService::class.java)) }
        }
        fun unconfirmed(context: Context): List<JSONObject> = CalendarReminderRuntime.records(context)
            .filter { !it.optBoolean("retired") && it.optString("status") in setOf("ringing","timed_out","interrupted") }
            .sortedWith(compareBy<JSONObject> { if(it.optString("status")=="ringing") 0 else 1 }.thenBy { it.optLong("startedAt") })
    }
}

class CalendarReminderAlertActivity : Activity() {
    private lateinit var card: CalendarReminderCard
    private val handler=Handler(Looper.getMainLooper())
    private val tick=object:Runnable {
        override fun run() {
            CalendarReminderAlarm.state(this@CalendarReminderAlertActivity)
            val items=CalendarReminderRingingService.unconfirmed(this@CalendarReminderAlertActivity)
            if(items.isEmpty()) { finish();return }
            val requested=intent.getStringExtra(CalendarReminderAlarm.EXTRA_OCCURRENCE).orEmpty()
            card.show(items.firstOrNull { it.optString("occurrence")==requested } ?: items.first(),items.size)
            handler.postDelayed(this,1000)
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if(Build.VERSION.SDK_INT>=27) { setShowWhenLocked(true);setTurnScreenOn(true) }
        else { @Suppress("DEPRECATION") window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON) }
        volumeControlStream = AudioManager.STREAM_RING
        window.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT))
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
        setFinishOnTouchOutside(false)
        val root=FrameLayout(this)
        card=CalendarReminderCard(this) {
            CalendarReminderAlarm.confirm(this,it)
            intent.removeExtra(CalendarReminderAlarm.EXTRA_OCCURRENCE)
            handler.removeCallbacks(tick);handler.post(tick)
        }
        root.addView(card,FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,FrameLayout.LayoutParams.WRAP_CONTENT))
        setContentView(root)
        val density = resources.displayMetrics.density
        window.setLayout((resources.displayMetrics.widthPixels - 24 * density).toInt().coerceAtMost((280 * density).toInt()), WindowManager.LayoutParams.WRAP_CONTENT)
        window.setGravity(Gravity.BOTTOM or Gravity.RIGHT)
        window.attributes = window.attributes.apply { x = (12 * density).toInt(); y = (12 * density).toInt() }
    }
    override fun onResume() { super.onResume();visible=true;handler.removeCallbacks(tick);handler.post(tick) }
    override fun onPause() { visible=false;handler.removeCallbacks(tick);super.onPause() }
    companion object { @Volatile var visible=false
        private set }
}
