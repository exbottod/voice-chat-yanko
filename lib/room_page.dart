import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_assets.dart';
import 'main.dart' show Room;
import 'native_bridge.dart';
import 'res_image.dart';
import 'room_menu_page.dart';
import 'room_settings_page.dart' show RoomSettingsPage, roomSeatRows, roomSeatCount;

const Color _ink = Color(0xFF1F1A3D);
const Color _pink = Color(0xFFFF4F8B);

/// Layar room suara: kursi mic, pengaturan room, bagikan, keluar/perkecil,
/// poin room (ranking user di room), dan daftar user online.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.room});

  final Room room;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  bool _micOn = false;
  bool _speakerOn = true;
  String _route = '';
  Uint8List? _bgBytes;
  bool _lockedRoom = false;
  bool _muteAll = false;
  int? _mySeat;
  Uint8List? _themeBytes;
  String _micMode = '11 Mics';
  String _announcement = 'Selamat datang semua! Mari ngobrol dan bersenang-senang.';
  String _title = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  bool _kickShown = false;
  final TextEditingController _chatCtl = TextEditingController();

  CollectionReference<Map<String, dynamic>>? get _chatRef {
    final String? id = widget.room.id;
    if (id == null) {
      return null;
    }
    return FirebaseFirestore.instance.collection('rooms').doc(id).collection('messages');
  }

  Future<void> _sendMessage(String text) async {
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    if (ref == null || text.trim().isEmpty) {
      return;
    }
    final String name = FirebaseAuth.instance.currentUser?.displayName ?? '';
    await ref.add(<String, dynamic>{
      'text': text.trim(),
      'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      'name': name.isEmpty ? 'Kamu' : name,
      'dj': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _chatCtl.clear();
  }

  void _takeSeat(int index) {
    setState(() {
      if (_mySeat == index) {
        _mySeat = null;
        _micOn = false;
        VoiceNative.setMicMuted(true);
        _toast('Kamu turun dari kursi $index');
      } else {
        _mySeat = index;
        _micOn = true;
        VoiceNative.setMicMuted(false);
        _toast('Kamu naik ke kursi $index, mic aktif');
      }
    });
  }

  Future<void> _toggleMic() async {
    if (_mySeat == null) {
      _toast('Naik ke kursi mic dulu untuk bicara');
      return;
    }
    setState(() => _micOn = !_micOn);
    await VoiceNative.setMicMuted(!_micOn);
    if (!mounted) {
      return;
    }
    _toast(_micOn ? 'Mic aktif, suaramu terdengar lagi' : 'Mic mati, suaramu tidak terdengar');
  }

  String get _myName {
    final User? u = FirebaseAuth.instance.currentUser;
    final String? n = u?.displayName;
    return (n == null || n.isEmpty) ? 'Kamu' : n;
  }

  @override
  void initState() {
    super.initState();
    VoiceNative.currentRoute().then((String route) {
      if (mounted) {
        setState(() => _route = route);
      }
    });
    VoiceNative.loadDrawable(AppAssets.roomBg1).then((Uint8List? bytes) {
      if (mounted && bytes != null) {
        setState(() => _bgBytes = bytes);
      }
    });
    final String? id = widget.room.id;
    if (id != null) {
      _roomSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(id)
          .snapshots()
          .listen(_onRoomDoc);
    }
  }

  void _onRoomDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted) {
      return;
    }
    final Map<String, dynamic> d = snap.data() ?? <String, dynamic>{};
    final String theme = (d['themeImage'] as String?) ?? '';
    final String ann = (d['announcement'] as String?) ?? '';
    final String title = (d['title'] as String?) ?? '';
    final String micMode = (d['micMode'] as String?) ?? '11 Mics';
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<dynamic> blacklist = (d['blacklist'] as List<dynamic>?) ?? <dynamic>[];
    final bool kicked = blacklist.any((dynamic e) =>
        (e is Map) && (e['uid'] as String?) == myUid);
    setState(() {
      _themeBytes = theme.isEmpty ? null : base64Decode(theme);
      _announcement = ann.isEmpty ? _announcement : ann;
      _title = title;
      _micMode = micMode;
      if (_mySeat != null && _mySeat! > roomSeatCount(micMode)) {
        _mySeat = null;
        _micOn = false;
      }
    });
    if (kicked && !_kickShown) {
      _kickShown = true;
      _showKickedDialog();
    }
  }

  void _showKickedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Anda telah dikeluarkan dari room!!',
            style: TextStyle(fontSize: 15.5, color: _ink)),
        content: const Text(
          'Pemilik room mengeluarkan kamu dari room ini.',
          style: TextStyle(fontSize: 13, color: Color(0xFF8E8AA8)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK', style: TextStyle(color: _pink)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatCtl.dispose();
    _roomSub?.cancel();
    super.dispose();
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

  void _sheet(String title, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E1EF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSettings() {
    final String? id = widget.room.id;
    if (id == null) {
      _toast('Room ini belum tersimpan di database');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RoomSettingsPage(roomId: id)),
    );
  }

  void _shareRoom() {
    final String link = 'https://login-9604e.web.app/room?name=${Uri.encodeComponent(widget.room.name)}';
    _sheet(
      'Bagikan room',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    link,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _ink),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: _ink),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (mounted) {
                      Navigator.of(context).pop();
                      _toast('Tautan room disalin');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (mounted) {
                  Navigator.of(context).pop();
                  _toast('Tautan disalin, tempel di chat mana pun');
                }
              },
              child: const Text('Salin tautan room', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _openOnlineUsers() {
    _sheet(
      'User online (${widget.room.listeners + 1})',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _userRow(widget.room.avatars.isEmpty ? 'Host' : 'Host room', true),
          _userRow(_myName, false),
          const SizedBox(height: 6),
          const Text(
            'User lain akan muncul di sini saat masuk room.',
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8AA8)),
          ),
        ],
      ),
    );
  }

  void _openRoomRanking() {
    _sheet(
      'Peringkat di room · 0K poin',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _rankRow(1, 'Host room', 0),
          _rankRow(2, _myName, 0),
          const SizedBox(height: 8),
          const Text(
            'Poin room bertambah dari gift yang dikirim di room ini.',
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8AA8)),
          ),
        ],
      ),
    );
  }

  void _openBoxTab() {
    final String? id = widget.room.id;
    if (id == null) {
      _toast('Room ini belum tersimpan di database');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomMenuPage(roomId: id, roomName: _title.isEmpty ? widget.room.name : _title),
      ),
    );
  }

  void _openEmoji() {
    _sheet(
      'Emot',
      SizedBox(
        height: 250,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: 10,
          itemBuilder: (BuildContext ctx, int i) {
            final String name = 'emotes_emote_${(i + 1).toString().padLeft(2, '0')}';
            return GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                _toast('Emot ${i + 1} terkirim');
              },
              child: ResImage(name, fit: BoxFit.contain),
            );
          },
        ),
      ),
    );
  }

  void _openGift() {
    _sheet(
      'Gift',
      const SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ResImage('room_gift_button', width: 72, height: 72),
              SizedBox(height: 10),
              Text(
                'Belum ada gift',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
              ),
              SizedBox(height: 4),
              Text(
                'Daftar gift dan harga akan muncul setelah diunggah dari panel developer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF8E8AA8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _powerPressed() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Keluar dari room?', style: TextStyle(fontSize: 16, color: _ink)),
          content: const Text(
            'Kamu bisa memperkecil room dan tetap mendengarkan, atau keluar sepenuhnya.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8AA8)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                _toast('Room diperkecil, audio tetap jalan');
              },
              child: const Text('Perkecil', style: TextStyle(color: _pink)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                _toast('Kamu keluar dari room');
              },
              child: const Text('Keluar', style: TextStyle(color: Color(0xFFE5484D))),
            ),
          ],
        );
      },
    );
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _userRow(String name, bool host) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE9FF),
        child: Icon(host ? Icons.star : Icons.person, color: _pink, size: 20),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14, color: _ink)),
      subtitle: Text(
        host ? 'Host' : 'Pendengar',
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E8AA8)),
      ),
    );
  }

  Widget _rankRow(int rank, String name, int points) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 26,
        child: Text(
          '$rank',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _pink),
        ),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14, color: _ink)),
      trailing: Text(
        '${points}K',
        style: const TextStyle(fontSize: 13, color: Color(0xFF8E8AA8)),
      ),
    );
  }

  Widget _menuRow(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _ink, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, color: _ink)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E8AA8))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8AA8)),
      onTap: () {
        Navigator.of(context).pop();
        if (title == 'Peringkat room') {
          _openRoomRanking();
        } else if (title == 'User online') {
          _openOnlineUsers();
        } else {
          _toast('$title segera hadir');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120E24),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_themeBytes != null)
            Image.memory(_themeBytes!, fit: BoxFit.cover)
          else if (_bgBytes != null)
            Image.memory(_bgBytes!, fit: BoxFit.cover)
          else
            const ResImage(AppAssets.roomBg1, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(
              children: <Widget>[
                _topBar(),
                const SizedBox(height: 6),
                Expanded(child: _seats()),
                _chatArea(),
                _notice(),
                const SizedBox(height: 8),
                _bottomBar(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: <Widget>[
                    const ClipOval(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: ResImage('demo_m1', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _title.isEmpty ? widget.room.name : _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'ID ${widget.room.listeners + 1}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _topIcon(
                icon: Icons.people_alt_outlined,
                color: const Color(0xFF9B7BFF),
                label: '${widget.room.listeners + 1}',
                onTap: _openOnlineUsers,
              ),
              _topIcon(
                icon: Icons.settings,
                color: const Color(0xFF3DD68C),
                onTap: _openSettings,
              ),
              _topIcon(
                icon: Icons.ios_share,
                color: const Color(0xFFE5484D),
                onTap: _shareRoom,
              ),
              _topIcon(
                icon: Icons.power_settings_new,
                color: const Color(0xFFFFC53D),
                onTap: _powerPressed,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _openRoomRanking,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.emoji_events, color: Color(0xFFFFC53D), size: 15),
                    SizedBox(width: 4),
                    Text(
                      '0K',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54, size: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.8), width: 1.4),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            if (label != null)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seats() {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          _hostSeat(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: <Widget>[
                for (final List<int> row in _seatRowsNumbered())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        for (final int n in row) _micSeat(n),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Welcome $_myName entered the room.',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _hostSeat() {
    return Column(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFFC53D), Color(0xFFFF4F8B)],
                ),
              ),
              child: const ClipOval(
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: ResImage('demo_m1', fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned(
              top: -14,
              child: const Icon(Icons.workspace_premium, color: Color(0xFFFFC53D), size: 22),
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DD68C),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'Lv.54',
                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.room.name,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  List<List<int>> _seatRowsNumbered() {
    final int total = int.tryParse(_micMode.split(' ').first) ?? 11;
    final List<int> rows = roomSeatRows(total);
    final List<List<int>> out = <List<int>>[];
    int n = 1;
    for (final int count in rows) {
      out.add(<int>[for (int i = 0; i < count; i++) n++]);
    }
    return out;
  }

  Widget _micSeat(int index) {
    final bool mine = _mySeat == index;
    final String asset = mine && !_micOn
        ? 'room_mic_seat_muted'
        : 'room_mic_seat_empty';
    return GestureDetector(
      onTap: () => _takeSeat(index),
      child: SizedBox(
        width: 58,
        child: Column(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: mine && _micOn
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF3DD68C).withValues(alpha: 0.7),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: ResImage(asset, width: 54, height: 54),
            ),
            const SizedBox(height: 3),
            Text(
              mine ? _myName : '$index',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mine ? const Color(0xFF3DD68C) : Colors.white54,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatArea() {
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    if (ref == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 86,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('createdAt', descending: true).limit(40).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (docs.isEmpty) {
            return const Center(
              child: Text('Belum ada chat. Mulai sapa room ini.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            );
          }
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: docs.length,
            itemBuilder: (BuildContext ctx, int i) {
              final Map<String, dynamic> m = docs[i].data();
              final bool dj = (m['dj'] as bool?) ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${(m['name'] as String?) ?? 'User'}: ',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: dj ? const Color(0xFFFFC53D) : const Color(0xFF9B7BFF),
                        ),
                      ),
                      TextSpan(
                        text: (m['text'] as String?) ?? '',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _notice() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Welcome! Mohon saling menghormati dan berkomunikasi dengan sopan. '
              'Perilaku kasar, iklan pihak ketiga, peniruan identitas, dan konten sensitif dilarang. '
              'Laporkan pelanggaran.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.35),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                const Text(
                  'Announcement: ',
                  style: TextStyle(color: Color(0xFFFFC53D), fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
                Expanded(
                  child: Text(
                    _announcement,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                  ),
                ),
                const Icon(Icons.edit, color: Colors.white54, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _chatCtl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sendMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Say something...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openEmoji,
                        child: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openGift,
                child: const ResImage('room_gift_button', width: 44, height: 44),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _barIcon(
                _micOn ? Icons.mic : Icons.mic_off,
                _micOn ? const Color(0xFF3DD68C) : Colors.white54,
                _toggleMic,
              ),
              _barIcon(
                _speakerOn ? Icons.volume_up : Icons.volume_off,
                _speakerOn ? Colors.white : const Color(0xFFE5484D),
                _toggleSpeaker,
              ),
              _barIcon(Icons.mail_outline, Colors.white, () => _toast('Belum ada pesan baru'), dot: true),
              _barIcon(Icons.grid_view, const Color(0xFF5AA9F5), _openBoxTab),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barIcon(IconData icon, Color color, VoidCallback onTap, {bool dot = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          if (dot)
            Positioned(
              right: -2,
              top: -1,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
