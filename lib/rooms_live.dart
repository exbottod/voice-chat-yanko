import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Kehadiran room lewat Firebase Realtime Database, mengikuti cara Viza.
///
/// Tiap HP yang ada di dalam room menulis satu kunci kecil
/// `roomsPub/{roomId}/users/{uid}` berisi waktu kirim. Tab Party cukup membaca
/// satu kali seluruh `roomsPub` (JSON kecil) untuk tahu room mana yang ada
/// isinya, jadi tidak ada lagi satu permintaan Firestore per room. Daftar jadi
/// ringan dan langsung tampil dalam hitungan detik.
class RoomsLive {
  RoomsLive._();

  static final RoomsLive instance = RoomsLive._();

  static const String _url =
      'https://login-9604e-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Detak lebih tua dari ini dianggap sudah keluar, supaya aplikasi yang
  /// ditutup paksa tidak membuat room kosong tetap tampil.
  static const int segarMs = 90000;

  FirebaseDatabase? _db;

  FirebaseDatabase get _database =>
      _db ??= FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _url,
      );

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Daftarkan diri di room dan tulis data ringkasnya untuk tab Party.
  Future<void> masuk(
    String roomId, {
    String title = '',
    String topic = '',
    String ownerId = '',
    String ownerName = '',
  }) async {
    final String uid = _uid;
    if (uid.isEmpty || roomId.isEmpty) {
      return;
    }
    try {
      final Map<String, Object?> isi = <String, Object?>{
        'users/$uid': ServerValue.timestamp,
        'isOpen': true,
      };
      if (title.isNotEmpty) {
        isi['title'] = title;
      }
      if (topic.isNotEmpty) {
        isi['topic'] = topic;
      }
      if (ownerId.isNotEmpty) {
        isi['ownerId'] = ownerId;
      }
      if (ownerName.isNotEmpty) {
        isi['ownerName'] = ownerName;
      }
      await _database.ref('roomsPub/$roomId').update(isi);
      // Kalau aplikasi mati mendadak atau koneksi putus, server yang
      // menghapus kehadiran kita supaya angka di tab Party tidak tertinggal 1.
      await _database
          .ref('roomsPub/$roomId/users/$uid')
          .onDisconnect()
          .remove();
    } catch (_) {
      // Jaringan bermasalah: daftar tetap memakai jalur Firestore.
    }
  }

  /// Detak berkala selama masih di room.
  Future<void> detak(String roomId) async {
    final String uid = _uid;
    if (uid.isEmpty || roomId.isEmpty) {
      return;
    }
    try {
      await _database
          .ref('roomsPub/$roomId/users/$uid')
          .set(ServerValue.timestamp);
    } catch (_) {}
  }

  /// Keluar room: kunci milik sendiri dihapus supaya room kosong hilang dari
  /// daftar.
  Future<void> keluar(String roomId) async {
    final String uid = _uid;
    if (uid.isEmpty || roomId.isEmpty) {
      return;
    }
    final DatabaseReference saya =
        _database.ref('roomsPub/$roomId/users/$uid');
    try {
      await saya.onDisconnect().cancel();
      await saya.remove();
    } catch (_) {}
  }

  /// Jumlah orang aktif per room dalam satu kali baca.
  Future<Map<String, int>> daftar({
    Duration batas = const Duration(seconds: 4),
  }) async {
    try {
      final DataSnapshot snap =
          await _database.ref('roomsPub').get().timeout(batas);
      final Object? nilai = snap.value;
      if (nilai is! Map) {
        return <String, int>{};
      }
      final int sekarang = DateTime.now().millisecondsSinceEpoch;
      final Map<String, int> hasil = <String, int>{};
      nilai.forEach((Object? id, Object? isi) {
        if (id is! String || isi is! Map) {
          return;
        }
        final Object? users = isi['users'];
        int aktif = 0;
        if (users is Map) {
          users.forEach((Object? _, Object? ts) {
            final int? ms = ts is int ? ts : (ts is num ? ts.toInt() : null);
            if (ms != null && sekarang - ms < segarMs) {
              aktif++;
            }
          });
        }
        hasil[id] = aktif;
      });
      return hasil;
    } catch (_) {
      return <String, int>{};
    }
  }
}
