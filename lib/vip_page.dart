import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'res_image.dart';

const Color _gold = Color(0xFFFFC94A);
const Color _goldDeep = Color(0xFFE9A92B);
const Color _panel = Color(0xCC1A1209);
const Color _panelLine = Color(0x55FFC94A);

class _Tier {
  const _Tier(this.level, this.coins, this.perks);

  final int level;
  final int coins;
  final List<String> perks;
}

const List<_Tier> _tiers = <_Tier>[
  _Tier(1, 3000, <String>[
    'Lencana VIP1',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
  ]),
  _Tier(2, 6000, <String>[
    'Lencana VIP2',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
    'Bingkai VIP2',
  ]),
  _Tier(3, 9000, <String>[
    'Lencana VIP3',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
    'Bingkai VIP3 beranimasi',
  ]),
  _Tier(4, 15000, <String>[
    'Lencana VIP4',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
    'Lihat semua yang mengunjungi profilmu',
    'Bingkai VIP4 beranimasi',
  ]),
  _Tier(5, 24000, <String>[
    'Lencana VIP5',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
    'Lihat semua yang mengunjungi profilmu',
    'Bingkai VIP5 beranimasi',
    'Efek masuk beranimasi di room',
  ]),
  _Tier(6, 36000, <String>[
    'Lencana VIP6',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
    'Lihat semua yang mengunjungi profilmu',
    'Bingkai VIP6 beranimasi',
    'Efek masuk beranimasi layar penuh saat kamu masuk room',
  ]),
  _Tier(7, 54000, <String>[
    'Lencana VIP7',
    'Nama emas di room dan chat',
    'Gelembung chat VIP',
    'Lihat semua yang mengunjungi profilmu',
    'Bingkai VIP7 beranimasi',
    'Efek masuk beranimasi layar penuh saat kamu masuk room',
  ]),
];

String _fmt(int n) {
  final String s = n.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Layar VIP & SVIP. VIP ditentukan dari total koin yang dibelanjakan.
class VipPage extends StatefulWidget {
  const VipPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  int _selected = 6;

  int get _spent => (widget.profile['totalSpent'] as num?)?.toInt() ?? 0;

  int get _currentLevel {
    int lv = 0;
    for (final _Tier t in _tiers) {
      if (_spent >= t.coins) lv = t.level;
    }
    return lv;
  }

  @override
  Widget build(BuildContext context) {
    final String name = (widget.profile['displayName'] as String?)?.isNotEmpty == true
        ? widget.profile['displayName'] as String
        : 'My name';
    final bool male = (widget.profile['gender'] as String?) != 'female';
    final String avatar = male ? 'demo_m1' : 'demo_f1';
    final _Tier tier = _tiers[_selected];
    final int cur = _currentLevel;
    final _Tier? next = cur >= _tiers.length ? null : _tiers[cur];
    final double progress =
        next == null ? 1 : (_spent / next.coins).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0805),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Opacity(
              opacity: 0.9,
              child: const ResImage('vip_vip', fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 48,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'VIP & SVIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 70, 16, 24),
                    children: <Widget>[
                      _box(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                ClipOval(
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: ResImage(avatar, fit: BoxFit.cover),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: <Widget>[
                                          const _Coin(),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Total pengeluaran: ${_fmt(_spent)} koin',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                backgroundColor: const Color(0x66FFFFFF),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(_gold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              next == null
                                  ? 'Kamu sudah mencapai VIP tertinggi'
                                  : 'Habiskan ${_fmt(next.coins - _spent)} koin lagi untuk VIP${next.level} (${_fmt(_spent)} / ${_fmt(next.coins)})',
                              style: const TextStyle(
                                color: Color(0xFFFFE2A0),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _tiers.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final bool on = i == _selected;
                            return GestureDetector(
                              onTap: () => setState(() => _selected = i),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  gradient: on
                                      ? const LinearGradient(
                                          colors: <Color>[
                                            Color(0xFF6C3BD8),
                                            Color(0xFF2B1A66),
                                          ],
                                        )
                                      : null,
                                  color: on ? null : const Color(0x33FFFFFF),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: on ? Colors.white70 : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  'VIP${_tiers[i].level}',
                                  style: TextStyle(
                                    color: on ? Colors.white : Colors.white70,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _box(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 104,
                                  height: 104,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: <Widget>[
                                      ClipOval(
                                        child: SizedBox(
                                          width: 74,
                                          height: 74,
                                          child: ResImage(avatar, fit: BoxFit.cover),
                                        ),
                                      ),
                                      const ResImage(
                                        'vip_crown',
                                        width: 104,
                                        height: 104,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'VIP${tier.level}',
                                        style: const TextStyle(
                                          color: _gold,
                                          fontSize: 34,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Row(
                                        children: <Widget>[
                                          const _Coin(),
                                          const SizedBox(width: 6),
                                          Text(
                                            _fmt(tier.coins),
                                            style: const TextStyle(
                                              color: _gold,
                                              fontSize: 20,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'total pengeluaran',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (final String perk in tier.perks)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(top: 1),
                                      decoration: const BoxDecoration(
                                        color: _gold,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Color(0xFF3A2400),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        perk,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 170,
                                width: double.infinity,
                                child: ResImage(
                                  'vip_vip_card_${tier.level}',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[Color(0xFFFFD36B), _goldDeep],
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.play_circle_fill,
                              color: Color(0xFF2A1A00),
                              size: 22,
                            ),
                            label: const Text(
                              'Lihat masuk megah',
                              style: TextStyle(
                                color: Color(0xFF2A1A00),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Tingkat',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      _box(
                        pad: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < _tiers.length; i++)
                              InkWell(
                                onTap: () => setState(() => _selected = i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == _selected
                                        ? const Color(0x33FFC94A)
                                        : null,
                                    border: i == 0
                                        ? null
                                        : const Border(
                                            top: BorderSide(color: Color(0x22FFFFFF)),
                                          ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7A4A12),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: _gold),
                                        ),
                                        child: Text(
                                          'V${_tiers[i].level}',
                                          style: const TextStyle(
                                            color: _gold,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          '${_fmt(_tiers[i].coins)} koin',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        cur >= _tiers[i].level
                                            ? Icons.check_circle
                                            : Icons.lock,
                                        size: 17,
                                        color: cur >= _tiers[i].level
                                            ? _gold
                                            : Colors.white38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '• VIP tidak dibeli: VIP diraih permanen dari total koin yang kamu belanjakan sejak bergabung, dan tidak pernah turun.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Yang dihitung: hadiah, pesan, panggilan, toko barang, dan Bangsawan. Menukar berlian ke koin tidak dihitung.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({
    required Widget child,
    EdgeInsets pad = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _panelLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text(
        'Y',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF7A4A00),
        ),
      ),
    );
  }
}
