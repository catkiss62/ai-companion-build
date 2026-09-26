package com.aicompanion.localfirst

import android.app.Activity
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class CalendarReminderRingingService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var currentId = ""
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable {
        if (currentId.isNotEmpty()) CalendarReminderAlarm.stop(this, currentId, "timeout")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val id = intent?.getStringExtra(CalendarReminderAlarm.EXTRA_ID).orEmpty()
        val occurrence = intent?.getStringExtra(CalendarReminderAlarm.EXTRA_OCCURRENCE).orEmpty()
        if (id.isBlank() || occurrence.isBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(CalendarReminderAlarm.EXTRA_TITLE).orEmpty().take(80)
        if (currentId.isNotEmpty() && currentId != id) {
            CalendarReminderAlarm.stop(this, currentId, "replaced_by_next_alarm", false)
            stopAudio()
        }
        currentId = id
        getSharedPreferences("calendar_reminders_v1", MODE_PRIVATE).edit()
            .putString("ringing", occurrence).putString("ringing_title", title).commit()
        startForeground(41020, notification(id, title))
        stopAudio()
        runCatching {
            player = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                setDataSource(this@CalendarReminderRingingService,
                    CalendarReminderAlarm.ringingSound(this@CalendarReminderRingingService))
                isLooping = true
                prepare()
                start()
            }
        }
        vibrator = getSystemService(Vibrator::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 700, 900), 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 700, 900), 0)
        }
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, CalendarReminderAlarm.FIVE_MINUTES)
        return START_NOT_STICKY
    }

    private fun notification(id: String, title: String): Notification {
        val screen = Intent(this, CalendarReminderAlertActivity::class.java)
            .putExtra(CalendarReminderAlarm.EXTRA_ID, id)
            .putExtra(CalendarReminderAlarm.EXTRA_TITLE, title)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val screenPending = PendingIntent.getActivity(this, id.hashCode(), screen, flags)
        val stop = Intent(this, CalendarReminderReceiver::class.java)
            .setAction("com.aicompanion.localfirst.calendar.STOP")
            .putExtra(CalendarReminderAlarm.EXTRA_ID, id)
        val stopPending = PendingIntent.getBroadcast(
            this, id.hashCode() xor 0x71, stop, flags,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CalendarReminderAlarm.channel(this))
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("日历事项正在提醒 · 点击关闭")
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(screenPending)
            .setFullScreenIntent(screenPending, true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "关闭提醒", stopPending)
            .build()
    }

    private fun stopAudio() {
        handler.removeCallbacks(timeout)
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        vibrator?.cancel()
        vibrator = null
    }

    override fun onDestroy() {
        stopAudio()
        currentId = ""
        super.onDestroy()
    }

    companion object {
        const val START = "calendar_start"
        const val STOP = "calendar_stop"
    }
}

class CalendarReminderAlertActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        val id = intent.getStringExtra(CalendarReminderAlarm.EXTRA_ID).orEmpty()
        val title = intent.getStringExtra(CalendarReminderAlarm.EXTRA_TITLE).orEmpty()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(android.graphics.Color.rgb(19, 18, 32))
        }
        column.addView(TextView(this).apply {
            text = title
            textSize = 29f
            gravity = Gravity.CENTER
            setTextColor(android.graphics.Color.WHITE)
        })
        column.addView(TextView(this).apply {
            text = "日历提醒"
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(android.graphics.Color.LTGRAY)
        })
        column.addView(Button(this).apply {
            text = "关闭响铃"
            setOnClickListener {
                CalendarReminderAlarm.stop(this@CalendarReminderAlertActivity, id, "dismissed")
                finish()
            }
        })
        setContentView(column)
    }
}
