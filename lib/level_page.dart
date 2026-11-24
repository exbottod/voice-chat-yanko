import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'res_image.dart';

const Color _ink = Color(0xFF3A2A1A);
const Color _amber = Color(0xFFE2873A);
const Color _muted = Color(0xFF9A8F86);
const Color _bg = Color(0xFFFFF7F1);

/// Level Kekayaan: level dihitung dari total koin yang dibelanjakan (1 koin = 1 poin).
class LevelPage extends StatelessWidget {
  const LevelPage({super.key, this.profile});

  final Map<String, dynamic>? profile;

  static const int _perLevel = 100;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Map<String, dynamic> p = profile ?? <String, dynamic>{};
    final bool male = (p['gender'] as String?) != 'female';
    final String? photo = (p['photoUrl'] as String?) ?? user?.photoURL;
    final int spent = (p['totalSpent'] as int?) ?? 0;
    final int level = spent ~/ _perLevel;
    final int toNext = _perLevel - (spent % _perLevel);
    final double progress = (spent % _perLevel) / _perLevel;
    final double w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Stack(
            children: <Widget>[
              SizedBox(
                height: 150,
                width: w,
                child: const ResImage('levels_wealth', fit: BoxFit.cover),
              ),
              SafeArea(
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Level Kekayaan',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 30, 22, 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3EA),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'LV.$level',
                                    style: const TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w800,
                                      color: _amber,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFE8F1FB),
                                  ),
                                  child: ClipOval(
                                    child: photo != null
                                        ? Image.network(
                                            photo,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => ResImage(
                                              male ? 'demo_m1' : 'demo_f1',
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '$toNext koin lagi ke level berikutnya',
                              style: const TextStyle(fontSize: 14, color: Color(0xFFB0602A)),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress < 0.03 ? 0.03 : progress,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFEBDDD2),
                                valueColor: const AlwaysStoppedAnimation<Color>(_amber),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text('LV.$level', style: const TextStyle(fontSize: 12, color: _muted)),
                                Text('LV.${level + 1}', style: const TextStyle(fontSize: 12, color: _muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2C4A0),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Level saat ini',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      const Expanded(child: Divider(color: Color(0xFFF0C9A8), thickness: 2)),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFF0C9A8), thickness: 2)),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(flex: 0, child: SizedBox(width: 60, child: Divider(color: Color(0xFFF0C9A8), thickness: 2))),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Text('LV.$level', style: const TextStyle(fontSize: 12, color: _amber, fontWeight: FontWeight.w600)),
                        Text('LV.${level + 1}', style: const TextStyle(fontSize: 12, color: _amber, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _heading('Keuntungan'),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: <Widget>[
                        _perk(Icons.military_tech, 'Lencana level', 'Menampilkan tingkat levelmu di samping nama...', 1, level, badge: true),
                        _perk(Icons.chat_bubble, 'Gelembung chat', 'Pesanmu muncul dalam gelembung khusus', 5, level),
                        _perk(Icons.campaign, 'Pengumuman naik level', 'Semua orang tahu saat kamu naik level', 10, level),
                        _perk(Icons.account_circle, 'Bingkai avatar', 'Hias avatarmu dan tampil beda', 10, level),
                        _perk(Icons.palette, 'Warna nama', 'Namamu tampil berwarna dengan cahaya', 15, level),
                        _perk(Icons.login, 'Efek masuk', 'Masukmu ke room menarik semua perhatian', 20, level),
                        _perk(Icons.monetization_on, 'Hadiah koin', 'Koin ditambahkan saat kamu naik level', 20, level),
                        _perk(Icons.back_hand, 'Keistimewaan khusus', 'Hak istimewa tambahan untuk levelmu', 25, level),
                        _perk(Icons.card_giftcard, 'Segera hadir lebih banyak', 'Nantikan keuntungan lainnya', 0, level, last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _heading('Cara naik level'),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: <Widget>[
                        _how(Icons.account_balance_wallet, 'Belanjakan koin', 'Setiap koin yang kamu belanjakan bernilai 1 poin'),
                        _how(Icons.card_giftcard, 'Kirim hadiah', 'Kirim hadiah di chat atau room'),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 18, 10, 36),
                    child: Text(
                      'Level tidak bernilai yang hadiah ditambahkan ke akunmu otomatis saat kamu naik level.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String t) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: Color(0xFFEBD9C8))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(t, style: const TextStyle(fontSize: 16, color: _ink, fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider(color: Color(0xFFEBD9C8))),
      ],
    );
  }

  Widget _perk(IconData icon, String title, String desc, int lv, int current,
      {bool badge = false, bool last = false}) {
    final bool unlocked = lv > 0 && current >= lv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 62,
            height: 46,
            decoration: BoxDecoration(
              color: last ? const Color(0xFFEFEDF3) : const Color(0xFFFFEFE0),
              borderRadius: BorderRadius.circular(badge ? 12 : 23),
            ),
            child: Icon(icon, color: last ? const Color(0xFFB9B6C6) : _amber, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          if (lv > 0)
            Text('Lv.$lv',
                style: TextStyle(fontSize: 12, color: unlocked ? _amber : _muted)),
          if (lv > 0)
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFB9B6C6)),
        ],
      ),
    );
  }

  Widget _how(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Color(0xFFF2A765), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
