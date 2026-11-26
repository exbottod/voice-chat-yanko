import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Follow dan chat pribadi antar pengguna.
///
/// Struktur data:
/// - users/{uid}/following/{target}  : siapa yang saya ikuti
/// - users/{uid}/followers/{pengikut}: siapa yang mengikuti saya
/// - dms/{pairId}                    : percakapan, pairId = dua uid diurutkan
/// - dms/{pairId}/messages/{id}      : pesan di percakapan itu
class SocialService {
  SocialService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get myUid => FirebaseAuth.instance.currentUser?.uid;

  /// Id percakapan yang sama untuk kedua pihak.
  static String pairId(String a, String b) {
    final List<String> dua = <String>[a, b]..sort();
    return '${dua[0]}_${dua[1]}';
  }

  // ------------------------------------------------------------ follow

  static Stream<bool> sayaMengikuti(String target) {
    final String? me = myUid;
    if (me == null) {
      return Stream<bool>.value(false);
    }
    return _db
        .collection('users')
        .doc(me)
        .collection('following')
        .doc(target)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> s) => s.exists);
  }

  /// Ikuti atau berhenti mengikuti. Dua dokumen ditulis satu batch supaya
  /// daftar following dan followers selalu sejalan.
  static Future<void> setFollow(String target, bool ikuti) async {
    final String? me = myUid;
    if (me == null || target.isEmpty || target == me) {
      return;
    }
    final DocumentReference<Map<String, dynamic>> a =
        _db.collection('users').doc(me).collection('following').doc(target);
    final DocumentReference<Map<String, dynamic>> b =
        _db.collection('users').doc(target).collection('followers').doc(me);
    final WriteBatch batch = _db.batch();
    if (ikuti) {
      final Map<String, dynamic> isi = <String, dynamic>{
        'at': FieldValue.serverTimestamp(),
      };
      batch.set(a, isi);
      batch.set(b, isi);
    } else {
      batch.delete(a);
      batch.delete(b);
    }
    await batch.commit();
  }

  // ------------------------------------------------------------ chat pribadi

  /// Kirim pesan. Dokumen percakapan ikut diperbarui supaya daftar di tab
  /// Pesan selalu menampilkan pesan terakhir dan urutan terbaru.
  static Future<void> kirim({
    required String target,
    required String targetNama,
    required String targetFoto,
    required String targetPublicId,
    required String teks,
    required String namaSaya,
    required String fotoSaya,
  }) async {
    final String? me = myUid;
    final String isi = teks.trim();
    if (me == null || target.isEmpty || isi.isEmpty) {
      return;
    }
    final String id = pairId(me, target);
    final DocumentReference<Map<String, dynamic>> ref =
        _db.collection('dms').doc(id);
    final WriteBatch batch = _db.batch();
    batch.set(
      ref,
      <String, dynamic>{
        'members': <String>[me, target],
        'lastText': isi,
        'lastFrom': me,
        'lastAt': FieldValue.serverTimestamp(),
        // Ringkasan kedua pihak, dipakai untuk judul dan foto di daftar.
        'profiles': <String, dynamic>{
          me: <String, dynamic>{'name': namaSaya, 'photo': fotoSaya},
          target: <String, dynamic>{
            'name': targetNama,
            'photo': targetFoto,
            'publicId': targetPublicId,
          },
        },
        'unread': <String, dynamic>{target: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );
    batch.set(ref.collection('messages').doc(), <String, dynamic>{
      'from': me,
      'text': isi,
      'at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Tandai percakapan sudah dibaca oleh saya.
  static Future<void> tandaiDibaca(String target) async {
    final String? me = myUid;
    if (me == null) {
      return;
    }
    try {
      await _db.collection('dms').doc(pairId(me, target)).set(
        <String, dynamic>{
          'unread': <String, dynamic>{me: 0},
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Percakapan belum ada atau offline: tidak masalah.
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> pesan(String target) {
    final String me = myUid ?? '';
    return _db
        .collection('dms')
        .doc(pairId(me, target))
        .collection('messages')
        .orderBy('at', descending: true)
        .limit(50)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> daftarPercakapan() {
    final String me = myUid ?? '';
    return _db
        .collection('dms')
        .where('members', arrayContains: me)
        .snapshots();
  }
}
