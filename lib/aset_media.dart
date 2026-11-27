import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'svga_view.dart';

/// Jenis berkas aset (gift, bingkai, efek) dari kolom mediaType/mime/nama.
/// Gift boleh berupa SVGA, MP4, GIF, WEBP, PNG, atau JPG.
String jenisAset(Map<String, dynamic> d) {
  final String jenis =
      ((d['mediaType'] ?? d['jenis'] ?? '') as String).toLowerCase();
  final String mime = ((d['mime'] ?? '') as String).toLowerCase();
  final String nama = ((d['name'] ?? d['nama'] ?? '') as String).toLowerCase();
  String semua = '$jenis $mime $nama';
  final String sumber = sumberAset(d).toLowerCase();
  semua = '$semua $sumber';
  if (semua.contains('svga')) {
    return 'svga';
  }
  if (semua.contains('mp4') || semua.contains('video/') || semua.contains('webm')) {
    return 'mp4';
  }
  if (semua.contains('.gif') || semua.contains('image/gif')) {
    return 'gif';
  }
  if (semua.contains('.webp') || semua.contains('image/webp')) {
    return 'webp';
  }
  if (semua.contains('.png') || semua.contains('image/png')) {
    return 'png';
  }
  return 'jpg';
}

/// Alamat berkas aset: url, data URL, atau penanda potongan dokumen.
String sumberAset(Map<String, dynamic> d) {
  for (final String k in <String>[
    'url',
    'sumber',
    'src',
    'link',
    'file',
    'gif',
    'image',
    'media',
    'animasi',
  ]) {
    final Object? v = d[k];
    if (v is String && v.isNotEmpty) {
      return v;
    }
  }
  return '';
}

/// Id aset, dipakai untuk mengambil berkas yang dipecah di `svip_assets_media`.
String idAset(Map<String, dynamic> d) =>
    ((d['id'] ?? d['assetId'] ?? d['giftId'] ?? '') as String?) ?? '';

/// Pemutar aset serbaguna: SVGA, MP4, GIF, WEBP, PNG, JPG.
class AsetMedia extends StatelessWidget {
  const AsetMedia({
    super.key,
    required this.sumber,
    this.id = '',
    this.jenis = '',
    this.fit = BoxFit.contain,
    this.loop = true,
    this.fallback,
  });

  /// Pemutar dari dokumen aset apa adanya.
  factory AsetMedia.dari(
    Map<String, dynamic> d, {
    Key? key,
    BoxFit fit = BoxFit.contain,
    bool loop = true,
    Widget? fallback,
  }) {
    return AsetMedia(
      key: key,
      sumber: sumberAset(d),
      id: idAset(d),
      jenis: jenisAset(d),
      fit: fit,
      loop: loop,
      fallback: fallback,
    );
  }

  final String sumber;
  final String id;
  final String jenis;
  final BoxFit fit;
  final bool loop;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final String j = jenis.isNotEmpty ? jenis : 'jpg';
    if (j == 'svga') {
      return SvgaAnimasi(sumber: sumber, id: id, fit: fit, fallback: fallback);
    }
    if (j == 'mp4') {
      return VideoAset(
        sumber: sumber,
        id: id,
        fit: fit,
        loop: loop,
        fallback: fallback,
      );
    }
    return GambarAset(
      sumber: sumber,
      id: id,
      fit: fit,
      fallback: fallback,
    );
  }
}

/// Gambar diam atau animasi GIF/WEBP. Flutter sudah memutar GIF dan WEBP
/// sendiri, jadi tidak perlu pustaka tambahan.
class GambarAset extends StatelessWidget {
  const GambarAset({
    super.key,
    required this.sumber,
    this.id = '',
    this.fit = BoxFit.contain,
    this.fallback,
  });

  final String sumber;
  final String id;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final Widget gagal = fallback ?? const SizedBox.shrink();
    if (sumber.isEmpty) {
      return gagal;
    }
    if (sumber.startsWith('data:')) {
      final int koma = sumber.indexOf(',');
      if (koma < 0) {
        return gagal;
      }
      try {
        return Image.memory(
          base64Decode(sumber.substring(koma + 1)),
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (BuildContext c, Object e, StackTrace? s) => gagal,
        );
      } catch (_) {
        return gagal;
      }
    }
    if (sumber.startsWith('http')) {
      return Image.network(
        sumber,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (BuildContext c, Object e, StackTrace? s) => gagal,
      );
    }
    return gagal;
  }
}

/// Pemutar MP4 yang berulang tanpa suara, dipakai untuk gift dan efek.
class VideoAset extends StatefulWidget {
  const VideoAset({
    super.key,
    required this.sumber,
    this.id = '',
    this.fit = BoxFit.contain,
    this.loop = true,
    this.fallback,
  });

  final String sumber;
  final String id;
  final BoxFit fit;
  final bool loop;
  final Widget? fallback;

  @override
  State<VideoAset> createState() => _VideoAsetState();
}

class _VideoAsetState extends State<VideoAset> {
  VideoPlayerController? _kontrol;
  bool _gagal = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void didUpdateWidget(covariant VideoAset lama) {
    super.didUpdateWidget(lama);
    if (lama.sumber != widget.sumber || lama.id != widget.id) {
      _muat();
    }
  }

  Future<void> _muat() async {
    await _kontrol?.dispose();
    _kontrol = null;
    _gagal = false;
    if (widget.sumber.isEmpty) {
      if (mounted) {
        setState(() => _gagal = true);
      }
      return;
    }
    try {
      final VideoPlayerController k =
          VideoPlayerController.networkUrl(Uri.parse(widget.sumber));
      await k.initialize();
      await k.setVolume(0);
      await k.setLooping(widget.loop);
      await k.play();
      if (!mounted) {
        await k.dispose();
        return;
      }
      setState(() => _kontrol = k);
    } catch (_) {
      if (mounted) {
        setState(() => _gagal = true);
      }
    }
  }

  @override
  void dispose() {
    _kontrol?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? k = _kontrol;
    if (k == null || _gagal) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    return FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: k.value.size.width,
        height: k.value.size.height,
        child: VideoPlayer(k),
      ),
    );
  }
}
