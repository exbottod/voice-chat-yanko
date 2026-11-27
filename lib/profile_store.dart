import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'countries.dart';

/// Profil user di Firestore: users/{uid}
class ProfileStore {
  ProfileStore._();

  static DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<bool> isComplete(User user) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _doc(user.uid).get();
      return snap.data()?['profileComplete'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Simpanan sebentar supaya masuk room berulang tidak membaca ulang
  /// dokumen yang sama dari jaringan.
  static final Map<String, ({Map<String, dynamic> data, DateTime waktu})> _cache =
      <String, ({Map<String, dynamic> data, DateTime waktu})>{};
  static const Duration _umurCache = Duration(seconds: 60);

  static Future<Map<String, dynamic>?> load(
    String uid, {
    bool segar = false,
  }) async {
    final ({Map<String, dynamic> data, DateTime waktu})? ada = _cache[uid];
    if (!segar &&
        ada != null &&
        DateTime.now().difference(ada.waktu) < _umurCache) {
      return ada.data;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _doc(uid).get();
      final Map<String, dynamic>? d = snap.data();
      if (d != null) {
        _cache[uid] = (data: d, waktu: DateTime.now());
      }
      return d;
    } catch (_) {
      return ada?.data;
    }
  }

  /// Buang simpanan satu akun, dipakai setelah koin berubah.
  static void lupakan(String uid) {
    _cache.remove(uid);
  }

  /// ID numerik 8 digit yang tampil di profil, dihitung stabil dari uid.
  static String publicId(String uid) {
    int h = 7;
    for (final int c in uid.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (10000000 + h % 90000000).toString();
  }

  static int ageFromBirth(String birth) {
    final List<String> p = birth.split('.');
    if (p.length != 3) {
      return 0;
    }
    final int d = int.tryParse(p[0]) ?? 1;
    final int m = int.tryParse(p[1]) ?? 1;
    final int y = int.tryParse(p[2]) ?? 2000;
    final DateTime now = DateTime.now();
    int age = now.year - y;
    if (now.month < m || (now.month == m && now.day < d)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  static Future<void> deleteProfile(String uid) async {
    await _doc(uid).delete();
  }

  static Future<void> updateDetails({
    required User user,
    String? displayName,
    String? bio,
    String? job,
    String? city,
    String? countryCode,
    String? height,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (displayName != null && displayName.isNotEmpty) {
      data['displayName'] = displayName;
    }
    if (bio != null) {
      data['bio'] = bio;
    }
    if (job != null) {
      data['job'] = job;
    }
    if (city != null) {
      data['city'] = city;
    }
    if (height != null) {
      data['height'] = height;
    }
    if (countryCode != null) {
      data['countryCode'] = countryCode;
      data['country'] = namaNegara(countryCode);
    }
    if (data.isEmpty) {
      return;
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _doc(user.uid).set(data, SetOptions(merge: true));
    if (displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
  }

  /// Simpan foto profil (data URL hasil upload dari galeri).
  static Future<void> updatePhoto(User user, String dataUrl) async {
    await _doc(user.uid).set(<String, dynamic>{
      'photoUrl': dataUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> save({
    required User user,
    required String displayName,
    required String gender,
    required String birthDate,
    String inviteCode = '',
    String agencyCode = '',
  }) async {
    await _doc(user.uid).set(<String, dynamic>{
      'uid': user.uid,
      'publicId': publicId(user.uid),
      'email': user.email,
      'photoUrl': user.photoURL,
      'displayName': displayName,
      'gender': gender,
      'birthDate': birthDate,
      'inviteCode': inviteCode,
      'agencyCode': agencyCode,
      'coins': 30,
      'profileComplete': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updateDisplayName(displayName);
  }
}
