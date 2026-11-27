import 'dart:typed_data';

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

  static final Map<String, Uint8List> _drawableCache = <String, Uint8List>{};

  /// Ambil gambar dari res/drawable-nodpi sebagai byte PNG.
  /// Gambar yang sudah pernah diambil, langsung dari cache tanpa menunggu.
  static Uint8List? drawableCached(String name) => _drawableCache[name];

  static Future<Uint8List?> loadDrawable(String name) async {
    final Uint8List? cached = _drawableCache[name];
    if (cached != null) {
      return cached;
    }
    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
        'loadDrawable',
        <String, dynamic>{'name': name},
      );
      if (bytes != null) {
        _drawableCache[name] = bytes;
      }
      return bytes;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> setMicMuted(bool muted) async {
    try {
      final bool? ok = await _channel
          .invokeMethod<bool>('setMicMuted', <String, dynamic>{'muted': muted});
      return ok ?? false;
    } catch (_) {
      return false;
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
