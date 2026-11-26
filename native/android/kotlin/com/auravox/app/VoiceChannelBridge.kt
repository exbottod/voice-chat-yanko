package com.auravox.app

import android.content.Context
import android.media.AudioManager
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

    /** Baca gambar dari res/drawable-nodpi lalu kirim ke Flutter sebagai byte PNG. */
    private fun loadDrawableBytes(name: String): ByteArray? {
        if (name.isEmpty()) {
            return null
        }
        // Nama package di resources.arsc bisa berbeda dari applicationId
        // (misalnya setelah rebrand), jadi cari tanpa package dulu lalu
        // fallback ke applicationId.
        var resId = context.resources.getIdentifier(name, "drawable", null)
        if (resId == 0) {
            resId = context.resources.getIdentifier(name, "drawable", context.packageName)
        }
        if (resId == 0) {
            return null
        }
        val bitmap = android.graphics.BitmapFactory.decodeResource(context.resources, resId)
            ?: return null
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
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
                "loadDrawable" -> {
                    val name = call.argument<String>("name") ?: ""
                    val bytes = loadDrawableBytes(name)
                    if (bytes == null) {
                        result.error("not_found", "drawable $name tidak ditemukan", null)
                    } else {
                        result.success(bytes)
                    }
                }
                "setMicMuted" -> {
                    val muted = call.argument<Boolean>("muted") ?: false
                    try {
                        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        am.isMicrophoneMute = muted
                        result.success(muted)
                    } catch (e: Exception) {
                        result.error("mic_failed", e.message, null)
                    }
                }
                "ping" -> result.success("pong")
                else -> result.notImplemented()
            }
        }
    }
}
