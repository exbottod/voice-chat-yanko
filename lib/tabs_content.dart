import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'app_shell.dart' show kInkMain, kMutedMain, kPinkMain;
import 'auth_service.dart';
import 'edit_profile_page.dart';
import 'net_status.dart';
import 'settings_page.dart';
import 'rankings_page.dart';
import 'search_user_page.dart';
import 'create_room_page.dart';
import 'collection_page.dart';
import 'store_page.dart';
import 'level_page.dart';
import 'tasks_page.dart';
import 'nobility_page.dart';
import 'vip_page.dart';
import 'invite_page.dart';
import 'feature_pages.dart';
import 'login_page.dart' show LoginPage;
import 'main.dart' show Room;
import 'room_page.dart' show RoomPage;
import 'room_session.dart';
import 'profile_screen.dart';
import 'profile_store.dart';
import 'avatar_image.dart';
import 'res_image.dart';

const LinearGradient _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0xFFFFE6EE), Color(0xFFFFF7F0), Colors.white],
  stops: <double>[0, 0.35, 0.7],
);

class _GradientPage extends StatelessWidget {
  const _GradientPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _bgGradient),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

// ---------------------------------------------------------------- PARTY

class PartyContent extends StatefulWidget {
  const PartyContent({super.key});

  @override
  State<PartyContent> createState() => _PartyContentState();
}

class _PartyContentState extends State<PartyContent> {
  int _tab = 1; // 0 = Mine, 1 = Popular
  static const List<String> _tabs = <String>['Mine', 'Popular'];

