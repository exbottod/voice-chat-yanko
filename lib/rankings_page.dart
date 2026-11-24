import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'res_image.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);
const Color _pink = Color(0xFFFF4F8B);

/// Peringkat: tab Kekayaan/Pesona/Room/CP, periode Harian/Mingguan/Bulanan.
class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key, this.profile});

  final Map<String, dynamic>? profile;

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  int _tab = 0;
  int _period = 0;
  bool _desc = true;

  static const List<String> _tabs = <String>['Kekayaan', 'Pesona', 'Room', 'CP'];
  static const List<String> _periods = <String>['Harian', 'Mingguan', 'Bulanan'];

  String get _remaining {
    final DateTime now = DateTime.now().toUtc();
    DateTime end;
    if (_period == 0) {
      end = DateTime.utc(now.year, now.month, now.day + 1);
    } else if (_period == 1) {
      end = DateTime.utc(now.year, now.month, now.day + (8 - now.weekday));
    } else {
      end = DateTime.utc(now.year, now.month + 1, 1);
    }
    final Duration d = end.difference(now);
    if (d.inDays >= 1) {
      return '${d.inDays}h ${d.inHours % 24}j';
    }
    return '${d.inHours}j ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Map<String, dynamic> p = widget.profile ?? <String, dynamic>{};
    final String name = (p['displayName'] as String?)?.isNotEmpty == true
        ? p['displayName'] as String
        : (user?.displayName ?? 'My name');
    final bool male = (p['gender'] as String?) != 'female';
    final String? photo = (p['photoUrl'] as String?) ?? user?.photoURL;
    final int coins = (p['coins'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFFF7AA8), Color(0xFFD16BFF)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 32),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 4),
                        for (int i = 0; i < _tabs.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: InkWell(
                              onTap: () => setState(() => _tab = i),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    _tabs[i],
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: _tab == i ? 1 : 0.7,
                                      ),
                                      fontSize: 17,
                                      fontWeight: _tab == i
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 22,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: _tab == i
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: <Widget>[
                              for (int i = 0; i < _periods.length; i++)
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => setState(() => _period = i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _period == i
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _periods[i],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _period == i
                                            ? _pink
                                            : Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _desc = !_desc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  _period == 0
                                      ? 'Hari ini'
                                      : (_period == 1 ? 'Minggu ini' : 'Bulan ini'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _desc ? Icons.swap_vert : Icons.swap_vert,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: <Widget>[
                          const Text('🇮🇩', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          const Text(
                            'ID',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Berakhir dalam $_remaining',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => _showRules(context),
                            child: const Row(
                              children: <Widget>[
                                Text(
                                  'Aturan reward',
                                  style: TextStyle(fontSize: 13, color: _muted),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.help_outline, size: 17, color: _muted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const ResImage(
                                'tasks_reward_chest',
                                width: 240,
                                height: 220,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Belum ada siapa pun di sini pada periode ini',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Masuk peringkat lewat pesan, panggilan, atau hadiah.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: _muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFF0F6),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Text('-',
                                    style: TextStyle(color: _muted, fontSize: 14)),
                                const SizedBox(width: 22),
                                Container(
                                  width: 60,
                                  height: 60,
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
                                        : ResImage(
                                            male ? 'demo_m1' : 'demo_f1',
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFC53D),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Y',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _tab == 0 ? '$coins' : '0',
                                  style: const TextStyle(fontSize: 14, color: _ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Kamu tidak masuk peringkat periode ini',
                              style: TextStyle(fontSize: 12, color: _pink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRules(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aturan reward'),
        content: const Text(
          'Peringkat dihitung dari aktivitas selama periode berjalan: '
          'pesan, panggilan, dan hadiah. Reward diberikan setelah periode berakhir '
          'kepada peringkat teratas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}
