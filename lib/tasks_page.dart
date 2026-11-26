import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'res_image.dart';
import 'system_notice.dart';

const Color _ink = Color(0xFF2A2140);
const Color _muted = Color(0xFF9A97B0);
const Color _pink = Color(0xFFFF4F8B);
const Color _soft = Color(0xFFFFF0F5);

const List<int> _rewards = <int>[10, 20, 30, 50, 80, 100, 200];

/// Misi: check-in harian 7 hari (klaim menambah koin) + misi harian/anggota baru.
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  int _period = 0;
  int _streak = 0; // jumlah hari berturut-turut yang sudah diklaim
  String _lastClaim = '';
  int _todayEarned = 0;
  bool _busy = false;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DocumentReference<Map<String, dynamic>>? get _doc {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  bool get _claimedToday => _lastClaim == _day(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DocumentReference<Map<String, dynamic>>? d = _doc;
    if (d == null) return;
    try {
      final Map<String, dynamic>? m = (await d.get()).data();
      if (m == null || !mounted) return;
      final String last = (m['checkinLast'] as String?) ?? '';
      int streak = (m['checkinStreak'] as int?) ?? 0;
      final DateTime now = DateTime.now();
      final String today = _day(now);
      final String yesterday = _day(now.subtract(const Duration(days: 1)));
      if (last != today && last != yesterday) streak = 0;
      if (streak >= 7 && last != today) streak = 0;
      setState(() {
        _lastClaim = last;
        _streak = streak;
        _todayEarned = last == today ? (m['checkinToday'] as int? ?? 0) : 0;
      });
    } catch (_) {}
  }

  Future<void> _claim() async {
    final DocumentReference<Map<String, dynamic>>? d = _doc;
    if (d == null || _claimedToday || _busy) return;
    setState(() => _busy = true);
    final int next = _streak >= 7 ? 1 : _streak + 1;
    final int reward = _rewards[next - 1];
    try {
      await d.set(<String, dynamic>{
        'coins': FieldValue.increment(reward),
        'checkinStreak': next,
        'checkinLast': _day(DateTime.now()),
        'checkinToday': reward,
      }, SetOptions(merge: true));
      SystemNotice.kirim(
        type: 'checkin',
        emoji: '\u2705',
        title: 'Check-in harian berhasil',
        body: 'Hari ke-$next berhasil. Kamu mendapat +$reward koin.',
      );
      if (!mounted) return;
      setState(() {
        _streak = next;
        _lastClaim = _day(DateTime.now());
        _todayEarned = reward;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-in berhasil, +$reward koin')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal check-in: $e')),
      );
    }
  }

  String get _resetText {
    final DateTime now = DateTime.now();
    final DateTime end = _period == 0
        ? DateTime(now.year, now.month, now.day + 1, 3)
        : (_period == 1
            ? DateTime(now.year, now.month, now.day + (8 - now.weekday), 3)
            : DateTime(now.year, now.month + 1, 1, 3));
    final Duration r = end.difference(now);
    if (r.inDays >= 1) return '${r.inDays}h ${r.inHours % 24}j';
    return '${r.inHours}j ${r.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1EC),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
                height: 250,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFFF8CA8), Color(0xFFFF6F82)],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 20,
                child: ResImage('tasks_checkin_header', width: w * 0.62, fit: BoxFit.contain),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          'CHECK-IN\nHARIAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
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
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Reward check-in harian',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rangkaian check-in $_streak hari',
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            for (int i = 0; i < 7; i++)
                              Expanded(child: _dayCell(i)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _claimedToday || _busy ? null : _claim,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pink,
                              disabledBackgroundColor: const Color(0xFFFFB3CB),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Text(
                              _claimedToday
                                  ? 'Reward hari ini sudah diklaim · kembali besok'
                                  : 'Klaim reward hari ini',
                              style: const TextStyle(fontSize: 14.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDC9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _coin(18),
                          const SizedBox(width: 8),
                          Text(
                            'Diperoleh hari ini: $_todayEarned koin',
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF9A6A00)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    pad: 6,
                    child: Row(
                      children: <Widget>[
                        for (int i = 0; i < 3; i++)
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => setState(() => _period = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _period == i ? _pink : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  const <String>['Harian', 'Mingguan', 'Bulanan'][i],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _period == i ? FontWeight.w700 : FontWeight.w400,
                                    color: _period == i ? Colors.white : _muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Reset dalam $_resetText · reward dibayarkan dalam koin',
                      style: const TextStyle(fontSize: 12.5, color: _muted),
                    ),
                  ),
                  if (_period == 0) ...<Widget>[
                    _questCard(
                      'Kirim pesan ke wanita',
                      '0 / 200',
                      const <int>[80, 80, 160],
                      const <String>['50', '100', '200'],
                    ),
                    _questCard(
                      'Bicara lewat suara/video',
                      '0 mnt / 30 mnt',
                      const <int>[80, 160, 240],
                      const <String>['5 mnt', '15 mnt', '30 mnt'],
                    ),
                  ] else
                    _card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            _period == 1
                                ? 'Misi mingguan belum tersedia'
                                : 'Misi bulanan belum tersedia',
                            style: const TextStyle(color: _muted, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: const <Widget>[
                            Text(
                              'Misi anggota baru',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
                            ),
                            Spacer(),
                            Text('Sekali saja', style: TextStyle(fontSize: 12.5, color: _muted)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _newbie(Icons.person, 'Lengkapi profilmu',
                            'Tambahkan foto profil dan isi nama, gender, dan tanggal lahirmu', 50, '0/1'),
                        _newbie(Icons.photo_library, 'Tambahkan 3 foto album',
                            'Tambahkan minimal 3 foto ke albummu', 50, '0/3'),
                        _newbie(Icons.edit_note, 'Tulis bio-mu',
                            'Tulis beberapa kalimat tentang dirimu di profil', 30, '0/1'),
                        _newbie(Icons.account_balance_wallet, 'Isi ulang koin pertama',
                            'Lakukan isi ulang pertamamu di toko koin', 100, '0/1'),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 18, 12, 36),
                    child: Text(
                      'Progres misi dihitung di server dari aktivitas nyatamu. Waktu reset '
                      'adalah 03:00. Misi harian direset setiap hari, misi mingguan pada hari '
                      'Senin, dan misi bulanan pada tanggal 1 setiap bulan. Hadiah tiap '
                      'tingkat diambil terpisah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: _muted, height: 1.5),
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

  Widget _card({required Widget child, double pad = 16}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _coin(double s) {
    return Container(
      width: s,
      height: s,
      decoration: const BoxDecoration(color: Color(0xFFFFC53D), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        'Y',
        style: TextStyle(fontSize: s * 0.55, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }

  Widget _dayCell(int i) {
    final bool done = i < _streak;
    final bool current = _claimedToday ? i == _streak - 1 : i == _streak;
    final int v = _rewards[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: <Widget>[
          Container(
            height: 66,
            decoration: BoxDecoration(
              color: done ? _soft : const Color(0xFFF5F4F8),
              borderRadius: BorderRadius.circular(12),
              border: current ? Border.all(color: _pink, width: 1.6) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '+$v',
                  style: TextStyle(
                    fontSize: 12,
                    color: done ? _pink : _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (done)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: _pink, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 16, color: Colors.white),
                  )
                else if (i == 6)
                  const Icon(Icons.card_giftcard, size: 26, color: Color(0xFFFF8A3D))
                else
                  _coin(24),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hari ke-${i + 1}',
            style: const TextStyle(fontSize: 9.5, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _questCard(String title, String progress, List<int> rewards, List<String> marks) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
                    const SizedBox(height: 6),
                    Text(progress, style: const TextStyle(fontSize: 13, color: _pink)),
                  ],
                ),
              ),
              _ayo(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (int i = 0; i < rewards.length; i++)
                      Column(
                        children: <Widget>[
                          Text('+${rewards[i]}', style: const TextStyle(fontSize: 12, color: _pink, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _coin(30),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.02,
                    minHeight: 6,
                    backgroundColor: Color(0xFFFFD3E2),
                    valueColor: AlwaysStoppedAnimation<Color>(_pink),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (final String m in marks)
                      Text(m, style: const TextStyle(fontSize: 11.5, color: _muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayo() {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).maybePop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: _pink,
        side: const BorderSide(color: _pink, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('Ayo'),
    );
  }

  Widget _newbie(IconData icon, String title, String desc, int coins, String prog) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle),
            child: Icon(icon, color: _pink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: _muted, height: 1.35)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: LinearProgressIndicator(
                        value: 0,
                        minHeight: 4,
                        backgroundColor: Color(0xFFEFEDF3),
                        valueColor: AlwaysStoppedAnimation<Color>(_pink),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(prog, style: const TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _coin(15),
                  const SizedBox(width: 4),
                  Text('$coins', style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A6A00))),
                ],
              ),
              const SizedBox(height: 8),
              _ayo(),
            ],
          ),
        ],
      ),
    );
  }
}
