import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Pemantau koneksi internet. Aplikasi ini butuh internet, jadi status
/// koneksi diperiksa berkala dan diberitahukan ke pengguna.
const int _batasGagalAkses = 2;

class NetStatus {
  NetStatus._();

  static final NetStatus instance = NetStatus._();

  /// true = tersambung, false = tidak ada internet.
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  Timer? _timer;
  bool _checking = false;
  bool _pernahServer = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static const String _probe =
      'https://voiceyanko.web.app/latest.json';

  /// Mulai memantau. Aman dipanggil berkali-kali.
  void start() {
    if (_timer != null) {
      return;
    }
    unawaited(now());
    // Data realtime: begitu Firestore kehilangan server, snapshot datang
    // bertanda cache, jadi status offline diketahui dalam hitungan detik.
    _watchUser();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      _watchUser();
      unawaited(now());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
  }

  /// Pantau dokumen milik sendiri; tanda cache = server tidak terjangkau.
  void _watchUser() {
    if (_sub != null) {
      return;
    }
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (snap.metadata.isFromCache) {
          // Cache bisa muncul sebelum data server pertama; baru dianggap
          // offline setelah pernah tersambung.
          if (_pernahServer) {
            unawaited(now());
          }
        } else {
          _pernahServer = true;
          _gagalBeruntun = 0;
          online.value = true;
        }
      },
      onError: (Object _) => unawaited(now()),
    );
  }

  /// Periksa koneksi sekarang juga. Hasilnya juga memperbarui [online].
  // Jumlah probe gagal berturut-turut. Banner baru muncul setelah beberapa
  // kali gagal, supaya sinyal yang turun sesaat tidak dianggap putus.
  int _gagalBeruntun = 0;
  static const int _batasGagal = 3;

  static const List<String> _targets = <String>[
    'https://voiceyanko.web.app/latest.json',
    'https://clients3.google.com/generate_204',
    'https://www.gstatic.com/generate_204',
  ];

  Future<bool> _coba(String url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final String sep = url.contains('?') ? '&' : '?';
      final HttpClientRequest req = await client.getUrl(
          Uri.parse('$url${sep}v=${DateTime.now().millisecondsSinceEpoch}'));
      req.headers.set('Cache-Control', 'no-cache, no-store');
      final HttpClientResponse res =
          await req.close().timeout(const Duration(seconds: 8));
      unawaited(res.drain<void>().catchError((Object _) {}));
      // 204 atau 200 berarti jalur internet hidup.
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Periksa koneksi. Dianggap tersambung bila SALAH SATU server menjawab;
  /// dianggap putus hanya setelah beberapa pemeriksaan gagal berturut-turut.
  Future<bool> now() async {
    if (_checking) {
      return online.value;
    }
    _checking = true;
    bool ok = false;
    try {
      // Semua target dicoba bersamaan; yang pertama berhasil menang.
      final Completer<bool> hasil = Completer<bool>();
      int selesai = 0;
      for (final String t in _targets) {
        _coba(t).then((bool b) {
          selesai++;
          if (b && !hasil.isCompleted) {
            hasil.complete(true);
          } else if (selesai == _targets.length && !hasil.isCompleted) {
            hasil.complete(false);
          }
        });
      }
      ok = await hasil.future;
    } finally {
      _checking = false;
    }
    if (ok) {
      _gagalBeruntun = 0;
      online.value = true;
    } else {
      _gagalBeruntun++;
      if (_gagalBeruntun >= _batasGagal) {
        online.value = false;
      }
    }
    return online.value;
  }
}

/// Notif mengambang singkat (tanpa kotak latar) di tengah atas layar.
void showNetNotice(BuildContext context, String text) {
  final OverlayState? overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    return;
  }
  final double top = MediaQuery.of(context).padding.top + 64;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext ctx) => Positioned(
      top: top,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
              shadows: <Shadow>[
                Shadow(color: Colors.black87, blurRadius: 6),
                Shadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(milliseconds: 2400), () {
    entry.remove();
  });
}

/// Pastikan ada internet sebelum membuka room. Kalau tidak ada, beri notif.
Future<bool> ensureOnline(BuildContext context) async {
  // Status sudah dipantau tiap 8 detik dan lewat snapshot Firestore, jadi
  // saat perangkat tersambung tidak perlu menahan navigasi dengan probe baru.
  if (NetStatus.instance.online.value) {
    return true;
  }
  NetStatus.instance._gagalBeruntun = _batasGagalAkses;
  final bool ok = await NetStatus.instance.now();
  if (!ok && context.mounted) {
    showNetNotice(context, 'Tidak ada koneksi internet');
  }
  return ok;
}