  /// Buka room milik sendiri bila sudah ada, kalau belum buat room baru.
  Future<void> _plusPressed() async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> mine = await FirebaseFirestore
          .instance
          .collection('rooms')
          .where('ownerId', isEqualTo: u.uid)
          .limit(1)
          .get();
      if (!mounted) {
        return;
      }
      if (mine.docs.isNotEmpty) {
        _openRoom(mine.docs.first.id, mine.docs.first.data());
        return;
      }
    } catch (_) {
      // lanjut ke pembuatan room
    }
    if (!mounted || !await ensureOnline(context)) {
      return;
    }
    final Object? made = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(builder: (_) => const CreateRoomPage()),
    );
    if (!mounted) {
      return;
    }
    if (made is String && made.isNotEmpty) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
            .instance
            .collection('rooms')
            .doc(made)
            .get();
        if (mounted && doc.exists) {
          _openRoom(made, doc.data() ?? <String, dynamic>{});
        }
      } catch (_) {}
    }
  }

  Future<void> _openRoom(String id, Map<String, dynamic> data) async {
    if (!await ensureOnline(context) || !mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomPage(
          room: Room(
            (data['title'] as String?) ?? 'Room',
            (data['topic'] as String?) ?? '',
            (data['listeners'] as num?)?.toInt() ?? 0,
            const <String>['A'],
            id: id,
          ),
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return _GradientPage(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                child: Row(
                  children: <Widget>[
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
                                  fontSize: _tab == i ? 19 : 17,
                                  fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w600,
                                  color: _tab == i
                                      ? kInkMain
                                      : kMutedMain.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 30,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: _tab == i ? kPinkMain : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Spacer(),
                    InkResponse(
                      onTap: _plusPressed,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: kInkMain.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 22, color: kInkMain),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkResponse(
                      onTap: () => _push(const SearchUserPage()),
                      child: const Icon(Icons.search, size: 26, color: kInkMain),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: const AspectRatio(
                        aspectRatio: 4 / 1,
                        child: ResImage(
                          'chat_weekly_star_256',
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _CategoryCard(
                            label: 'Top Supporter',
                            color: const Color(0xFFFFC53D),
                            onTap: () => _push(const RankingsPage(initialTab: 1)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CategoryCard(
                            label: 'Charm Star',
                            color: const Color(0xFFFF7AAE),
                            onTap: () => _push(const RankingsPage(initialTab: 0)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CategoryCard(
                            label: 'Top Room',
                            color: const Color(0xFF5AA9F5),
                            onTap: () => _push(const RankingsPage(initialTab: 2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _RoomGrid(
                        mineOnly: _tab == 0,
                        emptyText: _tab == 0
                        ? 'Kamu belum punya room. Tekan tombol + untuk membuat room.'
                        : 'Belum ada room. Jadilah yang pertama membuat room.'),
                  ],
                ),
              ),
            ],
          ),
          const Positioned(
            right: 14,
            bottom: 16,
            child: _MinimizedBubble(),
          ),
        ],
      ),
    );
  }
}

/// Bulatan room yang sedang diperkecil: ketuk untuk kembali ke room dengan
/// riwayat chat yang masih utuh.
class _MinimizedBubble extends StatelessWidget {
  const _MinimizedBubble();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Room?>(
      valueListenable: RoomSession.minimized,
      builder: (BuildContext context, Room? room, Widget? _) {
        if (room == null) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: () async {
            if (!await ensureOnline(context) || !context.mounted) {
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => RoomPage(room: room)),
            );
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: kPinkMain, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: ClipOval(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: ResImage('demo_m1', fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: kPinkMain,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: 6,
                    child: _bubble(const Color(0xFFF3F0FF), 26),
                  ),
                  _bubble(Colors.white, 32),
                  Positioned(
                    right: 6,
                    child: _bubble(const Color(0xFFFFF0F5), 26),
                  ),
                ],
              ),
            ),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child: Icon(Icons.person, size: size * 0.6, color: const Color(0xFFB9B3D6)),
    );
  }
}

class _RoomGrid extends StatelessWidget {
  const _RoomGrid({required this.emptyText, this.mineOnly = false});

  final String emptyText;
  final bool mineOnly;

  /// Jumlah anggota aktif per room (detak kehadiran < 60 detik).
  ///
  /// Membaca sub-koleksi members tiap room secara langsung (tanpa query
  /// collection group yang butuh indeks khusus). Dihitung ulang tiap 15 detik
  /// supaya anggota yang berhenti mendetak otomatis hilang.
  Stream<Map<String, int>> _live() {
    final StreamController<Map<String, int>> ctl =
        StreamController<Map<String, int>>();
    final Map<String, List<Timestamp?>> beats = <String, List<Timestamp?>>{};
    final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
        subs =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomsSub;
    Timer? tick;

    void emit() {
      if (ctl.isClosed) {
        return;
      }
      final int now = DateTime.now().millisecondsSinceEpoch;
      final Map<String, int> out = <String, int>{};
      beats.forEach((String roomId, List<Timestamp?> list) {
        int n = 0;
        for (final Timestamp? t in list) {
          final int ms = t?.millisecondsSinceEpoch ?? now;
          if (now - ms < 60000) {
            n++;
          }
        }
        if (n > 0) {
          out[roomId] = n;
        }
      });
      ctl.add(out);
    }

    ctl.onListen = () {
      roomsSub = FirebaseFirestore.instance
          .collection('rooms')
          .where('isOpen', isEqualTo: true)
          .limit(40)
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> snap) {
        final Set<String> ids =
            snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.id).toSet();
        for (final String gone in subs.keys.toList()) {
          if (!ids.contains(gone)) {
            subs.remove(gone)?.cancel();
            beats.remove(gone);
          }
        }
        for (final String id in ids) {
          if (subs.containsKey(id)) {
            continue;
          }
          subs[id] = FirebaseFirestore.instance
              .collection('rooms')
              .doc(id)
              .collection('members')
              .snapshots()
              .listen((QuerySnapshot<Map<String, dynamic>> m) {
            beats[id] = <Timestamp?>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> d in m.docs)
                d.data()['beat'] as Timestamp?,
            ];
            emit();
          }, onError: (Object _) {});
        }
        emit();
      }, onError: (Object _) {});
      tick = Timer.periodic(const Duration(seconds: 15), (_) => emit());
    };
    ctl.onCancel = () {
      tick?.cancel();
      roomsSub?.cancel();
      for (final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> sub
          in subs.values) {
        sub.cancel();
      }
      subs.clear();
    };
    return ctl.stream;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _live(),
      builder: (BuildContext context, AsyncSnapshot<Map<String, int>> liveSnap) {
        final Map<String, int> live = liveSnap.data ?? <String, int>{};
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .where('isOpen', isEqualTo: true)
              .limit(40)
              .snapshots(),
          builder: (BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
            if (snap.hasError) {
              return _empty();
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator(color: kPinkMain)),
              );
            }
            final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snap.data!.docs.where((QueryDocumentSnapshot<Map<String, dynamic>> d) {
              if (mineOnly) {
                return (d.data()['ownerId'] as String?) == myUid;
              }
              // Room tanpa anggota aktif disembunyikan dari daftar Party.
              return (live[d.id] ?? 0) > 0;
            }).toList()
                  ..sort((QueryDocumentSnapshot<Map<String, dynamic>> a,
                      QueryDocumentSnapshot<Map<String, dynamic>> b) {
                    final int ca = live[a.id] ?? 0;
                    final int cb = live[b.id] ?? 0;
                    if (ca != cb) {
                      return cb.compareTo(ca);
                    }
                    final Timestamp? ta = a.data()['createdAt'] as Timestamp?;
                    final Timestamp? tb = b.data()['createdAt'] as Timestamp?;
                    return (tb?.millisecondsSinceEpoch ?? 0)
                        .compareTo(ta?.millisecondsSinceEpoch ?? 0);
                  });
            if (docs.isEmpty) {
              return _empty();
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemCount: docs.length,
              itemBuilder: (BuildContext context, int i) => _RoomTile(
                data: docs[i].data(),
                id: docs[i].id,
                live: live[docs[i].id] ?? 0,
              ),
            );
          },
        );
      },
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: <Widget>[
          const ResImage('empty_empty_rooms', width: 190, height: 190),
          const SizedBox(height: 8),
          Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: kMutedMain, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.data, required this.id, this.live = 0});

  final Map<String, dynamic> data;
  final String id;
  final int live;

  Future<void> _open(BuildContext context) async {
    final String pass = (data['password'] as String?) ?? '';
    final bool open = (data['isOpen'] as bool?) ?? true;
    if (pass.isNotEmpty && !open) {
      final TextEditingController c = TextEditingController();
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Room terkunci', style: TextStyle(fontSize: 16, color: kInkMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Masukkan sandi 6 angka untuk masuk room ini.',
                style: TextStyle(fontSize: 12.5, color: kMutedMain),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 8, color: kInkMain),
                decoration: const InputDecoration(hintText: '••••••', counterText: ''),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal', style: TextStyle(color: kMutedMain)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(c.text == pass),
              child: const Text('Masuk', style: TextStyle(color: kPinkMain)),
            ),
          ],
        ),
      );
      if (ok != true) {
        if (context.mounted && ok == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sandi salah')),
          );
        }
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomPage(
          room: Room(
            (data['title'] as String?) ?? 'Room',
            (data['topic'] as String?) ?? '',
            (data['listeners'] as num?)?.toInt() ?? 0,
            const <String>['A'],
            id: id,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = (data['title'] as String?) ?? 'Room';
    final String topic = (data['topic'] as String?) ?? '';
    final int listeners = live > 0 ? live : ((data['listeners'] as num?)?.toInt() ?? 0);
    final String cover = (data['coverAsset'] as String?) ?? 'demo_room_bg_1';
    final String coverB64 = (data['coverImage'] as String?) ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  coverB64.isEmpty
                      ? ResImage(cover, fit: BoxFit.cover)
                      : Image.memory(
                          base64Decode(coverB64),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                              ResImage(cover, fit: BoxFit.cover),
                        ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.headphones, size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '$listeners',
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kInkMain,
            ),
          ),
          if (topic.isNotEmpty)
            Text(
              topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: kMutedMain),
            ),
        ],
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: <Widget>[
          ResImage('empty_empty_rooms', width: 230, height: 230),
          SizedBox(height: 8),
          Text(
            'Belum ada room terbuka',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: kInkMain,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'Room dibuka oleh pemilik agensi. Room yang terbuka akan muncul di sini',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: kMutedMain, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- JELAJAHI / MOMEN / PESAN

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({
    required this.title,
    required this.asset,
    required this.heading,
    required this.body,
    this.action,
  });

  final String title;
  final String asset;
  final String heading;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _GradientPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 18, 4),
            child: Row(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kInkMain,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ResImage(asset, width: 210, height: 210),
                  const SizedBox(height: 10),
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: kInkMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: kMutedMain,
                        height: 1.5,
                      ),
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
}

