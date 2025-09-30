package com.learningenglish.studyingbbc.bbc_reborn

import android.media.session.MediaSession
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "broadcast_receiver"
    private val MEDIA_CHANNEL = "media_notification"
    private lateinit var broadcastReceiverHandler: BroadcastReceiverHandler
    private lateinit var mediaNotificationManager: MediaNotificationManager
    private lateinit var mediaSession: MediaSession

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Khởi tạo MediaSession
        mediaSession = MediaSession(this, "BBCLearningEnglish")
        mediaSession.setActive(true)
        
        // Khởi tạo MediaNotificationManager
        mediaNotificationManager = MediaNotificationManager(this)
        mediaNotificationManager.setMediaSession(mediaSession)
        
        // Cấu hình MediaNotificationReceiver
        MediaNotificationReceiver.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
        )
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
        
        broadcastReceiverHandler = BroadcastReceiverHandler(this, channel)
        
        // Xử lý broadcast receiver calls
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
        
        // Xử lý media notification calls
        mediaChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "BBC Learning English"
                    val content = call.argument<String>("content") ?: "Đang phát audio"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val episodeId = call.argument<String>("episodeId")
                    val category = call.argument<String>("category")
                    val duration = call.argument<Long>("duration") ?: 0L
                    val currentPosition = call.argument<Long>("currentPosition") ?: 0L
                    
                    val notification = mediaNotificationManager.createNotification(
                        title, content, isPlaying, episodeId, category, duration, currentPosition
                    )
                    mediaNotificationManager.showNotification(notification)
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "BBC Learning English"
                    val content = call.argument<String>("content") ?: "Đang phát audio"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val episodeId = call.argument<String>("episodeId")
                    val category = call.argument<String>("category")
                    val duration = call.argument<Long>("duration") ?: 0L
                    val currentPosition = call.argument<Long>("currentPosition") ?: 0L
                    
                    val notification = mediaNotificationManager.createNotification(
                        title, content, isPlaying, episodeId, category, duration, currentPosition
                    )
                    mediaNotificationManager.showNotification(notification)
                    result.success(null)
                }
                "hideNotification" -> {
                    mediaNotificationManager.hideNotification()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        broadcastReceiverHandler.unregisterReceiver()
        mediaNotificationManager.hideNotification()
        mediaSession.release()
    }
}
