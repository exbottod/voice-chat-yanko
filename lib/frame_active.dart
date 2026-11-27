import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'avatar_image.dart';
import 'svga_view.dart';

/// Bingkai yang sedang dipakai pemilik akun, digambar menimpa foto.
/// Kalau bingkainya SVGA, animasinya ikut diputar.
class BingkaiAktif extends StatelessWidget {
  const BingkaiAktif({
    super.key,
    required this.uid,
    required this.ukuran,
    required this.anak,
    this.fotoUkuran,
  });

  final String uid;
  final double ukuran;
  final Widget anak;
  final double? fotoUkuran;

  @override
  Widget build(BuildContext context) {
    final String id = uid.isEmpty
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : uid;
    if (id.isEmpty) {
      return anak;
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
      builder: (BuildContext c,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
        final Map<String, dynamic>? data = snap.data?.data();
        final Object? pakai = data?['equipped'];
        Map<String, dynamic>? bingkai;
        if (pakai is Map) {
          final Object? f = pakai['frame'];
          if (f is Map) {
            bingkai = Map<String, dynamic>.from(f);
          }
        }
        if (bingkai == null) {
          return anak;
        }
        final String gambar = (bingkai['image'] as String?) ?? '';
        final String itemId = (bingkai['itemId'] as String?) ?? '';
        if (gambar.isEmpty && itemId.isEmpty) {
          return anak;
        }
        final double foto = fotoUkuran ?? ukuran * 0.62;
        final bool animasi = asetSvga(<String, dynamic>{
          'mediaType': bingkai['mime'],
          'name': bingkai['name'],
          'mime': bingkai['mime'],
        });

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
                width: ukuran,
                height: ukuran,
                fallback: const SizedBox.shrink(),
              );

        return SizedBox(
          width: ukuran,
          height: ukuran,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: foto,
                height: foto,
                child: ClipOval(child: anak),
              ),
              SizedBox(width: ukuran, height: ukuran, child: lapis),
            ],
          ),
        );
      },
    );
  }
}
