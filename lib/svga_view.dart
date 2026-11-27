import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:svgaplayer_3/svgaplayer_flutter.dart';

/// Apakah aset ini animasi SVGA?
bool asetSvga(Map<String, dynamic> d) {
  final String jenis = ((d['mediaType'] ?? '') as String).toLowerCase();
  final String mime = ((d['mime'] ?? '') as String).toLowerCase();
  final String nama = ((d['name'] ?? '') as String).toLowerCase();
  return jenis == 'svga' || mime.contains('svga') || nama.endsWith('.svga');
}

/// Ambil isi berkas SVGA: dari data URL, dari URL http, atau dari potongan
/// dokumen di koleksi `svip_assets_media` (berkas besar dipecah oleh panel).
Future<Uint8List?> muatByteSvga(String sumber, String id) async {
  try {
    if (sumber.startsWith('data:')) {
      final int koma = sumber.indexOf(',');
      if (koma < 0) {
        return null;
      }
      return base64Decode(sumber.substring(koma + 1));
    }
    if (sumber.startsWith('http')) {
      final HttpClient klien = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final HttpClientRequest req = await klien.getUrl(Uri.parse(sumber));
      final HttpClientResponse res = await req.close();
      if (res.statusCode != 200) {
        return null;
      }
      final List<int> isi = <int>[];
      await for (final List<int> bagian in res) {
        isi.addAll(bagian);
      }
      klien.close();
      return Uint8List.fromList(isi);
    }
    if (id.isEmpty) {
      return null;
    }
    final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore
        .instance
        .collection('svip_assets_media')
        .where('assetId', isEqualTo: id)
        .get();
    if (q.docs.isEmpty) {
      return null;
    }
    final List<Map<String, dynamic>> bagian =
        q.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.data())
            .toList()
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
              ((a['i'] as num?) ?? 0).compareTo((b['i'] as num?) ?? 0));
    final String gabung = bagian
        .map((Map<String, dynamic> e) => (e['data'] as String?) ?? '')
        .join();
    if (gabung.isEmpty) {
      return null;
    }
    return base64Decode(gabung);
  } catch (_) {
    return null;
  }
}

/// Pemutar animasi SVGA. Memuat sendiri berkasnya lalu memutar berulang.
class SvgaAnimasi extends StatefulWidget {
  const SvgaAnimasi({
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
  State<SvgaAnimasi> createState() => _SvgaAnimasiState();
}

class _SvgaAnimasiState extends State<SvgaAnimasi>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _kontrol;
  bool _siap = false;
  bool _gagal = false;
  int _versi = 0;

  @override
  void initState() {
    super.initState();
    _kontrol = SVGAAnimationController(vsync: this);
    _muat();
  }

  @override
  void didUpdateWidget(covariant SvgaAnimasi lama) {
    super.didUpdateWidget(lama);
    if (lama.sumber != widget.sumber || lama.id != widget.id) {
      _muat();
    }
  }

  Future<void> _muat() async {
    final int versi = ++_versi;
    if (!mounted) {
      return;
    }
    setState(() {
      _siap = false;
      _gagal = false;
    });
    final Uint8List? bytes = await muatByteSvga(widget.sumber, widget.id);
    if (!mounted || versi != _versi) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() => _gagal = true);
      return;
    }
    try {
      final MovieEntity film = await SVGAParser.shared.decodeFromBuffer(bytes);
      if (!mounted || versi != _versi) {
        return;
      }
      _kontrol.videoItem = film;
      setState(() => _siap = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        try {
          _kontrol.repeat();
        } catch (_) {}
      });
    } catch (_) {
      if (mounted) {
        setState(() => _gagal = true);
      }
    }
  }

  @override
  void dispose() {
    _versi++;
    _kontrol.stop();
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gagal || !_siap) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext c, BoxConstraints batas) {
        final double lebar = batas.hasBoundedWidth
            ? batas.maxWidth
            : (batas.maxHeight.isFinite ? batas.maxHeight : 120);
        final double tinggi =
            batas.hasBoundedHeight ? batas.maxHeight : lebar;
        final Size ukuran = Size(lebar, tinggi);
        return SizedBox(
          width: ukuran.width,
          height: ukuran.height,
          child: SVGAImage(
            _kontrol,
            fit: widget.fit,
            clearsAfterStop: false,
            preferredSize: ukuran,
            allowDrawingOverflow: false,
          ),
        );
      },
    );
  }
}
