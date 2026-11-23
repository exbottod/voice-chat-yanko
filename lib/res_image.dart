import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'native_bridge.dart';

/// Menampilkan gambar dari res/drawable-nodpi lewat native Android.
class ResImage extends StatelessWidget {
  const ResImage(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String name;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: VoiceNative.loadDrawable(name),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) {
          return SizedBox(width: width, height: height);
        }
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
            return SizedBox(width: width, height: height);
          },
        );
      },
    );
  }
}
