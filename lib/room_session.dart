import 'package:flutter/foundation.dart';

import 'main.dart' show Room;

/// Sesi room yang sedang berjalan.
///
/// Dipakai untuk dua hal:
/// 1. Menyimpan room yang diperkecil, supaya muncul bulatan mengambang di tab
///    Party dan bisa dibuka lagi tanpa kehilangan riwayat chat.
/// 2. Menandai kapan sesi chat dimulai. Saat benar-benar keluar room, sesi
///    diakhiri sehingga riwayat chat lama tidak tampil lagi ketika masuk ulang.
class RoomSession {
  RoomSession._();

  /// Room yang sedang diperkecil (null bila tidak ada).
  static final ValueNotifier<Room?> minimized = ValueNotifier<Room?>(null);

  /// Waktu mulai sesi chat saat ini.
  static DateTime? chatSince;

  /// Dipanggil saat halaman room dibuka. Bila belum ada sesi (masuk baru),
  /// sesi dimulai sekarang sehingga chat lama tidak ikut tampil.
  static void beginOrResume() {
    chatSince ??= DateTime.now();
    minimized.value = null;
  }

  /// Room diperkecil: audio tetap jalan, bulatan tampil di tab Party.
  static void minimize(Room room) {
    chatSince ??= DateTime.now();
    minimized.value = room;
  }

  /// Keluar sepenuhnya: sesi chat berakhir.
  static void end() {
    minimized.value = null;
    chatSince = null;
  }
}
