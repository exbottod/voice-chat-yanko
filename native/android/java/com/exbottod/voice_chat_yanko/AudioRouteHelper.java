package com.exbottod.voice_chat_yanko;

import android.content.Context;
import android.media.AudioManager;
import android.os.Build;

/**
 * Helper audio native (Java) untuk voice chat room.
 */
public final class AudioRouteHelper {

    private AudioRouteHelper() {
    }

    public static AudioManager manager(Context context) {
        return (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
    }

    public static String currentRoute(Context context) {
        AudioManager am = manager(context);
        if (am == null) {
            return "unknown";
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (am.isBluetoothScoOn()) {
                return "bluetooth";
            }
            if (am.isSpeakerphoneOn()) {
                return "speaker";
            }
        }
        return "earpiece";
    }

    public static void setSpeakerphone(Context context, boolean on) {
        AudioManager am = manager(context);
        if (am == null) {
            return;
        }
        am.setMode(AudioManager.MODE_IN_COMMUNICATION);
        am.setSpeakerphoneOn(on);
    }
}
