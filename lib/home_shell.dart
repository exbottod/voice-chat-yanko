import 'package:flutter/material.dart';

import 'main.dart' show Room, RoomPage, kRooms;
import 'res_image.dart';

const Color kPink = Color(0xFFFF6F7A);
const Color kInkDark = Color(0xFF14131A);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1;

  static const List<String> _tabs = <String>[
    'Discover',
    'Party',
    'Moments',
    'Messages',
    'Me',
  ];

  static const List<String> _icons = <String>[
    'tabs_discover',
    'tabs_party',
    'tabs_moments',
    'tabs_messages',
    'tabs_me',
  ];

  Widget _body() {
    switch (_index) {
      case 0:
        return const DiscoverTab();
      case 1:
        return const PartyTab();
      case 2:
        return const MomentsTab();
      case 3:
        return const MessagesTab();
      default:
        return const ProfileTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _body(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDEDF2))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _index = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Opacity(
                            opacity: _index == i ? 1 : 0.45,
                            child: ResImage(
                              '${_icons[i]}_${_index == i ? 'on' : 'off'}_v2',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _tabs[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: _index == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _index == i ? kPink : Colors.black45,
                            ),
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
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kInkDark,
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: kPink),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPink,
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  static const List<String> _cards = <String>[
    'demo_f1',
    'demo_f2',
    'demo_f3',
    'demo_f4',
    'demo_f5',
    'demo_f6',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _TabHeader(
            title: 'Discover',
            action: _Pill(icon: Icons.search, label: 'Cari'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.search, size: 18, color: Colors.black38),
                  SizedBox(width: 8),
                  Text(
                    'Cari orang atau room',
                    style: TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: _cards.length,
              itemBuilder: (BuildContext context, int index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ResImage(_cards[index], fit: BoxFit.cover),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MomentsTab extends StatelessWidget {
  const MomentsTab({super.key});

  static const List<String> _moments = <String>[
    'demo_moment_1',
    'demo_moment_2',
    'demo_moment_3',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _TabHeader(
            title: 'Moments',
            action: _Pill(icon: Icons.add_a_photo_outlined, label: 'Post'),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              itemCount: _moments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ClipOval(
                            child: ResImage(
                              'demo_m${index + 1}',
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'User ${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kInkDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ResImage(
                          _moments[index],
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _TabHeader(
            title: 'Messages',
            action: _Pill(icon: Icons.edit_outlined, label: 'Baru'),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const Divider(height: 18, color: Color(0xFFF0F0F4)),
              itemBuilder: (BuildContext context, int index) {
                return Row(
                  children: <Widget>[
                    ClipOval(
                      child: ResImage(
                        'demo_m${index + 1}',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'User ${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kInkDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Halo, masih di room?',
                            style: TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      '19:00',
                      style: TextStyle(fontSize: 10, color: Colors.black38),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PartyTab extends StatelessWidget {
  const PartyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _TabHeader(
            title: 'Party',
            action: _Pill(icon: Icons.add, label: 'Buat room'),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: kRooms.length,
              itemBuilder: (BuildContext context, int index) {
                return _RoomCard(room: kRooms[index], index: index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.index});

  final Room room;
  final int index;

  @override
  Widget build(BuildContext context) {
    final String bg = index.isEven ? 'demo_room_bg_1' : 'demo_room_bg_2';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RoomPage(room: room)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ResImage(bg, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.headphones, size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        '${room.listeners}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  static const List<String> _shortcuts = <String>[
    'me_shortcut_coin',
    'me_shortcut_nobility',
    'me_shortcut_rankings',
    'me_shortcut_tasks',
    'me_shortcut_visitors',
  ];

  static const List<String> _shortcutLabels = <String>[
    'Koin',
    'Nobility',
    'Ranking',
    'Tugas',
    'Pengunjung',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _TabHeader(title: 'Me'),
            Row(
              children: <Widget>[
                ClipOval(
                  child: ResImage('demo_m1', width: 58, height: 58, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Yanko User',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kInkDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID 10872',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.settings_outlined, color: Colors.black45),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(child: ResImage('me_card_wallet', height: 74, fit: BoxFit.contain)),
                const SizedBox(width: 10),
                Expanded(child: ResImage('me_card_vip', height: 74, fit: BoxFit.contain)),
                const SizedBox(width: 10),
                Expanded(child: ResImage('me_card_earnings', height: 74, fit: BoxFit.contain)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  for (int i = 0; i < _shortcuts.length; i++)
                    Column(
                      children: <Widget>[
                        ResImage(_shortcuts[i], width: 26, height: 26),
                        const SizedBox(height: 6),
                        Text(
                          _shortcutLabels[i],
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(child: ResImage('badges_agency_emblem', height: 56)),
                const SizedBox(width: 10),
                Expanded(child: ResImage('badges_monthly_top', height: 56)),
                const SizedBox(width: 10),
                Expanded(child: ResImage('rankings_podium', height: 56)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
