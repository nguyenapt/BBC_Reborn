package com.learn.speak.british.english

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import android.view.KeyEvent

typealias MediaActionForwarder = (String, Map<String, Any?>) -> Unit

/**
 * Giữ MediaSession toàn app — notification, tai nghe Bluetooth và lock screen
 * đều đi qua cùng một session/callback.
 */
object MediaPlaybackController {
    private const val TAG = "MediaPlayback"

    private var mediaSession: MediaSessionCompat? = null
    private var forwarder: MediaActionForwarder? = null

    fun initialize(context: Context, actionForwarder: MediaActionForwarder) {
        forwarder = actionForwarder
        if (mediaSession != null) return

        val appContext = context.applicationContext
        mediaSession = MediaSessionCompat(appContext, "BBCLearningEnglish").apply {
            setCallback(createCallback())

            val contentIntent = Intent(appContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "open_player")
            }
            setSessionActivity(
                PendingIntent.getActivity(
                    appContext,
                    0,
                    contentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        Log.d(TAG, "MediaSession initialized")
    }

    fun getSession(): MediaSessionCompat? = mediaSession

    fun setActive(active: Boolean) {
        mediaSession?.isActive = active
        Log.d(TAG, "MediaSession active=$active")
    }

    fun dispatchMediaButtonIntent(intent: Intent?): Boolean {
        val session = mediaSession ?: return false
        if (intent?.action != Intent.ACTION_MEDIA_BUTTON) return false
        val keyEvent = extractKeyEvent(intent) ?: return false
        return session.controller.dispatchMediaButtonEvent(keyEvent)
    }

    fun release() {
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
        forwarder = null
    }

    private fun forward(action: String, extras: Map<String, Any?> = emptyMap()) {
        Log.d(TAG, "Forward media action: $action")
        forwarder?.invoke(action, extras)
    }

    private fun createCallback(): MediaSessionCompat.Callback {
        return object : MediaSessionCompat.Callback() {
            override fun onSeekTo(pos: Long) {
                forward(
                    MediaNotificationManager.ACTION_SEEK,
                    mapOf("seek_to" to pos),
                )
            }

            override fun onPlay() {
                forward(MediaNotificationManager.ACTION_PLAY)
            }

            override fun onPause() {
                forward(MediaNotificationManager.ACTION_PAUSE)
            }

            override fun onRewind() {
                forward(MediaNotificationManager.ACTION_SKIP_BACKWARD)
            }

            override fun onFastForward() {
                forward(MediaNotificationManager.ACTION_SKIP_FORWARD)
            }

            override fun onSkipToNext() {
                forward(MediaNotificationManager.ACTION_SKIP_FORWARD)
            }

            override fun onSkipToPrevious() {
                forward(MediaNotificationManager.ACTION_SKIP_BACKWARD)
            }

            override fun onCustomAction(action: String, extras: Bundle?) {
                when (action) {
                    MediaNotificationManager.ACTION_SKIP_BACKWARD ->
                        forward(MediaNotificationManager.ACTION_SKIP_BACKWARD)
                    MediaNotificationManager.ACTION_SKIP_FORWARD ->
                        forward(MediaNotificationManager.ACTION_SKIP_FORWARD)
                    else -> super.onCustomAction(action, extras)
                }
            }

            override fun onMediaButtonEvent(mediaButtonEvent: Intent): Boolean {
                val keyEvent = extractKeyEvent(mediaButtonEvent)
                    ?: return super.onMediaButtonEvent(mediaButtonEvent)

                if (keyEvent.action != KeyEvent.ACTION_DOWN) {
                    return true
                }

                return when (keyEvent.keyCode) {
                    KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                    KeyEvent.KEYCODE_HEADSETHOOK -> {
                        forward(MediaNotificationManager.ACTION_TOGGLE_PLAY_PAUSE)
                        true
                    }
                    KeyEvent.KEYCODE_MEDIA_PLAY -> {
                        forward(MediaNotificationManager.ACTION_PLAY)
                        true
                    }
                    KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                        forward(MediaNotificationManager.ACTION_PAUSE)
                        true
                    }
                    KeyEvent.KEYCODE_MEDIA_NEXT -> {
                        forward(MediaNotificationManager.ACTION_SKIP_FORWARD)
                        true
                    }
                    KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                        forward(MediaNotificationManager.ACTION_SKIP_BACKWARD)
                        true
                    }
                    else -> super.onMediaButtonEvent(mediaButtonEvent)
                }
            }
        }
    }

    private fun extractKeyEvent(intent: Intent): KeyEvent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
        }
    }
}
