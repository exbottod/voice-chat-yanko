import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'aset_media.dart';

/// Satu efek masuk room yang sedang/akan diputar.
class EfekMasukData {
  const EfekMasukData({
    required this.uid,
    required this.nama,
    required this.sumber,
    required this.jenis,
    this.id = '',
    this.vip = 0,
  });

  final String uid;
  final String nama;
  final String sumber;
  final String jenis;
  final String id;
  final int vip;

  bool get kosong => sumber.isEmpty && id.isEmpty;
}

/// Antrian efek masuk room: efek kita sendiri diputar saat kita masuk, efek
/// orang lain diputar begitu mereka muncul di daftar anggota. Diputar satu per
/// satu supaya tidak numpuk kalau beberapa orang masuk bersamaan.
class EfekMasuk {
  EfekMasuk._();

  static final EfekMasuk i = EfekMasuk._();

  final ValueNotifier<EfekMasukData?> tampil =
      ValueNotifier<EfekMasukData?>(null);
  final List<EfekMasukData> _antre = <EfekMasukData>[];
  final Map<String, EfekMasukData> _cache = <String, EfekMasukData>{};
  bool _sibuk = false;

  /// Efek milik satu akun: bingkai yang sedang dipakai, atau dokumen
  /// `enter_effects` kalau nanti ada efek masuk khusus.
  Future<EfekMasukData> untukAkun(String uid, String nama) async {
    final EfekMasukData? ada = _cache[uid];
    if (ada != null) {
      return ada;
    }
    Map<String, dynamic>? aset;
    try {
      final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore
          .instance
          .collection('enter_effects')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        aset = <String, dynamic>{...q.docs.first.data(), 'id': q.docs.first.id};
      }
    } catch (_) {
      /* koleksi belum ada, lanjut ke bingkai */
    }
    if (aset == null) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> d = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(uid)
            .get();
        final Object? pakai = d.data()?['equipped'];
        if (pakai is Map) {
          // Efek masuk yang dipasang dari toko didahulukan. Bingkai hanya
          // cadangan bila akun belum memasang efek masuk.
          final Object? e = pakai['enter'];
          final Object? f = pakai['frame'];
          if (e is Map) {
            aset = Map<String, dynamic>.from(e);
          } else if (f is Map) {
            aset = Map<String, dynamic>.from(f);
          }
        }
      } catch (_) {
        /* biarkan kosong */
      }
    }
    final EfekMasukData hasil = aset == null
        ? EfekMasukData(uid: uid, nama: nama, sumber: '', jenis: '', id: '')
        : EfekMasukData(
            uid: uid,
            nama: nama,
            sumber: sumberAset(aset),
            jenis: jenisAset(aset),
            id: idAset(aset),
          );
    _cache[uid] = hasil;
    return hasil;
  }

  /// Antrekan efek untuk diputar.
  void tambah(EfekMasukData data) {
    if (data.kosong) {
      return;
    }
    if (tampil.value?.uid == data.uid && _sibuk) {
      return;
    }
    _antre.add(data);
    _lanjut();
  }

  void _lanjut() {
    if (_sibuk || _antre.isEmpty) {
      return;
    }
    _sibuk = true;
    tampil.value = _antre.removeAt(0);
    Timer(const Duration(milliseconds: 3200), () {
      tampil.value = null;
      _sibuk = false;
      _lanjut();
    });
  }

  /// Hentikan semuanya saat keluar room.
  void berhenti() {
    _antre.clear();
    _sibuk = false;
    tampil.value = null;
  }
}
