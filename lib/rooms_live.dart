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

  /// Batas aman saja. Kehadiran dihapus sendiri saat keluar room atau saat
  /// koneksi putus (onDisconnect), jadi angka tidak lagi bergantung pada jam
  /// HP masing-masing: jam yang berbeda dulu membuat room berisi orang
  /// terlihat kosong di HP lain.
  static const int segarMs = 1800000;

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
    String coverAsset = '',
    String coverImage = '',
  }) async {
    final String uid = _uid;
    if (uid.isEmpty || roomId.isEmpty) {
      return;
    }
    try {
      // Data ringkas room ikut ditulis di sini, jadi tab Party tidak perlu
      // membaca Firestore sama sekali: satu baca JSON kecil sudah memuat
      // judul, topik, sampul, dan jumlah orang.
      final Map<String, Object?> isi = <String, Object?>{
        'users/$uid': ServerValue.timestamp,
        'isOpen': true,
        'title': title,
        'topic': topic,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'coverAsset': coverAsset,
        'coverImage': coverImage,
      };
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

  /// Semua room yang sedang ada isinya, lengkap dengan judul dan sampulnya.
  /// Satu permintaan Realtime Database, tanpa Firestore.
  Future<Map<String, Map<String, dynamic>>> semua({
    Duration batas = const Duration(seconds: 5),
  }) async {
    try {
      final DataSnapshot snap =
          await _database.ref('roomsPub').get().timeout(batas);
      final Object? nilai = snap.value;
      if (nilai is! Map) {
        return <String, Map<String, dynamic>>{};
      }
      final int sekarang = DateTime.now().millisecondsSinceEpoch;
      final Map<String, Map<String, dynamic>> hasil =
          <String, Map<String, dynamic>>{};
      nilai.forEach((Object? id, Object? isi) {
        if (id is! String || isi is! Map) {
          return;
        }
        int aktif = 0;
        final Object? users = isi['users'];
        if (users is Map) {
          users.forEach((Object? _, Object? ts) {
            final int? ms = ts is int ? ts : (ts is num ? ts.toInt() : null);
            if (ms != null && sekarang - ms < segarMs) {
              aktif++;
            }
          });
        }
        hasil[id] = <String, dynamic>{
          'id': id,
          'title': (isi['title'] as String?) ?? '',
          'topic': (isi['topic'] as String?) ?? '',
          'coverAsset': (isi['coverAsset'] as String?) ?? '',
          'coverImage': (isi['coverImage'] as String?) ?? '',
          'ownerId': (isi['ownerId'] as String?) ?? '',
          'ownerName': (isi['ownerName'] as String?) ?? '',
          'isOpen': isi['isOpen'] != false,
          'listeners': aktif,
        };
      });
      return hasil;
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  /// Pantau isi satu room (untuk jumlah orang di dalam room).
  Stream<int> pantauJumlah(String roomId) {
    if (roomId.isEmpty) {
      return const Stream<int>.empty();
    }
    return _database.ref('roomsPub/$roomId/users').onValue.map((DatabaseEvent e) {
      final Object? v = e.snapshot.value;
      if (v is Map) {
        final int sekarang = DateTime.now().millisecondsSinceEpoch;
        int n = 0;
        v.forEach((Object? _, Object? ts) {
          final int? ms = ts is int ? ts : (ts is num ? ts.toInt() : null);
          if (ms != null && sekarang - ms < segarMs) {
            n++;
          }
        });
        return n;
      }
      return 0;
    });
  }

  /// Peringkat di dalam satu room, dipantau dari Realtime Database.
  Stream<Map<String, dynamic>> pantauRank(String roomId, String field) {
    if (roomId.isEmpty) {
      return const Stream<Map<String, dynamic>>.empty();
    }
    return _database.ref('rooms/$roomId/rank').onValue.map((DatabaseEvent e) {
      final Object? v = e.snapshot.value;
      final Map<String, dynamic> hasil = <String, dynamic>{};
      if (v is Map) {
        v.forEach((Object? uid, Object? nilai) {
          if (uid is String && nilai is Map) {
            hasil[uid] = Map<String, dynamic>.from(nilai);
          }
        });
      }
      return hasil;
    });
  }

  /// Penanda sedang mengetik: satu kunci kecil per orang, hilang sendiri saat
  /// koneksi putus.
  Future<void> tulisTyping(String roomId, bool aktif) async {
    final String uid = _uid;
    if (uid.isEmpty || roomId.isEmpty) {
      return;
    }
    final DatabaseReference r = _database.ref('rooms/$roomId/typing/$uid');
    try {
      if (aktif) {
        await r.set(true);
        await r.onDisconnect().remove();
      } else {
        await r.onDisconnect().cancel();
        await r.remove();
      }
    } catch (_) {}
  }

  /// Daftar uid yang sedang mengetik di satu room.
  Stream<List<String>> pantauTyping(String roomId) {
    if (roomId.isEmpty) {
      return const Stream<List<String>>.empty();
    }
    return _database.ref('rooms/$roomId/typing').onValue.map((DatabaseEvent e) {
      final Object? v = e.snapshot.value;
      final List<String> hasil = <String>[];
      if (v is Map) {
        v.forEach((Object? k, Object? on) {
          if (k is String && on == true) {
            hasil.add(k);
          }
        });
      }
      return hasil;
    });
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
