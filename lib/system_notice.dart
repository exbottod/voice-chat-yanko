import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Menulis notifikasi pribadi ke users/{uid}/notifications.
/// Tampil di tab Pesan > Notifikasi Sistem.
class SystemNotice {
  SystemNotice._();

  /// Jenis: checkin, gift, reward, account.
  static Future<void> kirim({
    required String type,
    required String title,
    String body = '',
    String emoji = '',
    String link = '',
    String linkLabel = '',
  }) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add(<String, dynamic>{
        'type': type,
        'title': title,
        'body': body,
        'emoji': emoji,
        'link': link,
        'linkLabel': linkLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notifikasi gagal tidak boleh menggagalkan aksi utamanya.
    }
  }
}
