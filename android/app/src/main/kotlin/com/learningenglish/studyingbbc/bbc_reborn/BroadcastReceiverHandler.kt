package com.learningenglish.studyingbbc.bbc_reborn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.plugin.common.MethodChannel

class BroadcastReceiverHandler(private val context: Context, private val channel: MethodChannel) {
    private var broadcastReceiver: BroadcastReceiver? = null

    fun initialize() {
        // Khởi tạo broadcast receiver
    }

    fun registerReceiver(action: String) {
        unregisterReceiver() // Hủy đăng ký trước nếu có

        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == action) {
                    // Gửi dữ liệu về Flutter
                    val data = mutableMapOf<String, Any>()
                    data["action"] = intent.action ?: ""
                    data["timestamp"] = System.currentTimeMillis()
                    
                    // Lấy extras từ intent
                    intent.extras?.let { extras ->
                        for (key in extras.keySet()) {
                            val value = extras.get(key)
                            data[key] = value?.toString() ?: ""
                        }
                    }

                    channel.invokeMethod("onBroadcastReceived", data)
                }
            }
        }

        val filter = IntentFilter(action)
        context.registerReceiver(broadcastReceiver, filter)
    }

    fun unregisterReceiver() {
        broadcastReceiver?.let {
            context.unregisterReceiver(it)
            broadcastReceiver = null
        }
    }
}

