class DiscoverContent extends StatelessWidget {
  const DiscoverContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EmptyPage(
      title: 'Jelajahi',
      asset: 'empty_empty_search',
      heading: 'Belum ada yang bisa dijelajahi',
      body: 'Orang dan room menarik akan muncul di sini',
      action: Icon(Icons.search, size: 28, color: kInkMain),
    );
  }
}

class MomentsContent extends StatelessWidget {
  const MomentsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EmptyPage(
      title: 'Momen',
      asset: 'empty_empty_photos',
      heading: 'Belum ada momen',
      body: 'Bagikan momen pertamamu dan lihat momen temanmu',
      action: Icon(Icons.add_a_photo_outlined, size: 26, color: kInkMain),
    );
  }
}

class MessagesContent extends StatelessWidget {
  const MessagesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EmptyPage(
      title: 'Pesan',
      asset: 'empty_empty_messages',
      heading: 'Belum ada pesan',
      body: 'Percakapanmu dengan teman akan muncul di sini',
    );
  }
}

// ------------------------------------------------------------------ SAYA

class MeContent extends StatelessWidget {
  const MeContent({super.key, required this.profile, required this.onRefresh});

  final Map<String, dynamic>? profile;
  final Future<void> Function() onRefresh;

  static const List<List<String>> _menu = <List<String>>[
    <String>['Edit profil', 'edit'],
    <String>['Undang teman', 'gift'],
    <String>['Keluargaku', 'family'],
    <String>['Agensiku', 'agency'],
    <String>['Peringkat', 'trophy'],
    <String>['Perlengkapan', 'bag'],
    <String>['Koleksi', 'collection'],
    <String>['Hewan peliharaanku', 'paw'],
    <String>['Levelku', 'level'],
    <String>['Pusat verifikasi', 'verify'],
    <String>['Bagikan', 'share'],
    <String>['Setelan', 'settings'],
  ];

