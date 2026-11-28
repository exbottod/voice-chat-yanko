import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

/// Cache berkas SVGA: di memori, di disk, dan hasil dekode filmnya.
///
/// Dulu setiap foto berbingkai mengambil ulang berkas dari Firestore (satu
/// query ditambah beberapa potongan base64) lalu mendekode lagi, jadi bingkai
/// terasa lama muncul. Sekarang berkas disimpan sekali, dipakai bersama semua
/// tempat, dan dibaca dari disk saat aplikasi dibuka lagi.
final Map<String, Uint8List> _byteCache = <String, Uint8List>{};
final Map<String, Future<Uint8List?>> _sedangMuat =
    <String, Future<Uint8List?>>{};

String _kunciAset(String sumber, String id) =>
    id.isNotEmpty ? id : 'u:${sumber.hashCode}';

Future<File?> _berkasCache(String kunci) async {
  try {
    final Directory dasar = await getApplicationSupportDirectory();
    final Directory dir = Directory('${dasar.path}/bingkai');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$kunci.svga');
  } catch (_) {
    return null;
  }
}

/// Film SVGA siap putar.
///
/// Berkasnya diambil dari cache (memori/disk), tapi film hasil dekode dibuat
/// baru untuk tiap tampilan. Sebelumnya satu film dipakai bersama, dan begitu
/// satu tampilan ditutup, gambar di dalamnya ikut hilang sehingga bingkai
/// lenyap saat kembali ke profil atau ke Barangku.
Future<MovieEntity?> muatFilmSvga(String sumber, String id) async {
  final Uint8List? bytes = await muatByteSvga(sumber, id);
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  return _dekodeRingan(bytes);
}

/// Dekode SVGA dengan gambar yang diperkecil.
///
/// Efek masuk bisa berisi 180 frame dan 73 gambar berukuran 712x517. Bila
/// didekode penuh, memori yang dibutuhkan lebih dari 100 MB dan dekode gagal
/// di HP biasa, sehingga efek tampil kosong. Di sini gambar didekode maksimal
/// 256 px lebarnya: cukup tajam untuk kursi, profil, dan pratinjau.
Future<MovieEntity?> _dekodeRingan(Uint8List bytes) async {
  try {
    final List<int> isi = const ZLibDecoder().decodeBytes(bytes);
    final MovieEntity film = MovieEntity.fromBuffer(isi);
    film.autorelease = true;
    final Map<String, List<int>> gambar = film.images;
    if (gambar.isNotEmpty) {
      await Future.wait(gambar.entries.map((MapEntry<String, List<int>> e) async {
        try {
          final ui.Codec kodek = await ui.instantiateImageCodec(
            Uint8List.fromList(e.value),
            targetWidth: 256,
          );
          final ui.FrameInfo bingkai = await kodek.getNextFrame();
          film.bitmapCache[e.key] = bingkai.image;
        } catch (_) {
          // Satu gambar gagal tidak menggagalkan seluruh animasi.
        }
      }));
    }
    return film;
  } catch (_) {
    // Cadangan: cara lama, untuk berkas yang strukturnya tidak biasa.
    try {
      final MovieEntity film = await SVGAParser.shared.decodeFromBuffer(bytes);
      film.autorelease = true;
      return film;
    } catch (_) {
      return null;
    }
  }
}

/// Apakah aset ini animasi SVGA?
bool asetSvga(Map<String, dynamic> d) {
  final String jenis = ((d['mediaType'] ?? '') as String).toLowerCase();
  final String mime = ((d['mime'] ?? '') as String).toLowerCase();
  final String nama = ((d['name'] ?? '') as String).toLowerCase();
  if (jenis == 'svga' || mime.contains('svga') || nama.endsWith('.svga')) {
    return true;
  }
  // Berkas SVGA yang diunggah lewat panel sering tersimpan sebagai
  // application/octet-stream dengan nama tanpa ekstensi, sehingga dulu
  // dianggap gambar biasa dan bingkai tidak muncul sama sekali.
  final String gambar = ((d['image'] ?? '') as String);
  if (mime.isEmpty || mime.contains('octet-stream') || mime.contains('zip')) {
    final int koma = gambar.indexOf(',');
    final String isi = koma >= 0 ? gambar.substring(koma + 1) : gambar;
    // Isi SVGA adalah zlib/gzip, jadi base64-nya mulai dengan penanda ini.
    if (isi.startsWith('eJ') ||
        isi.startsWith('eN') ||
        isi.startsWith('H4sI') ||
        isi.startsWith('eF')) {
      return true;
    }
  }
  // Berkas SVGA yang kini diputar dari URL (mis. Cloudinary).
  if (gambar.startsWith('http') && gambar.toLowerCase().contains('.svga')) {
    return true;
  }
  // Foto kosong tapi ada id aset: berkasnya dipecah di koleksi media (SVGA).
  if (gambar.isEmpty && ((d['itemId'] ?? '') as String).isNotEmpty) {
    return true;
  }
  // Barang di Barangku/equipped yang disalin tanpa mediaType: bila berkasnya
  // dipecah (chunks > 0) dan bukan gambar/video biasa, itu SVGA.
  final num? potong = d['chunks'] as num?;
  if (potong != null &&
      potong > 0 &&
      (mime.isEmpty || mime.contains('octet-stream'))) {
    return true;
  }
  return false;
}

