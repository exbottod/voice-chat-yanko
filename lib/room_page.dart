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
import 'profile_store.dart';
import 'avatar_image.dart';
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
  String _ownerId = '';
  List<int> _lockedSeats = <int>[];
  List<int> _mutedSeats = <int>[];

  bool get _isOwner {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return uid.isNotEmpty && uid == _ownerId;
  }
  String _announcement = 'Selamat datang semua! Mari ngobrol dan bersenang-senang.';
  String _title = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  bool _kickShown = false;
  final TextEditingController _chatCtl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _typing = false;
  String? _myPhoto;

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
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'name': name.isEmpty ? 'Kamu' : name,
      'dj': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _chatCtl.clear();
  }

  void _takeSeat(int index) {
    if (index == 0 && !_isOwner) {
      _toast('Kursi host hanya untuk owner');
      return;
    }
    final bool locked = _lockedSeats.contains(index);
    if (_isOwner) {
      _seatActions(index, locked);
      return;
    }
    if (locked && _mySeat != index) {
      _toast('Kursi $index dikunci owner');
      return;
    }
    _toggleSeat(index);
  }

  void _toggleSeat(int index) {
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

  Future<void> _setSeatLock(int index, bool lock) async {
    final String? id = widget.room.id;
    if (id == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('rooms').doc(id).set(
      <String, dynamic>{
        'lockedSeats': lock
            ? FieldValue.arrayUnion(<int>[index])
            : FieldValue.arrayRemove(<int>[index]),
      },
      SetOptions(merge: true),
    );
    if (mounted) {
      _toast(lock ? 'Kursi $index dikunci' : 'Kursi $index dibuka');
    }
  }

  Future<void> _roomSet(Map<String, dynamic> data) async {
    final String? id = widget.room.id;
    if (id == null) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _lockAll(bool lock) async {
    final int total = roomSeatCount(_micMode);
    await _roomSet(<String, dynamic>{
      'lockedSeats': lock ? <int>[for (int i = 1; i <= total; i++) i] : <int>[],
    });
    if (mounted) {
      _toast(lock ? 'Semua kursi dikunci' : 'Semua kursi dibuka');
    }
  }

  Future<void> _muteSeat(int index, bool mute) async {
    await _roomSet(<String, dynamic>{
      'mutedSeats': mute
          ? FieldValue.arrayUnion(<int>[index])
          : FieldValue.arrayRemove(<int>[index]),
    });
    if (mounted) {
      _toast(mute ? 'Kursi $index dibisukan' : 'Kursi $index tidak dibisukan');
    }
  }

  Future<void> _inviteToSeat(int index) async {
    await _sendMessage('mengundang semua orang naik ke kursi $index');
    if (mounted) {
      _toast('Undangan kursi $index dikirim ke chat');
    }
  }

  /// Aksi khusus owner saat mengetuk kursi mic (gaya Yanko).
  void _seatActions(int index, bool locked) {
    final bool onSeat = _mySeat == index;
    final bool muted = _mutedSeats.contains(index);
    final bool allLocked = _lockedSeats.length >= roomSeatCount(_micMode);

    Widget row(String label, VoidCallback onTap, {Color? color}) {
      return InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0EEF6))),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: color ?? const Color(0xFF111111),
            ),
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            row(onSeat ? 'Off Mic' : 'On Mic', () => _toggleSeat(index)),
            row('Invite', () => _inviteToSeat(index)),
            row(muted ? 'Unmute' : 'Mute', () => _muteSeat(index, !muted)),
            row(locked ? 'Unlock' : 'Lock', () => _setSeatLock(index, !locked)),
            row(allLocked ? 'Unlock All' : 'Lock All', () => _lockAll(!allLocked)),
            InkWell(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, color: Color(0xFF9A9AA3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMic() async {
    if (_mySeat != null && _mutedSeats.contains(_mySeat) && !_isOwner && !_micOn) {
      _toast('Kursimu dibisukan owner');
      return;
    }
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
    _chatCtl.addListener(_onTypingChanged);
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      ProfileStore.load(myUid).then((Map<String, dynamic>? p) {
        final String? url = p?['photoUrl'] as String?;
        if (mounted && url != null && url.isNotEmpty) {
          setState(() => _myPhoto = url);
        }
      });
    }
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
    final String ownerId = (d['ownerId'] as String?) ?? '';
    final List<int> locked = ((d['lockedSeats'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic e) => (e as num).toInt())
        .toList();
    final List<int> muted = ((d['mutedSeats'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic e) => (e as num).toInt())
        .toList();
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<dynamic> blacklist = (d['blacklist'] as List<dynamic>?) ?? <dynamic>[];
    final bool kicked = blacklist.any((dynamic e) =>
        (e is Map) && (e['uid'] as String?) == myUid);
    setState(() {
      _themeBytes = theme.isEmpty ? null : base64Decode(theme);
      _announcement = ann.isEmpty ? _announcement : ann;
      _title = title;
      _micMode = micMode;
      _ownerId = ownerId;
      _lockedSeats = locked;
      _mutedSeats = muted;
      if (_mySeat != null && muted.contains(_mySeat) && ownerId != myUid && _micOn) {
        _micOn = false;
        VoiceNative.setMicMuted(true);
      }
      if (_mySeat != null && locked.contains(_mySeat) && ownerId != myUid) {
        _mySeat = null;
        _micOn = false;
        VoiceNative.setMicMuted(true);
      }
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
  void _onTypingChanged() {
    final bool now = _chatCtl.text.trim().isNotEmpty;
    if (now != _typing && mounted) {
      setState(() => _typing = now);
    }
  }

  void dispose() {
    _chatCtl.removeListener(_onTypingChanged);
    _chatScroll.dispose();
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
    final double kb = MediaQuery.viewInsetsOf(context).bottom;
    // Saat mengetik: panggung mic tetap di tempat, chat yang bergulir.
    final bool compact = kb > 0;
    return Scaffold(
      backgroundColor: const Color(0xFF120E24),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_themeBytes != null)
            Image.memory(_themeBytes!, fit: BoxFit.cover)
          else if (_bgBytes != null)
            Image.memory(_bgBytes!, fit: BoxFit.cover)
          else
            const ResImage(AppAssets.roomBg1, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: kb),
              child: LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints c) {
                  final double stageH =
                      (c.maxHeight - (compact ? 158 : 250)).clamp(110.0, 262.0);
                  return Column(
                    children: <Widget>[
                      _topBar(),
                      _stage(stageH),
                      if (!compact) _noticeBox(),
                      if (!compact) _levelBadge(),
                      Expanded(child: _chatList()),
                      _typingBar(),
                      _bottomBar(),
                      const SizedBox(height: 4),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- top bar

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 4),
              const ClipOval(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: ResImage('demo_m1', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      (_title.isEmpty ? widget.room.name : _title).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.person, color: Colors.white54, size: 11),
                        const SizedBox(width: 2),
                        Text(
                          '${21593367 + widget.room.listeners}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _viewerChip(),
              const SizedBox(width: 4),
              _roundTop(Icons.hexagon_outlined, const Color(0xFFB07CFF),
                  _openRoomRanking),
              _roundTop(Icons.north_east, const Color(0xFF7FD7FF), _shareRoom),
              _roundTop(Icons.power_settings_new, const Color(0xFFFF6B6B),
                  _powerPressed),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              InkWell(
                onTap: _openRoomRanking,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.emoji_events,
                          color: Color(0xFFFFC53D), size: 15),
                      SizedBox(width: 3),
                      Text('0K',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                      Icon(Icons.chevron_right, color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openBoxTab,
                child: const ResImage('tasks_reward_chest',
                    width: 42, height: 42),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewerChip() {
    return GestureDetector(
      onTap: _openOnlineUsers,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.person_outline, color: Colors.white, size: 13),
            const SizedBox(width: 3),
            Text(
              '${widget.room.listeners + 1}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundTop(IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.85), width: 1.2),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ panggung mic

  Widget _stage(double tinggi) {
    return SizedBox(
      height: tinggi,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          height: 262,
          child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 6),
                _hostSeat(),
                const SizedBox(height: 10),
                for (final List<int> row in _seatRowsFixed())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (final int n in row)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            child: _micSeat(n),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 96,
            child: Column(
              children: <Widget>[
                _agencyBadge(),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openGift,
                  child: const ResImage('roomtools_rocket',
                      width: 46, height: 46),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 4,
            child: _rechargeCard(),
          ),
        ],
          ),
        ),
      ),
    );
  }

  /// Kursi tamu selalu 2 baris x 4, supaya tampilan tidak bergeser.
  List<List<int>> _seatRowsFixed() {
    return <List<int>>[
      <int>[1, 2, 3, 4],
      <int>[5, 6, 7, 8],
    ];
  }

  Widget _hostSeat() {
    final bool ownerHere = _isOwner && _mySeat == 0;
    return GestureDetector(
      onTap: () => _takeSeat(0),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              const Positioned(
                top: -14,
                child: ResImage(AppAssets.roomTopCrown, width: 34, height: 24),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: ownerHere && _micOn
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF3DD68C)
                                .withValues(alpha: 0.75),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : null,
                child: _seatFace(ownerHere, 78),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            ownerHere ? _myName : 'Owner',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatFace(bool occupied, double size) {
    if (occupied) {
      final String? photo =
          _myPhoto ?? FirebaseAuth.instance.currentUser?.photoURL;
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _micOn ? const Color(0xFF3DD68C) : Colors.white24,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: photo != null && photo.isNotEmpty
              ? AvatarImage(
                  source: photo,
                  width: size,
                  height: size,
                  fallback: ResImage('room_mic_seat_empty',
                      width: size, height: size),
                )
              : ResImage('room_mic_seat_empty', width: size, height: size),
        ),
      );
    }
    return ResImage('room_mic_seat_empty', width: size, height: size);
  }

  Widget _micSeat(int index) {
    final bool mine = _mySeat == index;
    final bool locked = _lockedSeats.contains(index);
    final bool muted = _mutedSeats.contains(index);
    return GestureDetector(
      onTap: () => _takeSeat(index),
      child: SizedBox(
        width: 54,
        child: Column(
          children: <Widget>[
            SizedBox(
              width: 52,
              height: 52,
              child: locked && !mine
                  ? const ResImage('room_mic_seat_locked',
                      width: 52, height: 52)
                  : mine
                      ? Container(
                          decoration: _micOn
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(0xFF3DD68C)
                                          .withValues(alpha: 0.75),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                )
                              : null,
                          child: _seatFace(true, 52),
                        )
                      : muted
                          ? const ResImage('room_mic_seat_muted',
                              width: 52, height: 52)
                          : _seatFace(false, 52),
            ),
            const SizedBox(height: 2),
            Text(
              mine ? _myName : '$index',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mine
                    ? const Color(0xFF3DD68C)
                    : (muted ? Colors.white38 : Colors.white60),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agencyBadge() {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFFFF8A2B),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'A',
        style: TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _rechargeCard() {
    return GestureDetector(
      onTap: _openBoxTab,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x66FFC53D), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ResImage(AppAssets.roomEventPanel, width: 62, height: 40),
            const SizedBox(height: 3),
            const Text(
              'Recharge Event',
              style: TextStyle(
                  color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.35,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC53D),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- peringatan

  Widget _noticeBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Perilaku kasar, iklan pihak ketiga, peniruan identitas, dan konten '
          'sensitif dilarang keras. Laporkan setiap pelanggaran!',
          textAlign: TextAlign.center,
          maxLines: 3,
          style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.3),
        ),
      ),
    );
  }

  Widget _levelBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.auto_awesome, color: Color(0xFFFFC53D), size: 16),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFD65C), Color(0xFFE79A19)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFFC53D).withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Text(
              'Lv.54',
              style: TextStyle(
                  color: Color(0xFF3A2400),
                  fontSize: 12,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.auto_awesome, color: Color(0xFFFFC53D), size: 16),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- chat

  Widget _chatList() {
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    if (ref == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(60).snapshots(),
      builder: (BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return ListView.builder(
          controller: _chatScroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
          itemCount: docs.length + 2,
          itemBuilder: (BuildContext ctx, int i) {
            if (i >= docs.length) {
              final int k = i - docs.length;
              if (k == 0) {
                return _systemLine('Welcome $_myName entered the room.',
                    const Color(0xFF9B7BFF));
              }
              return _announcementLine();
            }
            final Map<String, dynamic> m = docs[i].data();
            final bool dj = (m['dj'] as bool?) ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '${(m['name'] as String?) ?? 'User'}: ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: dj
                            ? const Color(0xFFFFC53D)
                            : const Color(0xFF9B7BFF),
                      ),
                    ),
                    TextSpan(
                      text: (m['text'] as String?) ?? '',
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _systemLine(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 10.5),
        ),
      ),
    );
  }

  Widget _announcementLine() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            const Text(
              'Announcement: ',
              style: TextStyle(
                  color: Color(0xFFFFC53D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700),
            ),
            const Icon(Icons.campaign, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _announcement,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ),
            if (_isOwner)
              GestureDetector(
                onTap: _openSettings,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.edit, color: Colors.white54, size: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typingBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: _typing
          ? Container(
              key: const ValueKey<String>('typing'),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'sedang mengetik',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                  const SizedBox(width: 5),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.3, end: 1),
                    duration: const Duration(milliseconds: 700),
                    builder: (BuildContext c, double v, Widget? _) => Opacity(
                      opacity: v,
                      child: const Text(
                        '•••',
                        style: TextStyle(
                            color: Color(0xFF9B7BFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('kosong')),
    );
  }

  // ------------------------------------------------------------ bottom bar

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _chatCtl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Say s...',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 12.5),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openEmoji,
                    child: const Icon(Icons.emoji_emotions,
                        color: Colors.white, size: 21),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
          _roundBtn(
            _speakerOn ? Icons.volume_up : Icons.volume_off,
            Colors.white,
            _toggleSpeaker,
          ),
          const SizedBox(width: 6),
          _roundBtn(Icons.mail, Colors.white, () => _toast('Belum ada pesan baru'),
              dot: true),
          const SizedBox(width: 6),
          _roundBtn(Icons.grid_view_rounded, Colors.white, _openBoxTab),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _openGift,
            child: const ResImage(AppAssets.roomGiftButton, width: 40, height: 40),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, Color color, VoidCallback onTap,
      {bool dot = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          if (dot)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5484D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
