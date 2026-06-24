package com.voalearningenglish.listeningskills

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat as MediaNotificationCompat
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MediaNotificationManager(private val context: Context) {
    companion object {
        private const val TAG = "MediaNotification"
        // v2: silent channel — tránh tiếng "ting" mỗi lần cập nhật play/pause/skip
        const val CHANNEL_ID = "audio_player_channel_v2"
        const val NOTIFICATION_ID = 1

        const val ACTION_PLAY = "action_play"
        const val ACTION_PAUSE = "action_pause"
        const val ACTION_TOGGLE_PLAY_PAUSE = "action_toggle_play_pause"
        const val ACTION_SKIP_FORWARD = "action_skip_forward"
        const val ACTION_SKIP_BACKWARD = "action_skip_backward"
        const val ACTION_SEEK = "action_seek"
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var mediaSession: MediaSessionCompat? = null
    private var cachedArtworkKey: String? = null
    private var cachedArtwork: Bitmap? = null
    private val artworkExecutor = Executors.newSingleThreadExecutor()

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audio Player Controls",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Controls for VOA Learning English audio player"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun setMediaSession(mediaSession: MediaSessionCompat) {
        this.mediaSession = mediaSession
    }

    fun useSharedMediaSession() {
        mediaSession = MediaPlaybackController.getSession()
    }

    fun createNotification(
        title: String,
        content: String,
        isPlaying: Boolean,
        episodeId: String? = null,
        category: String? = null,
        duration: Long = 0,
        currentPosition: Long = 0,
        thumbImageUrl: String? = null,
        thumbImageLocalPath: String? = null
    ): Notification {
        val playIntent = createActionIntent(
            ACTION_PLAY, episodeId, category, duration, currentPosition
        )
        val pauseIntent = createActionIntent(
            ACTION_PAUSE, episodeId, category, duration, currentPosition
        )
        val skipForwardIntent = createActionIntent(
            ACTION_SKIP_FORWARD, episodeId, category, duration, currentPosition
        )
        val skipBackwardIntent = createActionIntent(
            ACTION_SKIP_BACKWARD, episodeId, category, duration, currentPosition
        )

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("episode_id", episodeId)
            putExtra("category", category)
            putExtra("action", "open_player")
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            0,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mediaStyle = MediaNotificationCompat.MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)

        mediaSession?.sessionToken?.let { token ->
            mediaStyle.setMediaSession(token)
        }

        val artwork = resolveArtworkBitmap(thumbImageLocalPath, thumbImageUrl)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.drawable.ic_stat_media_play)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setStyle(mediaStyle)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setDefaults(0)
            .setSound(null)
            .setVibrate(null)
            .addAction(
                R.drawable.ic_skip_backward,
                "Skip -10s",
                skipBackwardIntent
            )
            .addAction(
                if (isPlaying) R.drawable.ic_media_pause else R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                if (isPlaying) pauseIntent else playIntent
            )
            .addAction(
                R.drawable.ic_skip_forward,
                "Skip +10s",
                skipForwardIntent
            )

        artwork?.let { bitmap ->
            builder.setLargeIcon(bitmap)
        }

        updateMediaSession(
            title = title,
            content = content,
            isPlaying = isPlaying,
            duration = duration,
            currentPosition = currentPosition,
            artwork = artwork,
        )

        if (duration > 0) {
            val max = duration.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
            val progress = currentPosition.coerceIn(0L, duration)
                .coerceAtMost(Int.MAX_VALUE.toLong())
                .toInt()
            builder.setProgress(max, progress, false)
        } else {
            builder.setProgress(0, 0, false)
        }

        if (artwork == null && !thumbImageUrl.isNullOrBlank()) {
            scheduleArtworkLoad(
                thumbImageUrl = thumbImageUrl,
                thumbImageLocalPath = thumbImageLocalPath,
                title = title,
                content = content,
                isPlaying = isPlaying,
                episodeId = episodeId,
                category = category,
                duration = duration,
                currentPosition = currentPosition,
            )
        }

        return builder.build()
    }

    private fun resolveArtworkBitmap(
        localPath: String?,
        url: String?,
    ): Bitmap? {
        val cacheKey = localPath ?: url
        if (cacheKey != null && cacheKey == cachedArtworkKey && cachedArtwork != null) {
            return cachedArtwork
        }

        localPath?.let { path ->
            loadBitmapFromFile(path)?.let { bitmap ->
                cachedArtworkKey = path
                cachedArtwork = bitmap
                return bitmap
            }
        }

        if (!url.isNullOrBlank()) {
            loadArtworkSync(url)?.let { bitmap ->
                cachedArtworkKey = url
                cachedArtwork = bitmap
                return bitmap
            }
        }

        return null
    }

    private fun updateMediaSession(
        title: String,
        content: String,
        isPlaying: Boolean,
        duration: Long,
        currentPosition: Long,
        artwork: Bitmap?,
    ) {
        val session = mediaSession ?: return

        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, content)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, content)

        if (duration > 0) {
            metadataBuilder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
        }
        artwork?.let { bitmap ->
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, bitmap)
        }
        session.setMetadata(metadataBuilder.build())

        val state = if (isPlaying) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
        val playbackSpeed = if (isPlaying) 1f else 0f
        val skipBackwardAction = PlaybackStateCompat.CustomAction.Builder(
            ACTION_SKIP_BACKWARD,
            "Skip -10s",
            R.drawable.ic_skip_backward,
        ).build()
        val skipForwardAction = PlaybackStateCompat.CustomAction.Builder(
            ACTION_SKIP_FORWARD,
            "Skip +10s",
            R.drawable.ic_skip_forward,
        ).build()
        val playbackState = PlaybackStateCompat.Builder()
            .setState(state, currentPosition.coerceAtLeast(0L), playbackSpeed)
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_SEEK_TO or
                    PlaybackStateCompat.ACTION_REWIND or
                    PlaybackStateCompat.ACTION_FAST_FORWARD
            )
            .addCustomAction(skipBackwardAction)
            .addCustomAction(skipForwardAction)
            .build()
        session.setPlaybackState(playbackState)
    }

    private fun loadBitmapFromFile(path: String): Bitmap? {
        return try {
            val file = File(path)
            if (!file.exists()) return null
            BitmapFactory.decodeFile(path)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load artwork file: ${e.message}")
            null
        }
    }

    private fun scheduleArtworkLoad(
        thumbImageUrl: String?,
        thumbImageLocalPath: String?,
        title: String,
        content: String,
        isPlaying: Boolean,
        episodeId: String?,
        category: String?,
        duration: Long,
        currentPosition: Long,
    ) {
        if (thumbImageUrl.isNullOrBlank()) return

        artworkExecutor.execute {
            val bitmap = resolveArtworkBitmap(thumbImageLocalPath, thumbImageUrl)
                ?: loadArtworkSync(thumbImageUrl)
                ?: return@execute

            cachedArtworkKey = thumbImageLocalPath ?: thumbImageUrl
            cachedArtwork = bitmap

            val updated = createNotification(
                title = title,
                content = content,
                isPlaying = isPlaying,
                episodeId = episodeId,
                category = category,
                duration = duration,
                currentPosition = currentPosition,
                thumbImageUrl = null,
                thumbImageLocalPath = cachedArtworkKey,
            )
            notificationManager.notify(NOTIFICATION_ID, updated)
            Log.d(TAG, "Artwork loaded and notification updated")
        }
    }

    private fun loadArtworkSync(url: String): Bitmap? {
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.doInput = true
            connection.connect()
            val bitmap = BitmapFactory.decodeStream(connection.inputStream)
            connection.disconnect()
            bitmap
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load artwork: ${e.message}")
            null
        }
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
