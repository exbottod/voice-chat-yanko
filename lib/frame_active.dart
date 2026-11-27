import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'avatar_image.dart';
import 'res_image.dart';
import 'svga_view.dart';

/// Bingkai yang sedang dipakai satu akun, disimpan di `users/{uid}.equipped`.
/// Satu pendengar per akun dipakai bersama semua tempat, supaya kursi dan
/// profil tidak membuka belasan listener untuk orang yang sama.
class BingkaiStore {
  BingkaiStore._();

  static final Map<String, ValueNotifier<Map<String, dynamic>?>> _peta =
      <String, ValueNotifier<Map<String, dynamic>?>>{};
  static final Set<String> _jalan = <String>{};

  static ValueNotifier<Map<String, dynamic>?> ambil(String uid) {
    final ValueNotifier<Map<String, dynamic>?> ada = _peta[uid]!;
    return ada;
  }

  static ValueNotifier<Map<String, dynamic>?> pantau(String uid) {
    final ValueNotifier<Map<String, dynamic>?>? ada = _peta[uid];
    if (ada != null) {
      return ada;
    }
    final ValueNotifier<Map<String, dynamic>?> notif =
        ValueNotifier<Map<String, dynamic>?>(null);
    _peta[uid] = notif;
    if (uid.isNotEmpty && _jalan.add(uid)) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> d) {
        final Object? pakai = d.data()?['equipped'];
        if (pakai is Map) {
          final Object? f = pakai['frame'];
          if (f is Map) {
            notif.value = Map<String, dynamic>.from(f);
            return;
          }
        }
        notif.value = null;
      }, onError: (Object _) {});
    }
    return notif;
  }
}

/// Ukuran bingkai menurut ukuran foto (dp), sesuai tabel yang ditetapkan:
/// 48 -> 60, 72 -> 88, 110 -> 132, 120 -> 144. Ukuran di antaranya dihitung
/// berdasarkan selisih terdekat; di luar tabel selisih mengikuti ujung tabel.
double ukuranBingkai(double foto) {
  const List<List<double>> tabel = <List<double>>[
    <double>[48, 60],
    <double>[72, 88],
    <double>[110, 132],
    <double>[120, 144],
  ];
  if (foto <= tabel.first[0]) {
    return foto + (tabel.first[1] - tabel.first[0]) * (foto / tabel.first[0]);
  }
  if (foto >= tabel.last[0]) {
    return foto * (tabel.last[1] / tabel.last[0]);
  }
  for (int i = 0; i < tabel.length - 1; i++) {
    final List<double> a = tabel[i];
    final List<double> b = tabel[i + 1];
    if (foto >= a[0] && foto <= b[0]) {
      final double t = (foto - a[0]) / (b[0] - a[0]);
      return a[1] + (b[1] - a[1]) * t;
    }
  }
  return foto * 1.2;
}

/// Foto profil dengan bingkai yang sedang dipakai akun itu.
/// Bingkai SVGA ikut beranimasi, bingkai gambar tampil biasa.
class BingkaiFoto extends StatelessWidget {
  const BingkaiFoto({
    super.key,
    required this.uid,
    required this.ukuran,
    this.photo,
    this.male = true,
    this.lingkar = true,
    this.kotakBingkai = false,
  });

  final String uid;
  final double ukuran;
  final String? photo;
  final bool male;
  final bool lingkar;

  /// true: kotak tata letak ikut sebesar bingkai (profil, seperti Viza).
  /// false: kotak tetap seukuran foto, bingkai meluber keluar tanpa menggeser
  /// tata letak (kursi mic, daftar, sheet).
  final bool kotakBingkai;

  Widget _foto(double sisi) {
    final Widget isi = (photo == null || photo!.isEmpty)
        ? ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover)
        : AvatarImage(
            source: photo,
            fit: BoxFit.cover,
            width: sisi,
            height: sisi,
            fallback: ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover),
          );
    return SizedBox(
      width: sisi,
      height: sisi,
      child: lingkar ? ClipOval(child: isi) : isi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String id =
        uid.isEmpty ? (FirebaseAuth.instance.currentUser?.uid ?? '') : uid;
    if (id.isEmpty) {
      return _foto(ukuran);
    }
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: BingkaiStore.pantau(id),
      builder: (BuildContext c, Map<String, dynamic>? bingkai, Widget? _) {
        final String gambar = (bingkai?['image'] as String?) ?? '';
        final String itemId = (bingkai?['itemId'] as String?) ?? '';
        if (bingkai == null || (gambar.isEmpty && itemId.isEmpty)) {
          // Tanpa bingkai: foto polos, sebesar foto di kursi (seperti Viza).
          return _foto(kotakBingkai ? ukuran * (72 / 110) : ukuran);
        }
        final bool animasi = asetSvga(<String, dynamic>{
          'mediaType': bingkai['mediaType'],
          'name': bingkai['name'],
          'mime': bingkai['mime'],
          'image': gambar,
          'itemId': itemId,
        });
        // Mengikuti Viza: foto 72dp, bingkai 100dp (bingkai = 1,39x foto) dan
        // kotak tata letak ikut sebesar bingkai, jadi bingkai tidak terpotong
        // dan tidak menempel ke teks di sebelahnya. Foto selalu ukuran penuh.
        final double foto = ukuran;
        final double bingkaiSisi = ukuranBingkai(ukuran);
        final Widget lapis = animasi
            ? SvgaAnimasi(
                sumber: gambar,
                id: itemId,
                fit: BoxFit.contain,
                fallback: const SizedBox.shrink(),
              )
            : AvatarImage(
                source: gambar,
                fit: BoxFit.contain,
                width: bingkaiSisi,
                height: bingkaiSisi,
                fallback: const SizedBox.shrink(),
              );
        final double kotak = kotakBingkai ? bingkaiSisi : ukuran;
        return SizedBox(
          width: kotak,
          height: kotak,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              _foto(foto),
              OverflowBox(
                maxWidth: bingkaiSisi,
                maxHeight: bingkaiSisi,
                child: IgnorePointer(
                  // Kunci per aset bingkai supaya pemutarnya tidak dibuat ulang
                  // (tidak berkedip) saat layar dihitung ulang.
                  child: KeyedSubtree(
                    key: ValueKey<String>('$itemId|$gambar'),
                    child: SizedBox(
                      width: bingkaiSisi,
                      height: bingkaiSisi,
                      child: lapis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
