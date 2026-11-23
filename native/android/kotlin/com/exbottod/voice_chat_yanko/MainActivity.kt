package com.exbottod.voice_chat_yanko

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VoiceChannelBridge(applicationContext)
            .register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
