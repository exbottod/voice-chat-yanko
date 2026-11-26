import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lang.dart';

/// Pembaruan aplikasi: cek versi terbaru, unduh file selisih kecil (~1 MB),
/// gabungkan dengan APK yang terpasang, lalu buka pemasang Android.
/// Kalau patch tidak tersedia atau gagal, otomatis pakai unduhan APK penuh.
class UpdateService {
  UpdateService._();

  static const String manifestUrl = 'https://voiceyanko.web.app/latest.json';
  static const String patchInfoUrl = 'https://voiceyanko.web.app/patch-info.json';
  static const String patchBase = 'https://voiceyanko.web.app/patch/';

  static const MethodChannel _channel = MethodChannel('yanko/update');

  static const Color card = Color(0xFF17171A);
  static const Color gold = Color(0xFFFFC82E);
  static const Color line = Color(0xFF6B5A1E);
  static const Color ink = Color(0xFFD9D9DE);

  static List<int> _parts(String value) {
    return value
        .split('.')
        .map((String part) =>
            int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  /// Bandingkan nama versi (1.0.69), bukan versionCode: APK split per ABI
  /// punya versionCode berbeda (armv7 1000+x, arm64 2000+x, x86_64 3000+x).
  static bool isNewer(String remote, String current) {
    if (remote.isEmpty || current.isEmpty) {
      return false;
    }
    final List<int> r = _parts(remote);
    final List<int> c = _parts(current);
    final int len = r.length > c.length ? r.length : c.length;
    for (int i = 0; i < len; i++) {
      final int rv = i < r.length ? r[i] : 0;
      final int cv = i < c.length ? c[i] : 0;
      if (rv != cv) {
        return rv > cv;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>?> _getJson(String url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      // Penanda waktu agar CDN tidak menyajikan versi lama.
      final String bust = url.contains('?')
          ? '$url&v=${DateTime.now().millisecondsSinceEpoch}'
          : '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      final HttpClientRequest req = await client.getUrl(Uri.parse(bust));
      req.headers.set('Cache-Control', 'no-cache, no-store');
      req.headers.set('Pragma', 'no-cache');
      final HttpClientResponse res = await req.close();
      if (res.statusCode != 200) {
        return null;
      }
      final String body = await res.transform(utf8.decoder).join();
      final Object? data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Cari file selisih untuk versi yang terpasang, atau null kalau tidak ada.
  static Future<Map<String, dynamic>?> _findPatch(
      String versiBaru, String versiTerpasang) async {
    final Map<String, dynamic>? data = await _getJson(patchInfoUrl);
    if (data == null) {
      return null;
    }
    final List<dynamic> list =
        (data['patch'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic item in list) {
      if (item is! Map) {
        continue;
      }
      if (item['dari'] == versiTerpasang && item['ke'] == versiBaru) {
        final Object? arm = item['arm64'];
        if (arm is Map && (arm['file'] as String?)?.isNotEmpty == true) {
          return <String, dynamic>{
            'url': patchBase + (arm['file'] as String),
            'size': (arm['ukuran'] as num?)?.toInt() ?? 0,
            'sha256': (arm['sha256'] as String?) ?? '',
          };
        }
      }
    }
    return null;
  }

  static Future<void> check(BuildContext context) async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final Map<String, dynamic>? manifest = await _getJson(manifestUrl);
      if (manifest == null) {
        return;
      }
      final String versionName = (manifest['versionName'] as String?) ?? '';
      if (!isNewer(versionName, info.version)) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getString('skippedVersion') == versionName) {
        final int at = prefs.getInt('skippedAt') ?? 0;
        final bool recent = DateTime.now().millisecondsSinceEpoch - at <
            const Duration(hours: 24).inMilliseconds;
        if (recent) {
          return;
        }
      }
      final Map<String, dynamic>? patch =
          await _findPatch(versionName, info.version);
      final String apkUrl = (manifest['apkUrl'] as String?) ?? '';
      if (apkUrl.isEmpty || !context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (BuildContext ctx) => UpdateDialog(
          versionName: versionName,
          notes: ((manifest['notes'] as String?) ?? '').trim(),
          apkUrl: apkUrl,
          apkSize: (manifest['apkSize'] as num?)?.toInt() ?? 0,
          patch: patch,
        ),
      );
    } catch (_) {
      // Diam saja kalau offline atau server tidak bisa dihubungi.
    }
  }
}

/// Dialog pembaruan dengan bilah kemajuan 0-100% lalu pemasang Android.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    this.patch,
  });

  final String versionName;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final Map<String, dynamic>? patch;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Tahap { siap, unduh, gabung, pasang, izin, gagal }

class _UpdateDialogState extends State<UpdateDialog> {
  _Tahap _tahap = _Tahap.siap;
  double _progress = 0;
  String _pesan = '';
  String? _apkSiap;

  String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  int get _patchSize => (widget.patch?['size'] as int?) ?? 0;

  bool get _adaPatch => widget.patch != null;

  Future<void> _nanti() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('skippedVersion', widget.versionName);
    await prefs.setInt(
        'skippedAt', DateTime.now().millisecondsSinceEpoch);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<Directory> _folder() async {
    final Directory tmp = await getTemporaryDirectory();
    final Directory dir = Directory('${tmp.path}/update');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File?> _unduh(
      String url, File target, int ukuranHarapan, void Function(double) onP) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.headers.set('Cache-Control', 'no-cache');
      final HttpClientResponse res = await req.close();
      if (res.statusCode != 200) {
        return null;
      }
      final int total =
          res.contentLength > 0 ? res.contentLength : ukuranHarapan;
      if (await target.exists()) {
        await target.delete();
      }
      sink = target.openWrite();
      int sudah = 0;
      await for (final List<int> chunk in res) {
        sink.add(chunk);
        sudah += chunk.length;
        if (total > 0) {
          onP((sudah / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (ukuranHarapan > 0 && sudah < ukuranHarapan) {
        return null;
      }
      return target;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  Future<String> _sha256(File file) async {
    final Digest d = await sha256.bind(file.openRead()).first;
    return d.toString();
  }

  /// Alur utama: patch kecil dulu, gagal -> APK penuh.
  Future<void> _mulai() async {
    setState(() {
      _tahap = _Tahap.unduh;
      _progress = 0;
      _pesan = '';
    });
    final Directory dir = await _folder();

    if (_adaPatch) {
      final String url = widget.patch!['url'] as String;
      final int size = _patchSize;
      final String sha = (widget.patch!['sha256'] as String?) ?? '';
      final File patchFile = File('${dir.path}/patch.bin');
      final File? unduhan = await _unduh(url, patchFile, size, (double p) {
        if (mounted) {
          setState(() => _progress = p);
        }
      });
      if (unduhan == null) {
        await _unduhPenuh(dir);
        return;
      }
      if (mounted) {
        setState(() {
          _tahap = _Tahap.gabung;
          _progress = 1;
        });
      }
      final File hasil = File('${dir.path}/update.apk');
      bool ok = false;
      try {
        ok = await UpdateService._channel.invokeMethod<bool>('applyPatch',
                <String, String>{
                  'old': await _apkTerpasang(),
                  'patch': patchFile.path,
                  'out': hasil.path,
                }) ??
            false;
      } catch (_) {
        ok = false;
      }
      if (!ok || !await hasil.exists()) {
        await _unduhPenuh(dir);
        return;
      }
      if (sha.isNotEmpty) {
        final String hasilSha = await _sha256(hasil);
        if (hasilSha != sha) {
          await _unduhPenuh(dir);
          return;
        }
      }
      try {
        await patchFile.delete();
      } catch (_) {}
      _apkSiap = hasil.path;
      await _pasang();
      return;
    }
    await _unduhPenuh(dir);
  }

  Future<String> _apkTerpasang() async {
    final String path =
        await UpdateService._channel.invokeMethod<String>('apkPath') ?? '';
    return path;
  }

  Future<void> _unduhPenuh(Directory dir) async {
    if (mounted) {
      setState(() {
        _tahap = _Tahap.unduh;
        _progress = 0;
        _pesan = 'Unduhan penuh';
      });
    }
    final File target = File('${dir.path}/update.apk');
    final File? file = await _unduh(widget.apkUrl, target, widget.apkSize,
        (double p) {
      if (mounted) {
        setState(() => _progress = p);
      }
    });
    if (file == null) {
      if (mounted) {
        setState(() {
          _tahap = _Tahap.gagal;
          _pesan = 'Unduhan gagal. Periksa koneksi lalu coba lagi.';
        });
      }
      return;
    }
    _apkSiap = file.path;
    await _pasang();
  }

  Future<void> _pasang() async {
    if (mounted) {
      setState(() {
        _tahap = _Tahap.pasang;
        _progress = 1;
      });
    }
    String hasil = '';
    try {
      final Object? r = await UpdateService._channel
          .invokeMethod<Object>('install', <String, String>{
        'apk': _apkSiap ?? '',
      });
      // Versi lama mengembalikan bool, versi baru mengembalikan kode teks.
      hasil = r is bool ? (r ? 'ok' : 'izin') : (r?.toString() ?? '');
    } catch (e) {
      hasil = 'galat: $e';
    }
    if (!mounted) {
      return;
    }
    if (hasil == 'ok') {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      if (hasil == 'izin') {
        _tahap = _Tahap.izin;
        _pesan =
            'Izinkan pemasangan dari aplikasi ini, lalu ketuk Pasang lagi.';
      } else if (hasil == 'berkas') {
        _tahap = _Tahap.gagal;
        _pesan = 'Berkas update tidak ditemukan. Ketuk Coba lagi.';
      } else {
        _tahap = _Tahap.gagal;
        _pesan = 'Pemasang gagal dibuka ($hasil). Ketuk Coba lagi.';
      }
    });
  }

  /// Dipakai tombol Pasang setelah izin diberikan. Bila berkas update sudah
  /// hilang dari cache, unduh ulang dulu supaya tidak gagal diam-diam.
  Future<void> _pasangUlang() async {
    final String? path = _apkSiap;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      await _mulai();
      return;
    }
    await _pasang();
  }

  Future<void> _bukaIzin() async {
    try {
      await UpdateService._channel.invokeMethod<bool>('openInstallSettings');
    } catch (_) {}
  }

  Widget _bar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: _progress <= 0 ? null : _progress,
        minHeight: 8,
        backgroundColor: const Color(0xFF2A2A30),
        valueColor: const AlwaysStoppedAnimation<Color>(UpdateService.gold),
      ),
    );
  }

  String get _judul => switch (_tahap) {
        _Tahap.siap => 'Update Available',
        _Tahap.unduh => _adaPatch && _pesan.isEmpty
            ? 'Mengunduh update kecil'
            : 'Mengunduh update',
        _Tahap.gabung => 'Memasang update',
        _Tahap.pasang => 'Membuka pemasang',
        _Tahap.izin => 'Butuh izin',
        _Tahap.gagal => 'Gagal',
      };

  @override
  Widget build(BuildContext context) {
    final bool jalan = _tahap == _Tahap.unduh ||
        _tahap == _Tahap.gabung ||
        _tahap == _Tahap.pasang;
    final String ukuran = _adaPatch
        ? 'Unduhan kecil ${_mb(_patchSize)}'
        : 'Unduhan penuh ${_mb(widget.apkSize)}';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: UpdateService.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: UpdateService.line, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 30,
                  decoration: BoxDecoration(
                    color: UpdateService.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.download_rounded,
                      size: 18, color: Color(0xFF17171A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _judul,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_tahap == _Tahap.siap) ...<Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    widget.notes.isNotEmpty
                        ? widget.notes
                        : 'Versi ${widget.versionName} sudah tersedia.',
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: UpdateService.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Versi ${widget.versionName}  ·  $ukuran',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8A8A92)),
              ),
            ] else ...<Widget>[
              _bar(),
              const SizedBox(height: 12),
              Text(
                _tahap == _Tahap.unduh
                    ? '${(_progress * 100).toStringAsFixed(0)}%  ·  ${_mb((_progress * (_adaPatch ? _patchSize : widget.apkSize)).round())}'
                    : _pesan.isNotEmpty
                        ? _pesan
                        : 'Menyiapkan…',
                style: const TextStyle(
                    fontSize: 13, color: UpdateService.ink),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (_tahap == _Tahap.siap)
                  TextButton(
                    onPressed: _nanti,
                    child: const Text(
                      'Nanti',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBDBDC4),
                      ),
                    ),
                  ),
                if (_tahap == _Tahap.izin)
                  TextButton(
                    onPressed: _bukaIzin,
                    child: const Text(
                      'Buka izin',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBDBDC4),
                      ),
                    ),
                  ),
                if (_tahap == _Tahap.gagal)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBDBDC4),
                      ),
                    ),
                  ),
                const SizedBox(width: 14),
                if (_tahap == _Tahap.siap || _tahap == _Tahap.izin || _tahap == _Tahap.gagal)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpdateService.gold,
                        foregroundColor: const Color(0xFF17171A),
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _tahap == _Tahap.izin
                          ? _pasangUlang
                          : _mulai,
                      child: Text(
                        _tahap == _Tahap.izin ? 'Pasang' : 'Update Sekarang',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (jalan)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(UpdateService.gold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
