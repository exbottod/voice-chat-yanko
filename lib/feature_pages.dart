import 'package:flutter/material.dart';

import 'res_image.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF9A97B0);
const Color _pink = Color(0xFFFF4F8B);

/// Halaman fitur umum: header, ilustrasi dari res, dan daftar isi.
class FeaturePage extends StatelessWidget {
  const FeaturePage({
    super.key,
    required this.title,
    required this.headerAsset,
    required this.children,
    this.dark = false,
  });

  final String title;
  final String headerAsset;
  final List<Widget> children;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF14101F) : const Color(0xFFF7F5FB),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF14101F) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: dark ? Colors.white : _ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: dark ? Colors.white : _ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: ResImage(headerAsset, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Dompet',
      headerAsset: 'wallet_coin_pile',
      children: <Widget>[
        InfoCard(
          child: Row(
            children: <Widget>[
              const ResImage('wallet_coin_star', width: 46, height: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Saldo koin', style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        InfoCard(
          child: Column(
            children: const <Widget>[
              _Row('Isi ulang koin', 'Segera'),
              Divider(height: 22),
              _Row('Riwayat transaksi', 'Belum ada'),
            ],
          ),
        ),
      ],
    );
  }
}

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Misi',
      headerAsset: 'tasks_checkin_header',
      children: <Widget>[
        InfoCard(
          child: Row(
            children: <Widget>[
              const ResImage('tasks_daily_gift', width: 56, height: 56),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Absen harian',
                      style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Masuk setiap hari untuk mendapat hadiah.',
                      style: TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Absen'),
                ),
              ),
            ],
          ),
        ),
        InfoCard(
          child: Row(
            children: const <Widget>[
              ResImage('tasks_reward_chest', width: 56, height: 52),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Selesaikan misi untuk membuka peti hadiah.',
                  style: TextStyle(color: _ink, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Peringkat',
      headerAsset: 'rankings_podium',
      children: <Widget>[
        for (int i = 1; i <= 3; i++)
          InfoCard(
            child: Row(
              children: <Widget>[
                ResImage('rankings_medal$i', width: 42, height: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Peringkat $i',
                    style: const TextStyle(color: _ink, fontSize: 15),
                  ),
                ),
                const Text('Belum ada', style: TextStyle(color: _muted, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

class NobilityPage extends StatelessWidget {
  const NobilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePage(
      title: 'Bangsawan',
      headerAsset: 'aristo_asalet_banner',
      dark: true,
      children: <Widget>[
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int i) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 124,
                  child: ResImage('aristo_card_${i + 1}', fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 1; i <= 7; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF211A33),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                ResImage('aristo_aristo_$i', width: 44, height: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Bangsawan $i',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                const Icon(Icons.lock, size: 17, color: Colors.white38),
              ],
            ),
          ),
      ],
    );
  }
}

class VisitorsPage extends StatelessWidget {
  const VisitorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: _ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Pengunjung',
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            ResImage('empty_empty_people', width: 220, fit: BoxFit.contain),
            SizedBox(height: 16),
            Text(
              'Belum ada yang mengunjungi profilmu',
              style: TextStyle(color: _muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.left, this.right);

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(left, style: const TextStyle(color: _ink, fontSize: 15))),
        Text(right, style: const TextStyle(color: _muted, fontSize: 13)),
      ],
    );
  }
}
