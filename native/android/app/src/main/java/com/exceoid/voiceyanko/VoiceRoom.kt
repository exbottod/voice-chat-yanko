package com.exceoid.voiceyanko

import com.auravox.app.BuildConfig
import com.auravox.app.R

import android.content.Context
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig

/** Suara room memakai Agora. Nonaktif bila App ID belum diisi. */
object VoiceRoom {
    private var engine: RtcEngine? = null
    var channel: String? = null
        private set

    val ready: Boolean get() = BuildConfig.AGORA_APP_ID.isNotBlank()

    fun init(context: Context) {
        if (engine != null || !ready) return
        try {
            val config = RtcEngineConfig().apply {
                mContext = context.applicationContext
                mAppId = BuildConfig.AGORA_APP_ID
                mEventHandler = object : IRtcEngineEventHandler() {}
            }
            engine = RtcEngine.create(config).also { e ->
                e.enableAudio()
                e.setChannelProfile(Constants.CHANNEL_PROFILE_LIVE_BROADCASTING)
                e.setClientRole(Constants.CLIENT_ROLE_BROADCASTER)
                e.enableLocalAudio(true)
            }
        } catch (_: Throwable) {
            engine = null
        }
    }

    fun join(roomId: String, uid: String) {
        val e = engine ?: return
        if (channel == roomId) return
        leave()
        val options = ChannelMediaOptions().apply {
            clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
            channelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
            publishMicrophoneTrack = true
            autoSubscribeAudio = true
        }
        try {
            e.joinChannel("", roomId, (uid.hashCode() and 0x7fffffff), options)
            channel = roomId
        } catch (_: Throwable) {
        }
    }

    fun setMic(on: Boolean) {
        engine?.enableLocalAudio(on)
        engine?.muteLocalAudioStream(!on)
    }

    fun leave() {
        val e = engine ?: return
        try {
            e.leaveChannel()
        } catch (_: Throwable) {
        }
        channel = null
    }
}