  IconData _icon(String key) {
    switch (key) {
      case 'edit':
        return Icons.edit_note;
      case 'collection':
        return Icons.collections_bookmark_outlined;
      case 'gift':
        return Icons.card_giftcard;
      case 'family':
        return Icons.groups_outlined;
      case 'agency':
        return Icons.apartment_outlined;
      case 'trophy':
        return Icons.emoji_events_outlined;
      case 'bag':
        return Icons.shopping_bag_outlined;
      case 'paw':
        return Icons.pets_outlined;
      case 'level':
        return Icons.trending_up;
      case 'verify':
        return Icons.crop_free;
      case 'share':
        return Icons.share_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  String? _trailing(String label) {
    switch (label) {
      case 'Keluargaku':
        return 'Segera';
      case 'Levelku':
        return 'Lv.0';
      case 'Pusat verifikasi':
        return 'Belum terverifikasi';
      default:
        return null;
    }
  }

  int _completion(Map<String, dynamic> p, User? user) {
    int done = 0;
    if ((p['displayName'] as String? ?? '').isNotEmpty) {
      done += 25;
    }
    if (p['photoUrl'] != null || user?.photoURL != null) {
      done += 25;
    }
    if ((p['birthDate'] as String? ?? '').isNotEmpty) {
      done += 25;
    }
    if ((p['gender'] as String? ?? '').isNotEmpty) {
      done += 25;
    }
    return done;
  }

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(profile: profile ?? <String, dynamic>{}),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Map<String, dynamic> p = profile ?? <String, dynamic>{};
    final String name = (p['displayName'] as String?)?.isNotEmpty == true
        ? p['displayName'] as String
        : (user?.displayName ?? 'My name');
    final String gender = (p['gender'] as String?) ?? 'male';
    final int age = ProfileStore.ageFromBirth((p['birthDate'] as String?) ?? '');
    final String pid =
        (p['publicId'] as String?) ?? ProfileStore.publicId(user?.uid ?? '0');
    final int coins = (p['coins'] as int?) ?? 30;
    final int pct = _completion(p, user);
    final String? photo = (p['photoUrl'] as String?) ?? user?.photoURL;

    return _GradientPage(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: <Widget>[
            InkWell(
              onTap: () => _openProfile(context),
              child: Row(
                children: <Widget>[
                  _Avatar(photo: photo, size: 62),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kInkMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _GenderBadge(gender: gender, age: age),
                        const SizedBox(height: 4),
                        Text(
                          'ID:$pid · Lihat atau edit',
                          style: const TextStyle(fontSize: 11, color: kMutedMain),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: kMutedMain, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text(
                        'Kelengkapan profil',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kInkMain,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kPinkMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFFFD9E6),
                      valueColor: const AlwaysStoppedAnimation<Color>(kPinkMain),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    pct >= 100 ? 'Profilmu sudah lengkap' : 'Berikutnya: Foto profil',
                    style: const TextStyle(fontSize: 11, color: kMutedMain),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: <Widget>[
                      ResImage('me_shortcut_coin', width: 16, height: 16),
                      SizedBox(width: 5),
                      Text(
                        'Lengkapi untuk mendapat 100 koin',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB7791F),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _BannerCard(
                    asset: 'me_card_wallet',
                    title: 'Dompet',
                    footer: '$coins ›',
                    coinIcon: true,
                    onTap: () => _go(context, WalletPage(coins: coins)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BannerCard(
                    asset: 'me_card_vip',
                    title: 'VIP & SVIP',
                    footer: 'Gabung ›',
                    onTap: () => _go(
                      context,
                      VipPage(profile: profile ?? <String, dynamic>{}),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _Shortcut(
                    asset: 'me_shortcut_tasks',
                    label: 'Misi',
                    onTap: () => _go(context, const TasksPage()),
                  ),
                  _Shortcut(
                    asset: 'me_shortcut_rankings',
                    label: 'Peringkat',
                    onTap: () => _go(context, RankingsPage(profile: profile)),
                  ),
                  _Shortcut(
                    asset: 'me_shortcut_nobility',
                    label: 'Bangsawan',
                    onTap: () => _go(context, NobilityPage(profile: profile)),
                  ),
                  _Shortcut(
                    asset: 'me_shortcut_visitors',
                    label: 'Pengunjung',
                    onTap: () => _go(context, const VisitorsPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: <Widget>[
                  for (final List<String> item in _menu)
                    InkWell(
                      onTap: () {
                        if (item[0] == 'Edit profil') {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EditProfilePage(
                                profile: profile ?? <String, dynamic>{},
                              ),
                            ),
                          );
                        } else if (item[0] == 'Undang teman') {
                          _go(
                            context,
                            InvitePage(profile: profile ?? <String, dynamic>{}),
                          );
                        } else if (item[0] == 'Peringkat') {
                          _go(context, RankingsPage(profile: profile));
                        } else if (item[0] == 'Levelku') {
                          _go(context, LevelPage(profile: profile));
                        } else if (item[0] == 'Koleksi') {
                          _go(context, const CollectionPage());
                        } else if (item[0] == 'Perlengkapan') {
                          _go(context, const StorePage());
                        } else if (item[0] == 'Setelan') {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsPage(),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(_icon(item[1]), size: 20, color: kInkMain),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item[0],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: kInkMain,
                                ),
                              ),
                            ),
                            if (_trailing(item[0]) != null)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: _trailing(item[0]) == 'Segera'
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      )
                                    : EdgeInsets.zero,
                                decoration: _trailing(item[0]) == 'Segera'
                                    ? BoxDecoration(
                                        color: const Color(0xFFF1F0F5),
                                        borderRadius: BorderRadius.circular(12),
                                      )
                                    : null,
                                child: Text(
                                  _trailing(item[0])!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kMutedMain,
                                  ),
                                ),
                              ),
                            const Icon(
                              Icons.chevron_right,
                              size: 22,
                              color: kMutedMain,
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
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo, required this.size});

  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        color: const Color(0xFFE8F1FB),
      ),
      child: ClipOval(
        child: photo != null
            ? AvatarImage(
                source: photo,
                fallback: const ResImage('demo_m1', fit: BoxFit.cover),
              )
            : const ResImage('demo_m1', fit: BoxFit.cover),
      ),
    );
  }
}

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender, required this.age});

  final String gender;
  final int age;

  @override
  Widget build(BuildContext context) {
    final bool male = gender != 'female';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: male ? const Color(0xFF4C8DF6) : const Color(0xFFFF6FA5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(male ? Icons.male : Icons.female, size: 14, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            '$age',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.asset,
    required this.title,
    required this.footer,
    this.coinIcon = false,
    this.onTap,
  });

  final String asset;
  final String title;
  final String footer;
  final bool coinIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 90,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ResImage(asset, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      if (coinIcon) ...<Widget>[
                        const ResImage('me_shortcut_coin', width: 18, height: 18),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        footer,
                        style: TextStyle(
                          fontSize: coinIcon ? 15 : 11.5,
                          fontWeight: FontWeight.w700,
                          color: coinIcon ? Colors.white : const Color(0xFFFFD27A),
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

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.asset, required this.label, this.onTap});

  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _col(),
    );
  }

  Widget _col() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ResImage(asset, width: 42, height: 42),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: kInkMain),
        ),
      ],
    );
  }
}
