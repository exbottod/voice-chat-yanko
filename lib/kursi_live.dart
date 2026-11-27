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
    if (uid.isEmpty || roomId.isEmpty) {
      return;
    }
    if (_roomId == roomId && _sub != null) {
      return;
    }
    await berhenti();
    _roomId = roomId;
    _uid = uid;
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
  }

  /// Kirim posisi kursi kita. Cukup JSON beberapa byte lewat WebSocket.
  Future<void> sebar({
    required int? seat,
    required bool micOn,
    String name = '',
    String photoUrl = '',
  }) async {
    final DatabaseReference? ref = _milikku;
    final String? uid = _uid;
    if (ref == null || uid == null) {
      return;
    }
    try {
      if (seat == null) {
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
