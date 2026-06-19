package com.learning.eslenglish

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class AudioPlaybackForegroundService : Service() {
    companion object {
        private const val ACTION_START = "start"
        private const val ACTION_UPDATE = "update"
        private const val ACTION_STOP = "stop"

        @Volatile
        private var pendingNotification: Notification? = null

        fun start(context: Context, notification: Notification) {
            pendingNotification = notification
            val intent = Intent(context, AudioPlaybackForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, notification: Notification) {
            pendingNotification = notification
            val intent = Intent(context, AudioPlaybackForegroundService::class.java).apply {
                action = ACTION_UPDATE
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, AudioPlaybackForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val notification = pendingNotification
                if (notification != null) {
                    startForeground(MediaNotificationManager.NOTIFICATION_ID, notification)
                    MediaPlaybackController.setActive(true)
                } else {
                    stopSelf()
                }
            }
            ACTION_UPDATE -> {
                val notification = pendingNotification
                if (notification != null) {
                    startForeground(MediaNotificationManager.NOTIFICATION_ID, notification)
                    val manager =
                        getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                    manager.notify(MediaNotificationManager.NOTIFICATION_ID, notification)
                    MediaPlaybackController.setActive(true)
                }
            }
            ACTION_STOP -> {
                MediaPlaybackController.setActive(false)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }
}
