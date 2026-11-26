import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Catatan kursi mic yang harus dilepas di server tetapi belum berhasil
/// terkirim, biasanya karena koneksi terputus. Disimpan di perangkat dan
/// dikirim ulang saat internet kembali atau saat aplikasi dibuka lagi.
class KursiTertunda {
  KursiTertunda._();

  static const String _key = 'kursi_tertunda';

  static Future<List<String>> _muat() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return p.getStringList(_key) ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> _simpan(List<String> isi) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setStringList(_key, isi);
    } catch (_) {
      // Gagal menyimpan catatan bukan alasan untuk menghentikan aplikasi.
    }
  }

  /// Tambahkan satu kursi yang perlu dilepas nanti.
  static Future<void> tambah(String? roomId, int? seat) async {
    if (roomId == null || seat == null) {
      return;
    }
    final String baris = '$roomId|$seat';
    final List<String> isi = await _muat();
    if (isi.contains(baris)) {
      return;
    }
    isi.add(baris);
    await _simpan(isi);
  }

  /// Lepas semua kursi tertunda yang masih ada. Aman dipanggil berkali-kali
  /// dan saat offline (yang gagal akan tetap tersimpan).
  static Future<void> bersihkan() async {
    final List<String> isi = await _muat();
    if (isi.isEmpty) {
      return;
    }
    final List<String> sisa = <String>[];
    for (final String baris in isi) {
      final List<String> bagian = baris.split('|');
      if (bagian.length != 2) {
        continue;
      }
      final int? seat = int.tryParse(bagian[1]);
      if (seat == null) {
        continue;
      }
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(bagian[0])
            .collection('seats')
            .doc('$seat')
            .delete();
      } catch (_) {
        sisa.add(baris);
      }
    }
    await _simpan(sisa);
  }

  /// Pasang pengiriman ulang otomatis: begitu internet kembali, kursi
  /// tertunda langsung dilepas.
  static void pantau(ValueNotifier<bool> online) {
    void kirim() {
      if (online.value) {
        unawaited(bersihkan());
      }
    }

    online.addListener(kirim);
    unawaited(bersihkan());
  }
}
