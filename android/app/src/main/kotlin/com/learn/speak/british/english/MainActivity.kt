package com.learn.speak.british.english

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "broadcast_receiver"
    private val MEDIA_CHANNEL = "media_notification"
    private val TAG = "MediaNotification"

    private lateinit var broadcastReceiverHandler: BroadcastReceiverHandler
    private lateinit var mediaNotificationManager: MediaNotificationManager
    private var mediaChannel: MethodChannel? = null
    private var foregroundActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)

        MediaPlaybackController.initialize(this) { action, extras ->
            forwardMediaAction(action, extras)
        }

        mediaNotificationManager = MediaNotificationManager(this)
        mediaNotificationManager.useSharedMediaSession()

        MediaNotificationReceiver.setMethodChannel(mediaChannel!!)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        broadcastReceiverHandler = BroadcastReceiverHandler(this, channel)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    broadcastReceiverHandler.initialize()
                    result.success(null)
                }
                "registerReceiver" -> {
                    val action = call.argument<String>("action")
                    if (action != null) {
                        broadcastReceiverHandler.registerReceiver(action)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Action cannot be null", null)
                    }
                }
                "unregisterReceiver" -> {
                    broadcastReceiverHandler.unregisterReceiver()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        mediaChannel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "showNotification" -> {
                        if (!canPostNotifications()) {
                            result.error(
                                "PERMISSION_DENIED",
                                "POST_NOTIFICATIONS permission not granted",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val notification = buildNotificationFromCall(call)
                        AudioPlaybackForegroundService.start(this, notification)
                        MediaPlaybackController.setActive(true)
                        foregroundActive = true
                        result.success(null)
                    }
                    "updateNotification" -> {
                        if (!canPostNotifications()) {
                            result.error(
                                "PERMISSION_DENIED",
                                "POST_NOTIFICATIONS permission not granted",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val notification = buildNotificationFromCall(call)
                        if (foregroundActive) {
                            AudioPlaybackForegroundService.update(this, notification)
                        } else {
                            AudioPlaybackForegroundService.start(this, notification)
                            foregroundActive = true
                        }
                        MediaPlaybackController.setActive(true)
                        result.success(null)
                    }
                    "hideNotification" -> {
                        AudioPlaybackForegroundService.stop(this)
                        mediaNotificationManager.hideNotification()
                        MediaPlaybackController.setActive(false)
                        foregroundActive = false
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Media notification error: ${call.method}", e)
                result.error("NOTIFICATION_ERROR", e.message, null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dispatchMediaButtonIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchMediaButtonIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun dispatchMediaButtonIntent(intent: Intent?) {
        MediaPlaybackController.dispatchMediaButtonIntent(intent)
    }

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun buildNotificationFromCall(call: io.flutter.plugin.common.MethodCall): android.app.Notification {
        val title = call.argument<String>("title") ?: "BBC Learning English"
        val content = call.argument<String>("content") ?: "Đang phát audio"
        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
        val episodeId = call.argument<String>("episodeId")
        val category = call.argument<String>("category")
        val duration = readLongArg(call, "duration")
        val currentPosition = readLongArg(call, "currentPosition")
        val thumbImageUrl = call.argument<String>("thumbImageUrl")
        val thumbImageLocalPath = call.argument<String>("thumbImageLocalPath")

        return mediaNotificationManager.createNotification(
            title,
            content,
            isPlaying,
            episodeId,
            category,
            duration,
            currentPosition,
            thumbImageUrl,
            thumbImageLocalPath
        )
    }

    private fun readLongArg(call: io.flutter.plugin.common.MethodCall, key: String): Long {
        val value = call.argument<Any>(key) ?: return 0L
        return when (value) {
            is Int -> value.toLong()
            is Long -> value
            is Number -> value.toLong()
            else -> 0L
        }
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent?.getStringExtra("action") != "open_player") return

        val episodeId = intent.getStringExtra("episode_id")
        val category = intent.getStringExtra("category")
        if (episodeId.isNullOrBlank()) return

        mediaChannel?.invokeMethod(
            "onNotificationTap",
            mapOf(
                "episode_id" to episodeId,
                "category" to category
            )
        )
    }

    private fun forwardMediaAction(action: String, extras: Map<String, Any?>) {
        val payload = mutableMapOf<String, Any?>(
            "action" to action,
        )
        payload.putAll(extras)
        mediaChannel?.invokeMethod("onMediaAction", payload)
    }

    override fun onDestroy() {
        super.onDestroy()
        broadcastReceiverHandler.unregisterReceiver()
        if (isFinishing) {
            AudioPlaybackForegroundService.stop(this)
            mediaNotificationManager.hideNotification()
            MediaPlaybackController.setActive(false)
        }
    }
}
