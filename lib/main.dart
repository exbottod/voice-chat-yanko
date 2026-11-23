import 'package:flutter/material.dart';

import 'native_bridge.dart';

void main() {
  runApp(const YankoApp());
}

const Color kBackground = Color(0xFF0E0F14);
const Color kSurface = Color(0xFF1A1C25);
const Color kAccent = Color(0xFF7C5CFF);

class YankoApp extends StatelessWidget {
  const YankoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Chat Yanko',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Room {
  const Room(this.name, this.topic, this.listeners, this.avatars);

  final String name;
  final String topic;
  final int listeners;
  final List<String> avatars;
}

const List<Room> kRooms = <Room>[
  Room('Yanko Lounge', 'Ngobrol santai bareng semua', 24, <String>['A', 'R', 'D', 'S']),
  Room('Music Corner', 'Request lagu dan nyanyi bareng', 12, <String>['J', 'M', 'T']),
  Room('Gaming Squad', 'Mabar malam ini jam 9', 8, <String>['B', 'K']),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Voice Chat Yanko',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pilih room dan mulai ngobrol',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: kAccent.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_outline, color: kAccent),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: kRooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (BuildContext context, int index) {
                    final Room room = kRooms[index];
                    return RoomCard(room: room);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoomPage(room: room),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.headphones, size: 13, color: kAccent),
                      const SizedBox(width: 4),
                      Text(
                        '${room.listeners}',
                        style: const TextStyle(fontSize: 12, color: kAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              room.topic,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                for (int i = 0; i < room.avatars.length; i++)
                  Align(
                    widthFactor: 0.65,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: kAccent.withValues(alpha: 0.35),
                      child: Text(
                        room.avatars[i],
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                const Spacer(),
                const Text(
                  'Gabung',
                  style: TextStyle(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.room});

  final Room room;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  bool _micOn = true;
  bool _speakerOn = true;
  String _route = 'unknown';

  @override
  void initState() {
    super.initState();
    VoiceNative.currentRoute().then((String route) {
      if (mounted) {
        setState(() => _route = route);
      }
    });
  }

  Future<void> _toggleSpeaker() async {
    final bool next = !_speakerOn;
    setState(() => _speakerOn = next);
    await VoiceNative.setSpeakerphone(next);
    final String route = await VoiceNative.currentRoute();
    if (mounted) {
      setState(() => _route = route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          widget.room.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.room.listeners} pendengar - audio: $_route',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: widget.room.avatars.length + 3,
                  itemBuilder: (BuildContext context, int index) {
                    final List<String> names = <String>[
                      ...widget.room.avatars,
                      'Y',
                      'N',
                      'F',
                    ];
                    final bool isSpeaking = index == 0;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSpeaking ? kAccent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: kAccent.withValues(alpha: 0.25),
                            child: Text(
                              names[index],
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'User ${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _ControlButton(
                    icon: _micOn ? Icons.mic : Icons.mic_off,
                    active: _micOn,
                    onTap: () => setState(() => _micOn = !_micOn),
                  ),
                  const SizedBox(width: 18),
                  _ControlButton(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    active: _speakerOn,
                    onTap: _toggleSpeaker,
                  ),
                  const SizedBox(width: 18),
                  _ControlButton(
                    icon: Icons.call_end,
                    active: false,
                    danger: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color bg = danger
        ? const Color(0xFFE5484D)
        : active
            ? kAccent
            : kSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
