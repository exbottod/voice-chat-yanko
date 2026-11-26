import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;

import 'app_shell.dart' show kInkMain, kMutedMain;

const LinearGradient kOfficialGradient = LinearGradient(
  colors: <Color>[Color(0xFF8B5CF6), Color(0xFFE879F9)],
);

const Color kOfficialPurple = Color(0xFF8B5CF6);
const Color kSystemBlue = Color(0xFF3B82F6);

/// Halaman pesan dari akun resmi (Tim AuraVox / Notifikasi Sistem).
/// Isinya dibaca dari koleksi `announcements` dengan field `channel`.
class OfficialPage extends StatelessWidget {
  const OfficialPage({
    super.key,
    required this.channel,
    required this.title,
  });

  final String channel; // 'team' atau 'system'
  final String title;

  static String _waktu(Timestamp? t) {
    if (t == null) {
      return '';
    }
    final DateTime w = t.toDate();
    final DateTime now = DateTime.now();
    String dua(int n) => n.toString().padLeft(2, '0');
    if (w.year == now.year && w.month == now.month && w.day == now.day) {
      return '${dua(w.hour)}:${dua(w.minute)}';
    }
    return '${dua(w.day)}/${dua(w.month)}/${w.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: kInkMain),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kInkMain,
              ),
            ),
            if (channel == 'team') ...<Widget>[
              const SizedBox(width: 5),
              const VerifiedBadge(size: 15),
            ],
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .where('channel', isEqualTo: channel)
            .snapshots(),
        builder: (BuildContext c,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snap.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
          docs.sort((QueryDocumentSnapshot<Map<String, dynamic>> a,
              QueryDocumentSnapshot<Map<String, dynamic>> b) {
            final Timestamp? ta = a.data()['createdAt'] as Timestamp?;
            final Timestamp? tb = b.data()['createdAt'] as Timestamp?;
            return (tb?.millisecondsSinceEpoch ?? 0)
                .compareTo(ta?.millisecondsSinceEpoch ?? 0);
          });
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      channel == 'team'
                          ? Icons.campaign_outlined
                          : Icons.notifications_none_rounded,
                      size: 46,
                      color: const Color(0xFFC9C4DA),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      channel == 'team'
                          ? 'Belum ada pengumuman'
                          : 'Belum ada notifikasi',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: kInkMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      channel == 'team'
                          ? 'Promo dan pesan dari Tim AuraVox muncul di sini.'
                          : 'Hadiah, reward, dan info akun muncul di sini.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: kMutedMain, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext c, int i) {
              final Map<String, dynamic> d = docs[i].data();
              final String judul = (d['title'] as String?) ?? title;
              final String isi = (d['body'] as String?) ?? '';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            judul,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kInkMain,
                            ),
                          ),
                        ),
                        Text(
                          _waktu(d['createdAt'] as Timestamp?),
                          style: const TextStyle(
                              fontSize: 11, color: kMutedMain),
                        ),
                      ],
                    ),
                    if (isi.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        isi,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B4658),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
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
