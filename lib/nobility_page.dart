import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'res_image.dart';

const Color _gold = Color(0xFFE9B98A);
const Color _bronze = Color(0xFFB87A55);
const Color _panel = Color(0xCC140D22);

class _Tier {
  const _Tier(this.name, this.price, this.perks);

  final String name;
  final int price;
  final List<String> perks;
}

const List<_Tier> _tiers = <_Tier>[
  _Tier('Baron', 5000, <String>[
    'Lencana Baron dan bingkai eksklusif Baron',
    'Banner Baron beranimasi saat kamu masuk room',
    'Lihat semua pengunjung',
    'Kunjungan tak terlihat',
    'Bingkai mewah eksklusif: Hutan Zamrud',
  ]),
  _Tier('Viscount', 12000, <String>[
    'Lencana Viscount dan bingkai eksklusif Viscount',
    'Banner Viscount beranimasi saat kamu masuk room',
    'Lihat semua pengunjung',
    'Kunjungan tak terlihat',
    'Masuk room tak terlihat',
  ]),
  _Tier('Count', 30000, <String>[
    'Lencana Count dan bingkai eksklusif Count',
    'Banner Count beranimasi saat kamu masuk room',
    'Lihat semua pengunjung',
    'Kunjungan dan masuk room tak terlihat',
    'Status online tak terlihat',
  ]),
  _Tier('Marquis', 70000, <String>[
    'Lencana Marquis dan bingkai eksklusif Marquis',
    'Banner Marquis beranimasi saat kamu masuk room',
    'Semua keistimewaan privasi Count',
    'Tersembunyi di peringkat',
  ]),
  _Tier('Duke', 150000, <String>[
    'Lencana Duke dan bingkai eksklusif Duke',
    'Banner Duke beranimasi saat kamu masuk room',
    'Semua keistimewaan privasi Marquis',
  ]),
  _Tier('Prince', 350000, <String>[
    'Lencana Prince dan bingkai eksklusif Prince',
    'Banner Prince beranimasi saat kamu masuk room',
    'Semua keistimewaan privasi Duke',
  ]),
  _Tier('King', 800000, <String>[
    'Lencana King dan bingkai eksklusif King',
    'Banner King beranimasi saat kamu masuk room',
    'Semua keistimewaan Bangsawan',
  ]),
];

String _fmt(int n) {
  final String s = n.toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      b.write('.');
    }
    b.write(s[i]);
  }
  return b.toString();
}

/// Bangsawan: 7 tingkat. Foto profil user sendiri dipasang di bawah frame res.
class NobilityPage extends StatefulWidget {
  const NobilityPage({super.key, this.profile});

  final Map<String, dynamic>? profile;

  @override
  State<NobilityPage> createState() => _NobilityPageState();
}

class _NobilityPageState extends State<NobilityPage> {
  int _i = 0;
  final PageController _pc = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _avatar(String? photo, bool male, double size) {
    final String fallback = male ? 'demo_m1' : 'demo_f1';
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photo != null
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ResImage(fallback, fit: BoxFit.cover),
              )
            : ResImage(fallback, fit: BoxFit.cover),
      ),
    );
  }

  /// Foto user di tengah + frame bangsawan (res) di atasnya.
  Widget _framed(String? photo, bool male, int tier, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _avatar(photo, male, size * 0.66),
          ResImage(
            'aristo_aristo_v2_${tier + 1}',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
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
    final _Tier t = _tiers[_i];

    return Scaffold(
      backgroundColor: const Color(0xFF120A1F),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ResImage('aristo_asalet_bg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Bangsawan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 130, 16, 24),
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            _avatar(photo, male, 52),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Pilih tingkat; keistimewaanmu aktif selama 30 hari.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
                            final bool on = i == _i;
                            return InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                setState(() => _i = i);
                                _pc.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: on
                                      ? const LinearGradient(
                                          colors: <Color>[
                                            Color(0xFFD9976B),
                                            Color(0xFFB96F4C),
                                          ],
                                        )
                                      : null,
                                  color: on
                                      ? null
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    ResImage(
                                      'aristo_aristo_${i + 1}',
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _tiers[i].name,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: on ? 1 : 0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 470,
                        child: PageView.builder(
                          controller: _pc,
                          itemCount: _tiers.length,
                          onPageChanged: (int i) => setState(() => _i = i),
                          itemBuilder: (BuildContext context, int i) {
                            final _Tier tier = _tiers[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    ResImage(
                                      'aristo_card_${i + 1}',
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.45),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              _framed(photo, male, i, 120),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 14,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Text(
                                                        'Tingkat ${i + 1}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      Row(
                                                        children: <Widget>[
                                                          ResImage(
                                                            'aristo_aristo_${i + 1}',
                                                            width: 26,
                                                            height: 26,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            tier.name,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 26,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: <Widget>[
                                                          Container(
                                                            width: 20,
                                                            height: 20,
                                                            decoration:
                                                                const BoxDecoration(
                                                              color: Color(
                                                                0xFFFFC53D,
                                                              ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            alignment:
                                                                Alignment
                                                                    .center,
                                                            child: const Text(
                                                              'Y',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            _fmt(tier.price),
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 22,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          const Text(
                                                            '/ 30 hari',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white70,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          for (final String perk in tier.perks)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  const Icon(
                                                    Icons.check_circle,
                                                    size: 20,
                                                    color: _gold,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      perk,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Banner masuk room',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          gradient: LinearGradient(
                            colors: <Color>[
                              _gold.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            _framed(photo, male, _i, 74),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: name,
                                      style: const TextStyle(
                                        color: Color(0xFFFFE08A),
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' masuk ke room',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Membeli tingkat yang sama lagi memperpanjangnya 30 hari. '
                        'Jika naik tingkat, sisa waktumu dipindahkan ke tingkat baru '
                        'sebanding dengan harga. Kamu bisa mengaktifkan mode tak '
                        'terlihat di Setelan → Privasi.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => _buy(context, t),
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: <Color>[_gold, _bronze],
                            ),
                          ),
                          child: Text(
                            'Jadi ${t.name} · ${_fmt(t.price)} koin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  void _buy(BuildContext context, _Tier t) {
    final int coins = (widget.profile?['coins'] as int?) ?? 0;
    final bool enough = coins >= t.price;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Jadi ${t.name}'),
        content: Text(
          enough
              ? 'Pembelian bangsawan belum tersedia di versi ini.'
              : 'Koinmu belum cukup. Kamu punya ${_fmt(coins)} koin, '
                  'butuh ${_fmt(t.price)} koin.',
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
