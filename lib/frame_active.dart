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
    this.skala = 1.36,
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

  /// Perbandingan bingkai terhadap foto. 1,36 di semua permukaan dan 1,3 di
  /// kursi mic, supaya bingkai menutup tepi lingkaran tanpa ruang kosong.
  final double skala;

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
        // Profil (kotakBingkai): sama seperti pratinjau toko. Kotak = bingkai
        // utuh dan foto 0,62x bingkai tepat di lubang lingkaran, jadi tidak ada
        // bagian bingkai yang meluber dan terpotong panel yang bisa digulir.
        final double bingkaiSisi = kotakBingkai ? ukuran * 1.32 : ukuran * skala;
        final double foto = kotakBingkai ? bingkaiSisi * 0.62 : ukuran;
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
              Positioned(
                left: (kotak - foto) / 2,
                top: (kotak - foto) / 2,
                child: _foto(foto),
              ),
              // Bingkai digambar penuh di atas foto walau induknya (kursi mic)
              // memberi batas ketat seukuran foto: dipaksa tanpa batas lalu
              // dipusatkan, jadi meluber keluar tanpa menggeser tata letak.
              Positioned(
                left: (kotak - bingkaiSisi) / 2,
                top: (kotak - bingkaiSisi) / 2,
                width: bingkaiSisi,
                height: bingkaiSisi,
                child: IgnorePointer(
                  // Kunci per aset bingkai supaya pemutarnya tidak dibuat ulang
                  // (tidak berkedip) saat layar dihitung ulang.
                  child: KeyedSubtree(
                    key: ValueKey<String>('$itemId|$gambar'),
                    child: lapis,
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
