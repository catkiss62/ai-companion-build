package com.aicompanion.localfirst

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager

/**
 * Direct local preview for proactive-message sounds.
 *
 * This intentionally bypasses NotificationChannel so the settings screen can
 * distinguish an inaudible asset from a muted/system-customized channel.
 */
object NotificationSoundPreview {
    private val lock = Any()
    private var activePlayer: MediaPlayer? = null
    private var activeRingtone: Ringtone? = null

    fun play(context: Context, soundKey: String): Map<String, Any> {
        val normalized = CompanionNotification.normalizeSoundKey(soundKey)
        synchronized(lock) {
            stopLocked()
            if (normalized == "silent") {
                return mapOf(
                    "played" to false,
                    "reason" to "silent_selected",
                    "soundKey" to normalized,
                )
            }
            if (normalized == "system") {
                val uri = RingtoneManager.getDefaultUri(
                    RingtoneManager.TYPE_NOTIFICATION,
                ) ?: return mapOf(
                    "played" to false,
                    "reason" to "system_sound_missing",
                    "soundKey" to normalized,
                )
                val ringtone = RingtoneManager.getRingtone(context, uri)
                    ?: return mapOf(
                        "played" to false,
                        "reason" to "system_ringtone_unavailable",
                        "soundKey" to normalized,
                    )
                ringtone.audioAttributes = notificationAttributes()
                activeRingtone = ringtone
                ringtone.play()
                return mapOf(
                    "played" to true,
                    "reason" to "system_preview_started",
                    "soundKey" to normalized,
                )
            }

            val rawId = CompanionNotification.bundledSoundResource(normalized)
                ?: return mapOf(
                    "played" to false,
                    "reason" to "bundled_sound_missing",
                    "soundKey" to normalized,
                )
            val player = MediaPlayer.create(
                context,
                rawId,
                notificationAttributes(),
                AudioManager.AUDIO_SESSION_ID_GENERATE,
            ) ?: return mapOf(
                "played" to false,
                "reason" to "media_player_create_failed",
                "soundKey" to normalized,
            )
            activePlayer = player
            player.setOnCompletionListener { completed ->
                synchronized(lock) {
                    if (activePlayer === completed) activePlayer = null
                    completed.release()
                }
            }
            player.setOnErrorListener { failed, _, _ ->
                synchronized(lock) {
                    if (activePlayer === failed) activePlayer = null
                    failed.release()
                }
                true
            }
            player.start()
            return mapOf(
                "played" to true,
                "reason" to "bundled_preview_started",
                "soundKey" to normalized,
            )
        }
    }

    fun stop() = synchronized(lock) {
        stopLocked()
    }

    private fun stopLocked() {
        runCatching { activePlayer?.stop() }
        runCatching { activePlayer?.release() }
        activePlayer = null
        runCatching { activeRingtone?.stop() }
        activeRingtone = null
    }

    private fun notificationAttributes(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
}
