import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart' hide Text;

import 'app_lang.dart';
import 'app_shell.dart' show kInkMain, kMutedMain;

const LinearGradient kOfficialGradient = LinearGradient(
  colors: <Color>[Color(0xFF8B5CF6), Color(0xFFE879F9)],
);

const Color kOfficialPurple = Color(0xFF8B5CF6);
const Color kSystemBlue = Color(0xFF3B82F6);

/// Halaman pesan dari akun resmi.
/// - channel 'team'   : pengumuman Tim AuraVox dari koleksi `announcements`
///                      (diisi lewat panel developer web).
/// - channel 'system' : notifikasi pribadi dari `users/{uid}/notifications`
///                      (hadiah, reward, check-in harian, status akun).
class OfficialPage extends StatelessWidget {
  const OfficialPage({
    super.key,
    required this.channel,
    required this.title,
  });

  final String channel;
  final String title;

  bool get _tim => channel == 'team';

  static String _jam(DateTime w) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(w.hour)}.${dua(w.minute)}';
  }

  static String _tanggal(DateTime w) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(w.day)}/${dua(w.month)}/${w.year}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    if (_tim) {
      return db
          .collection('announcements')
          .where('channel', isEqualTo: 'team')
          .snapshots();
    }
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '-';
    return db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: <Widget>[
          _header(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (BuildContext c,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                        snap.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
                int waktu(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ((d.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch) ??
                    0;
                // Lama ke baru: yang terbaru ada di bawah, seperti chat.
                docs.sort((QueryDocumentSnapshot<Map<String, dynamic>> a,
                        QueryDocumentSnapshot<Map<String, dynamic>> b) =>
                    waktu(a).compareTo(waktu(b)));
                if (docs.isEmpty) {
                  return _kosong();
                }
                return _daftar(context, docs);
              },
            ),
          ),
          if (_tim)
            Container(
              width: double.infinity,
              color: const Color(0xFFF6F7FB),
              padding: EdgeInsets.fromLTRB(
                  28, 8, 28, 14 + MediaQuery.of(context).padding.bottom),
              child: const Text(
                'Kamu tidak bisa membalas akun resmi ini. '
                'Untuk bantuan, buka Setelan \u2192 Tentang.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: Color(0xFFB4B0C4), height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          4, MediaQuery.of(context).padding.top + 6, 16, 10),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: kInkMain),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _tim
                  ? kOfficialGradient
                  : const LinearGradient(
                      colors: <Color>[Color(0xFF60A5FA), Color(0xFF2563EB)],
                    ),
            ),
            child: ClipOval(
              child: _tim
                  ? Image.asset(
                      'assets/mascot.png',
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext c, Object e, StackTrace? st) =>
                          const Icon(Icons.graphic_eq,
                              color: Colors.white, size: 24),
                    )
                  : const Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: _tim
                          ? GradientName(title, fontSize: 16.5)
                          : Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: kInkMain,
                              ),
                            ),
                    ),
                    if (_tim) ...<Widget>[
                      const SizedBox(width: 5),
                      const VerifiedBadge(size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _tim
                      ? 'Akun resmi \u00b7 promo dan pengumuman'
                      : 'Hadiah, reward, dan status akun',
                  style: const TextStyle(fontSize: 12.5, color: kMutedMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kosong() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              _tim
                  ? Icons.campaign_outlined
                  : Icons.notifications_none_rounded,
              size: 52,
              color: const Color(0xFFC3C6D6),
            ),
            const SizedBox(height: 14),
            Text(
              _tim ? 'Belum ada pengumuman' : 'Belum ada notifikasi',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kInkMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tim
                  ? 'Promo dan pesan dari Tim AuraVox muncul di sini.'
                  : 'Hadiah yang kamu terima, reward, dan notifikasi akun muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: kMutedMain, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daftar(BuildContext context,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<Widget> isi = <Widget>[];
    String hariTerakhir = '';
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> d = doc.data();
      final DateTime w =
          ((d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now())
              .toLocal();
      final String hari = _tanggal(w);
      if (hari != hariTerakhir) {
        hariTerakhir = hari;
        isi.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EBF3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                hari,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7C7F93)),
              ),
            ),
          ),
        ));
      }
      isi.add(_kartu(context, d, w));
      isi.add(const SizedBox(height: 10));
    }
    return ListView(
      reverse: false,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      children: isi,
    );
  }

  /// Ikon dan warna sesuai jenis notifikasi.
  (IconData, Color) _gaya(String jenis) {
    switch (jenis) {
      case 'checkin':
        return (Icons.event_available_rounded, const Color(0xFF10B981));
      case 'gift':
        return (Icons.card_giftcard_rounded, const Color(0xFFF59E0B));
      case 'reward':
        return (Icons.emoji_events_rounded, const Color(0xFFF59E0B));
      case 'account':
        return (Icons.shield_rounded, const Color(0xFF3B82F6));
      default:
        return (Icons.auto_awesome_rounded, const Color(0xFFFF4D8D));
    }
  }

  Widget _kartu(BuildContext context, Map<String, dynamic> d, DateTime w) {
    final String emoji = (d['emoji'] as String?) ?? '';
    final String judul = (d['title'] as String?) ?? title;
    final String isi = (d['body'] as String?) ?? '';
    final String tautan = (d['link'] as String?) ?? '';
    final String labelTautan =
        ((d['linkLabel'] as String?) ?? '').isEmpty ? 'Lihat' : d['linkLabel'] as String;
    final (IconData ikon, Color warna) = _gaya((d['type'] as String?) ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            child: Icon(ikon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        emoji.isEmpty ? judul : '$emoji $judul',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kInkMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _jam(w),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFB4B0C4)),
                    ),
                  ],
                ),
                if (isi.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    isi,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: kInkMain,
                      height: 1.4,
                    ),
                  ),
                ],
                if (tautan.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _bukaTautan(context, tautan),
                    child: Text(
                      '$labelTautan  \u203a',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF4D8D),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bukaTautan(BuildContext context, String url) async {
    final Uri? u = Uri.tryParse(url);
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// Centang verified ungu dengan dasar gradien.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: kOfficialGradient,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.check_rounded,
        size: size * 0.68,
        color: Colors.white,
      ),
    );
  }
}

/// Nama dengan teks bergradien ungu.
class GradientName extends StatelessWidget {
  const GradientName(this.text, {super.key, this.fontSize = 15.5});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => kOfficialGradient.createShader(bounds),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
