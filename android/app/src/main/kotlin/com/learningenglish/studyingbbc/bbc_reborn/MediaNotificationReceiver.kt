package com.learningenglish.studyingbbc.bbc_reborn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class MediaNotificationReceiver : BroadcastReceiver() {
    companion object {
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action
        val episodeId = intent?.getStringExtra("episode_id")
        val category = intent?.getStringExtra("category")
        val duration = intent?.getLongExtra("duration", 0L) ?: 0L
        val currentPosition = intent?.getLongExtra("current_position", 0L) ?: 0L
        val timestamp = intent?.getLongExtra("timestamp", 0L) ?: 0L

        // Tạo data map để gửi về Flutter
        val data = mapOf(
            "action" to action,
            "episode_id" to episodeId,
            "category" to category,
            "duration" to duration,
            "current_position" to currentPosition,
            "timestamp" to timestamp
        )

        // Gửi action về Flutter qua Method Channel
        methodChannel?.invokeMethod("onMediaAction", data)
    }
}







