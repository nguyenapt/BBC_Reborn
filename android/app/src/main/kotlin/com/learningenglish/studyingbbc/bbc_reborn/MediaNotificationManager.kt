package com.learning.eslenglish

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.session.MediaSession
import android.os.Build
import androidx.core.app.NotificationCompat

class MediaNotificationManager(private val context: Context) {
    companion object {
        const val CHANNEL_ID = "audio_player_channel"
        const val NOTIFICATION_ID = 1
        
        // Action IDs
        const val ACTION_PLAY = "action_play"
        const val ACTION_PAUSE = "action_pause"
        const val ACTION_PREVIOUS = "action_previous"
        const val ACTION_NEXT = "action_next"
        const val ACTION_STOP = "action_stop"
        const val ACTION_SKIP_FORWARD = "action_skip_forward"
        const val ACTION_SKIP_BACKWARD = "action_skip_backward"
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var mediaSession: MediaSession? = null

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audio Player Controls",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Controls for BBC Learning English audio player"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun setMediaSession(mediaSession: MediaSession) {
        this.mediaSession = mediaSession
    }

    fun createNotification(
        title: String,
        content: String,
        isPlaying: Boolean,
        episodeId: String? = null,
        category: String? = null,
        duration: Long = 0,
        currentPosition: Long = 0
    ): Notification {
        
        // Tạo PendingIntent cho các action
        val playIntent = createActionIntent(ACTION_PLAY, episodeId, category, duration, currentPosition)
        val pauseIntent = createActionIntent(ACTION_PAUSE, episodeId, category, duration, currentPosition)
        val previousIntent = createActionIntent(ACTION_PREVIOUS, episodeId, category, duration, currentPosition)
        val nextIntent = createActionIntent(ACTION_NEXT, episodeId, category, duration, currentPosition)
        val stopIntent = createActionIntent(ACTION_STOP, episodeId, category, duration, currentPosition)
        val skipForwardIntent = createActionIntent(ACTION_SKIP_FORWARD, episodeId, category, duration, currentPosition)
        val skipBackwardIntent = createActionIntent(ACTION_SKIP_BACKWARD, episodeId, category, duration, currentPosition)

        // Tạo PendingIntent cho tap vào notification
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("episode_id", episodeId)
            putExtra("category", category)
            putExtra("action", "open_player")
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context, 0, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            // Thêm các action buttons
            .addAction(
                android.R.drawable.ic_media_previous,
                "Previous",
                previousIntent
            )
            .addAction(
                android.R.drawable.ic_media_rew,
                "Skip -10s",
                skipBackwardIntent
            )
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                if (isPlaying) pauseIntent else playIntent
            )
            .addAction(
                android.R.drawable.ic_media_ff,
                "Skip +10s",
                skipForwardIntent
            )
            .addAction(
                android.R.drawable.ic_media_next,
                "Next",
                nextIntent
            )
            .build()
    }

    private fun createActionIntent(
        action: String,
        episodeId: String?,
        category: String?,
        duration: Long,
        currentPosition: Long
    ): PendingIntent {
        val intent = Intent(context, MediaNotificationReceiver::class.java).apply {
            this.action = action
            putExtra("episode_id", episodeId)
            putExtra("category", category)
            putExtra("duration", duration)
            putExtra("current_position", currentPosition)
            putExtra("timestamp", System.currentTimeMillis())
        }
        
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun showNotification(notification: Notification) {
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    fun hideNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
    }
}