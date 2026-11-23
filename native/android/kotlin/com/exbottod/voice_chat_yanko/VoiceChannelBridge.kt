package com.exbottod.voice_chat_yanko

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Jembatan MethodChannel antara Flutter (Dart) dan kode native Android.
 * Semua logika perangkat keras audio didelegasikan ke AudioRouteHelper (Java).
 */
class VoiceChannelBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "yanko/voice"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "getAudioRoute" -> result.success(AudioRouteHelper.currentRoute(context))
                "setSpeakerphone" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    AudioRouteHelper.setSpeakerphone(context, on)
                    result.success(true)
                }
                "ping" -> result.success("pong")
                else -> result.notImplemented()
            }
        }
    }
}