/// Ambil isi berkas SVGA: dari data URL, dari URL http, atau dari potongan
/// dokumen di koleksi `svip_assets_media` (berkas besar dipecah oleh panel).
Future<Uint8List?> muatByteSvga(String sumber, String id) {
  final String kunci = _kunciAset(sumber, id);
  final Uint8List? sudah = _byteCache[kunci];
  if (sudah != null) {
    return Future<Uint8List?>.value(sudah);
  }
  final Future<Uint8List?>? jalan = _sedangMuat[kunci];
  if (jalan != null) {
    // Banyak foto berbingkai di satu layar memakai satu unduhan yang sama.
    return jalan;
  }
  final Future<Uint8List?> baru = _muatSekali(sumber, id, kunci);
  _sedangMuat[kunci] = baru;
  return baru.whenComplete(() => _sedangMuat.remove(kunci));
}

Future<Uint8List?> _muatSekali(String sumber, String id, String kunci) async {
  try {
    if (sumber.startsWith('data:')) {
      final int koma = sumber.indexOf(',');
      if (koma < 0) {
        return null;
      }
      final Uint8List bytes = base64Decode(sumber.substring(koma + 1));
      _byteCache[kunci] = bytes;
      return bytes;
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
      final Uint8List bytes = Uint8List.fromList(isi);
      _byteCache[kunci] = bytes;
      return bytes;
    }
    if (id.isEmpty) {
      return null;
    }
    // Sudah pernah diunduh: baca dari disk, tidak perlu jaringan sama sekali.
    final File? berkas = await _berkasCache(kunci);
    if (berkas != null && await berkas.exists()) {
      final Uint8List bytes = await berkas.readAsBytes();
      if (bytes.isNotEmpty) {
        _byteCache[kunci] = bytes;
        return bytes;
      }
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
    final Uint8List bytes = base64Decode(gabung);
    _byteCache[kunci] = bytes;
    if (berkas != null) {
      try {
        await berkas.writeAsBytes(bytes, flush: false);
      } catch (_) {}
    }
    return bytes;
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final SVGAAnimationController _kontrol;
  bool _siap = false;
  bool _gagal = false;
  int _versi = 0;

  @override
  void initState() {
    super.initState();
    _kontrol = SVGAAnimationController(vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _muat();
  }

  @override
  void didUpdateWidget(covariant SvgaAnimasi lama) {
    super.didUpdateWidget(lama);
    if (lama.sumber != widget.sumber || lama.id != widget.id) {
      _muat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Saat halaman kembali terlihat (mis. balik dari profil orang lain),
    // animasi dipaksa jalan lagi. Tanpa ini bingkai diam walau gambarnya ada.
    _putarUlang();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _putarUlang();
    }
  }

  void _putarUlang() {
    if (!mounted || !_siap) {
      return;
    }
    if (!TickerMode.of(context)) {
      return;
    }
    try {
      if (!_kontrol.isAnimating) {
        _kontrol.repeat();
      }
    } catch (_) {}
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
    // Film diambil dari cache: yang sudah pernah diputar tampil seketika.
    final MovieEntity? film =
        await muatFilmSvga(widget.sumber, widget.id);
    if (!mounted || versi != _versi) {
      return;
    }
    if (film == null) {
      setState(() => _gagal = true);
      return;
    }
    try {
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
    WidgetsBinding.instance.removeObserver(this);
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
