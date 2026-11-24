import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil memilih foto profil dari galeri.
class PickedAvatar {
  const PickedAvatar(this.dataUrl, this.animated);

  /// Format: data:image/<tipe>;base64,<isi>
  final String dataUrl;
  final bool animated;
}

/// Pilih foto dari galeri (jpg, png, webp, gif) lalu ubah ke data URL.
///
/// GIF animasi dibiarkan apa adanya supaya tetap bergerak, dengan batas
/// ukuran. Gambar diam (jpg/png/webp) diperkecil oleh image_picker agar
/// muat di satu dokumen Firestore (batas 1 MB).
class AvatarPicker {
  AvatarPicker._();

  /// Batas ukuran GIF/WebP animasi (byte). Base64 menambah ~33%, dan satu
  /// dokumen Firestore maksimal 1 MiB, jadi 600 KB aman.
  static const int maxAnimatedBytes = 600 * 1024;

  /// Batas akhir untuk gambar diam setelah diperkecil.
  static const int maxStillBytes = 700 * 1024;

  static const Set<String> _allowed = <String>{'jpg', 'jpeg', 'png', 'webp', 'gif'};

  static String _ext(String name) {
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Deteksi format dari isi file (bukan dari nama), karena nama dari galeri
  /// tidak selalu punya ekstensi.
  static String _sniff(Uint8List b) {
    if (b.length > 12) {
      if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'gif';
      if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
        return 'png';
      }
      if (b[0] == 0xFF && b[1] == 0xD8) return 'jpeg';
      if (b[0] == 0x52 &&
          b[1] == 0x49 &&
          b[2] == 0x46 &&
          b[3] == 0x46 &&
          b[8] == 0x57 &&
          b[9] == 0x45 &&
          b[10] == 0x42 &&
          b[11] == 0x50) {
        return 'webp';
      }
    }
    return '';
  }

  /// WebP animasi punya chunk "ANIM" di header.
  static bool _webpAnimated(Uint8List b) {
    final int n = b.length < 64 ? b.length : 64;
    for (int i = 12; i + 3 < n; i++) {
      if (b[i] == 0x41 && b[i + 1] == 0x4E && b[i + 2] == 0x49 && b[i + 3] == 0x4D) {
        return true;
      }
    }
    return false;
  }

  /// Mengembalikan null kalau dibatalkan. Melempar [String] berisi pesan
  /// kalau file tidak didukung atau terlalu besar.
  static Future<PickedAvatar?> pick() async {
    final ImagePicker picker = ImagePicker();
    // Ambil file asli dulu (tanpa kompres) supaya GIF/WebP animasi utuh.
    final XFile? raw = await picker.pickImage(source: ImageSource.gallery);
    if (raw == null) {
      return null;
    }
    Uint8List bytes = await raw.readAsBytes();
    String type = _sniff(bytes);
    if (type.isEmpty) {
      final String e = _ext(raw.name);
      if (!_allowed.contains(e)) {
        throw 'Format tidak didukung. Pakai JPG, PNG, WEBP atau GIF.';
      }
      type = e == 'jpg' ? 'jpeg' : e;
    }

    final bool animated =
        type == 'gif' || (type == 'webp' && _webpAnimated(bytes));

    if (animated) {
      if (bytes.length > maxAnimatedBytes) {
        final int kb = (bytes.length / 1024).round();
        throw 'GIF/WebP animasi terlalu besar ($kb KB). Maksimal 600 KB.';
      }
      return PickedAvatar(
        'data:image/$type;base64,${base64Encode(bytes)}',
        true,
      );
    }

    // Gambar diam: perkecil jadi maksimal 720 px lalu simpan sebagai PNG
    // (kalau ada transparansi) atau JPEG-ish lewat PNG terkompres.
    final Uint8List? kecil = await _resize(bytes, 720);
    if (kecil != null) {
      bytes = kecil;
      type = 'png';
    }
    if (bytes.length > maxStillBytes) {
      final Uint8List? lebihKecil = await _resize(bytes, 480);
      if (lebihKecil != null) {
        bytes = lebihKecil;
        type = 'png';
      }
    }
    if (bytes.length > maxStillBytes) {
      throw 'Foto terlalu besar. Pilih foto lain.';
    }
    return PickedAvatar(
      'data:image/$type;base64,${base64Encode(bytes)}',
      false,
    );
  }

  /// Perkecil gambar diam dengan codec bawaan Flutter (tanpa paket tambahan).
  static Future<Uint8List?> _resize(Uint8List bytes, int sisiMax) async {
    try {
      final ui.Codec probe = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo f0 = await probe.getNextFrame();
      final int w = f0.image.width;
      final int h = f0.image.height;
      f0.image.dispose();
      probe.dispose();
      if (w <= sisiMax && h <= sisiMax && bytes.length <= maxStillBytes) {
        return null;
      }
      final double skala = sisiMax / (w > h ? w : h);
      final int tw = skala < 1 ? (w * skala).round() : w;
      final int th = skala < 1 ? (h * skala).round() : h;
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: tw,
        targetHeight: th,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? out =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return out?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

/// Gambar avatar yang mengerti URL biasa dan data URL (foto upload).
class AvatarImage extends StatelessWidget {
  const AvatarImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    required this.fallback,
  });

  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget fallback;

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  static Uint8List? _decode(String data) {
    final Uint8List? hit = _cache[data];
    if (hit != null) {
      return hit;
    }
    final int comma = data.indexOf(',');
    if (comma < 0) {
      return null;
    }
    try {
      final Uint8List out = base64Decode(data.substring(comma + 1));
      if (_cache.length > 24) {
        _cache.remove(_cache.keys.first);
      }
      _cache[data] = out;
      return out;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? s = source;
    if (s == null || s.isEmpty) {
      return fallback;
    }
    if (s.startsWith('data:image')) {
      final Uint8List? bytes = _decode(s);
      if (bytes == null) {
        return fallback;
      }
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.network(
      s,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
