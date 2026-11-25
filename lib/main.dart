import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'app_assets.dart';
import 'auth_gate.dart';
import 'net_status.dart';
import 'login_page.dart';
import 'native_bridge.dart';
import 'room_page.dart' show RoomPage;

bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }
  await AppLang.load();
  NetStatus.instance.start();
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
      // Layout dikunci: ukuran font/tampilan Android tidak membuat teks dan
      // tab membesar, jadi tampilan selalu sama seperti desain.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mq = MediaQuery.of(context);
        final Widget isi = child ?? const SizedBox.shrink();
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.noScaling),
          child: ValueListenableBuilder<bool>(
            valueListenable: NetStatus.instance.online,
            child: isi,
            builder: (BuildContext ctx, bool tersambung, Widget? page) {
              return Stack(
                children: <Widget>[
                  page ?? const SizedBox.shrink(),
                  // Banner tetap selama internet tidak ada.
                  if (!tersambung)
                    Positioned(
                      top: mq.padding.top + 6,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Tidak ada koneksi internet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

class Room {
  const Room(this.name, this.topic, this.listeners, this.avatars, {this.id});

  final String name;
  final String topic;
  final int listeners;
  final List<String> avatars;
  final String? id;
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Voice Chat Yanko',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          firebaseReady
                              ? 'Pilih room dan mulai ngobrol'
                              : 'Firebase belum aktif',
                          style: TextStyle(
                            color: firebaseReady ? Colors.white60 : Colors.orangeAccent,
                            fontSize: 13,
                          ),
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
      onTap: () async {
        if (!await ensureOnline(context)) {
          return;
        }
        if (!context.mounted) {
          return;
        }
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
