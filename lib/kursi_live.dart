import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Jalur cepat posisi kursi mic.
///
/// Memakai Firebase Realtime Database, yang koneksinya WebSocket tetap dan
/// datanya JSON kecil (`{uid, seat, micOn, name, photo}`). Satu kali tulis
/// langsung didorong ke semua HP di room tanpa memuat ulang room, jadi pindah
/// kursi terasa seketika. Firestore tetap dipakai sebagai catatan resmi.
class KursiLive {
  KursiLive._();

  static final KursiLive instance = KursiLive._();

  static const String _url =
      'https://login-9604e-default-rtdb.asia-southeast1.firebasedatabase.app';

  FirebaseDatabase? _db;
  DatabaseReference? _simpul; // rooms/{roomId}/kursi
  DatabaseReference? _milikku; // rooms/{roomId}/kursi/{uid}
  StreamSubscription<DatabaseEvent>? _sub;
  StreamController<Map<String, dynamic>>? _masuk;
  Future<void>? _siap;
  String? _roomId;
  String? _uid;

  /// Perubahan kursi dari HP lain: `{uid, seat, micOn, name, photo}`.
  Stream<Map<String, dynamic>> get masuk =>
      (_masuk ??= StreamController<Map<String, dynamic>>.broadcast()).stream;

  FirebaseDatabase get _database =>
      _db ??= FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _url,
      );

  bool get siap => _milikku != null;

  /// Mulai mendengarkan kursi room. Aman dipanggil berulang.
  Future<void> mulai(String roomId) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || roomId.isEmpty) {
      return;
    }
    if (_roomId == roomId && _sub != null) {
      return;
    }
    await berhenti();
    _roomId = roomId;
    _uid = uid;
    _siap = null;
    final DatabaseReference simpul = _database.ref('rooms/$roomId/kursi');
    _simpul = simpul;
    _milikku = simpul.child(uid);
    _sub = simpul.onValue.listen((DatabaseEvent e) {
      final Object? v = e.snapshot.value;
      if (v is! Map) {
        return;
      }
      for (final MapEntry<Object?, Object?> entry in v.entries) {
        final Object? isi = entry.value;
        if (isi is! Map) {
          continue;
        }
        final Map<String, dynamic> m = <String, dynamic>{
          'uid': '${entry.key}',
        };
        isi.forEach((Object? k, Object? val) {
          if (k != null) {
            m['$k'] = val;
          }
        });
        _masuk?.add(m);
      }
    });
    // Penanda siap: sebar() menunggu ini supaya kursi yang dikirim saat baru
    // masuk room tidak hilang karena sambungan belum terpasang.
    _siap = _database.ref('.info/connected').get().then((DataSnapshot _) {});
    await _siap;
  }

  /// Kirim posisi kursi kita. Cukup JSON beberapa byte lewat WebSocket.
  Future<void> sebar({
    required int? seat,
    required bool micOn,
    String name = '',
    String photoUrl = '',
  }) async {
    // Kalau sambungan belum siap (mis. duduk segera setelah room terbuka),
    // tunggu sebentar lalu kirim. Tanpa ini kursi tidak pernah tersiar.
    if (_milikku == null && _roomId != null) {
      await mulai(_roomId!);
    }
    final Future<void>? tunggu = _siap;
    if (tunggu != null) {
      await tunggu;
    }
    DatabaseReference? ref = _milikku;
    String? uid = _uid;
    if (ref == null || uid == null) {
      // Sambungan masih dipasang: beri satu kesempatan lagi sebelum menyerah.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      ref = _milikku;
      uid = _uid;
    }
    if (ref == null || uid == null) {
      return;
    }
    try {
      if (seat == null) {
        // Penanda keluar: HP lain menerima ini sebagai "kosongkan kursi",
        // karena penghapusan simpul sendiri tidak memicu pesan apa pun.
        await ref.set(<String, Object?>{
          'uid': uid,
          'seat': -1,
          'micOn': false,
          'ts': ServerValue.timestamp,
        });
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await ref.remove();
      } else {
        await ref.set(<String, Object?>{
          'uid': uid,
          'seat': seat,
          'micOn': micOn,
          'name': name,
          'photo': photoUrl,
          'ts': ServerValue.timestamp,
        });
      }
    } catch (_) {
      // Offline atau ditolak aturan: Firestore tetap jadi cadangan.
    }
  }

  /// Lepas penanda kursi kita dan hentikan langganan.

  /// Kosongkan kursi milik [uid] lain (dipakai pemilik saat menurunkan atau
  /// mengeluarkan pengguna). Tanpa ini, simpul kursi di RTDB tetap ada dan HP
  /// pengguna itu memasang dirinya kembali ke kursi setiap kali data masuk.
  Future<void> kosongkanUid(String uid) async {
    final DatabaseReference? simpul = _simpul;
    if (simpul == null || uid.isEmpty) {
      return;
    }
    try {
      final DatabaseReference r = simpul.child(uid);
      await r.set(<String, Object?>{
        'uid': uid,
        'seat': -1,
        'micOn': false,
        'ts': ServerValue.timestamp,
      });
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await r.remove();
    } catch (_) {}
  }

  Future<void> berhenti() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _milikku?.remove();
    } catch (_) {}
    _milikku = null;
    _simpul = null;
    _roomId = null;
    _uid = null;
  }
}
