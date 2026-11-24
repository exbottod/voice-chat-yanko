import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  static Future<Map<String, dynamic>?> load(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _doc(uid).get();
      return snap.data();
    } catch (_) {
      return null;
    }
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
