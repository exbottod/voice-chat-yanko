import 'package:flutter/services.dart';

/// Akses ke kode native Android (Kotlin + Java) lewat MethodChannel.
class VoiceNative {
  static const MethodChannel _channel = MethodChannel('yanko/voice');

  static Future<String> currentRoute() async {
    try {
      final String? route = await _channel.invokeMethod<String>('getAudioRoute');
      return route ?? 'unknown';
    } on PlatformException {
      return 'unknown';
    } on MissingPluginException {
      return 'unknown';
    }
  }

  static Future<void> setSpeakerphone(bool on) async {
    try {
      await _channel.invokeMethod<bool>(
        'setSpeakerphone',
        <String, dynamic>{'on': on},
      );
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
