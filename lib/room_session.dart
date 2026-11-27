import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'main.dart' show Room;
import 'rooms_live.dart';

/// Sesi room yang sedang berjalan.
///
/// Dipakai untuk tiga hal:
/// 1. Menyimpan room yang diperkecil, supaya muncul bulatan mengambang di tab
///    Party dan bisa dibuka lagi tanpa kehilangan riwayat chat.
/// 2. Menjaga kehadiran tetap hidup selama room diperkecil, sehingga room
///    masih terlihat di tab Party karena kita belum keluar.
/// 3. Mengingat kursi mic yang sedang dipakai, supaya saat room dibuka lagi
///    lewat bulatan kita tetap duduk di kursi yang sama.
class RoomSession {
  RoomSession._();

  /// Room yang sedang diperkecil (null bila tidak ada).
  static final ValueNotifier<Room?> minimized = ValueNotifier<Room?>(null);

  /// Waktu mulai sesi chat saat ini.
  static DateTime? chatSince;

  /// True selama room diperkecil: halaman room boleh ditutup tanpa menghapus
  /// kehadiran dan kursi mic.
  static bool keepAlive = false;

  /// Kursi mic yang dipakai saat room diperkecil.
  static int? seat;

  static Timer? _beat;

  /// Dipanggil saat halaman room dibuka. Bila belum ada sesi (masuk baru),
  /// sesi dimulai sekarang sehingga chat lama tidak ikut tampil.
  static void beginOrResume() {
    chatSince ??= DateTime.now();
    if (!keepAlive) {
      minimized.value = null;
    }
  }

  /// Kembalikan kursi yang tersimpan bila room ini yang tadi diperkecil.
  static int? takeSeat(String? roomId) {
    final Room? open = minimized.value;
    final bool same = roomId != null && open != null && open.id == roomId;
    final int? saved = same ? seat : null;
    seat = null;
    keepAlive = false;
    _stopBeat();
    minimized.value = null;
    return saved;
  }

  /// Room diperkecil: audio tetap jalan, bulatan tampil di tab Party, dan
  /// kehadiran terus diperbarui supaya room tidak dianggap kosong.
  static void minimize(Room room, {int? mySeat}) {
    chatSince ??= DateTime.now();
    seat = mySeat;
    keepAlive = true;
    minimized.value = room;
    _startBeat(room.id);
  }

  /// Keluar sepenuhnya: sesi chat berakhir dan kehadiran dihapus.
  static void end() {
    keepAlive = false;
    seat = null;
    _stopBeat();
    minimized.value = null;
    chatSince = null;
  }

  /// Hapus dokumen kehadiran milik sendiri di room.
  static Future<void> clearPresence(String? roomId) async {
    unawaited(RoomsLive.instance.keluar(roomId ?? ''));
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (roomId == null || uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(uid)
          .delete();
    } catch (_) {
      // Offline atau ditolak aturan: tidak masalah.
    }
  }

  /// Detak dikirim ulang seketika saat aplikasi kembali ke depan, karena
  /// timer bisa dihentikan sistem selama aplikasi di latar belakang.
  static final _PengawasDetak _pengawas = _PengawasDetak();
  static VoidCallback? _tickSekarang;

  static void _startBeat(String? roomId) {
    _stopBeat();
    if (roomId == null) {
      return;
    }
    void tick() {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        return;
      }
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(uid)
          .set(<String, dynamic>{
            'uid': uid,
            'beat': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((Object _) {});
      unawaited(RoomsLive.instance.detak(roomId));
    }

    _tickSekarang = tick;
    WidgetsBinding.instance.addObserver(_pengawas);
    tick();
    _beat = Timer.periodic(const Duration(seconds: 20), (_) => tick());
  }

  static void _stopBeat() {
    _beat?.cancel();
    _beat = null;
    _tickSekarang = null;
    WidgetsBinding.instance.removeObserver(_pengawas);
  }
}

class _PengawasDetak with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RoomSession._tickSekarang?.call();
    }
  }
}
