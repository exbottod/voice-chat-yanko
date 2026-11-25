import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'yanko_notice.dart';

/// Pemantau koneksi internet. Aplikasi ini butuh internet, jadi status
/// koneksi diperiksa berkala dan diberitahukan ke pengguna.
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
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
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
          online.value = true;
        }
      },
      onError: (Object _) => unawaited(now()),
    );
  }

  /// Periksa koneksi sekarang juga. Hasilnya juga memperbarui [online].
  Future<bool> now() async {
    if (_checking) {
      return online.value;
    }
    _checking = true;
    bool ok = false;
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final String bust = '?v=${DateTime.now().millisecondsSinceEpoch}';
      final HttpClientRequest req =
          await client.getUrl(Uri.parse('$_probe$bust'));
      req.headers.set('Cache-Control', 'no-cache, no-store');
      final HttpClientResponse res =
          await req.close().timeout(const Duration(seconds: 5));
      await res.drain<void>();
      ok = res.statusCode == 200;
    } catch (_) {
      ok = false;
    } finally {
      client.close(force: true);
      _checking = false;
    }
    online.value = ok;
    return ok;
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
          child: YankoNoticeCard(
            text: text,
            icon: Icons.wifi_off_rounded,
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
  final bool ok = await NetStatus.instance.now();
  if (!ok && context.mounted) {
    showNetNotice(context, 'Tidak ada koneksi internet');
  }
  return ok;
}
