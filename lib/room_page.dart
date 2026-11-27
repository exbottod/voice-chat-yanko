import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_assets.dart';
import 'main.dart' show Room;
import 'native_bridge.dart';
import 'kursi_tertunda.dart';
import 'net_status.dart';
import 'aset_media.dart';
import 'kursi_live.dart';
import 'rtc_voice.dart';
import 'yanko_notice.dart';
import 'profile_screen.dart';
import 'profile_store.dart';
import 'avatar_image.dart';
import 'frame_active.dart';
import 'feature_pages.dart' show WalletPage;
import 'res_image.dart';
import 'room_menu_page.dart';
import 'room_ranking_page.dart';
import 'room_session.dart';
import 'lucky_bag.dart';

import 'countries.dart';
import 'room_settings_page.dart' show RoomSettingsPage, roomSeatRows, roomSeatCount;

const Color _ink = Color(0xFF1F1A3D);
const Color _pink = Color(0xFFF59E0B);

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
  bool _lockedRoom = false;
  bool _muteAll = false;
  int? _mySeat;
  Uint8List? _themeBytes;
  // Simpan hasil decode per room: masuk ulang tidak mengulang base64Decode.
  static final Map<String, Uint8List> _themeCache = <String, Uint8List>{};

  /// Lebar piksel untuk decode gambar latar: cukup seukuran layar.
  int get _latarW {
    final double w =
        MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
    return w.clamp(360, 1080).round();
  }

  static final Map<String, Uint8List> _coverCache = <String, Uint8List>{};
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
  String? _myPhoto;
  int _myLevel = 1;
  String _myCountry = '';
  String _ownerPublicId = '';
  Uint8List? _coverBytes;
  int _onlineCount = 1;
  Timer? _beat;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  // Penghuni kursi disimpan di notifier sendiri supaya perubahan kursi hanya
  // membangun ulang panggung mic, bukan seluruh halaman room (chat, efek,
  // hadiah). Ini yang membuat nama di kursi baru muncul tanpa tersendat.
  final ValueNotifier<Map<int, Map<String, dynamic>>> _seatsNotifier =
      ValueNotifier<Map<int, Map<String, dynamic>>>(
          <int, Map<String, dynamic>>{});
  Map<int, Map<String, dynamic>> get _seatUsers => _seatsNotifier.value;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _seatsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _inviteSub;

  CollectionReference<Map<String, dynamic>>? get _chatRef {
    final String? id = widget.room.id;
    if (id == null) {
      return null;
    }
    return FirebaseFirestore.instance.collection('rooms').doc(id).collection('messages');
  }

  /// Pesan sistem "X entered the room" disimpan agar terlihat semua user.
  Future<void> _announceJoin() async {
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    final User? u = FirebaseAuth.instance.currentUser;
    if (ref == null || u == null) {
      return;
    }
    try {
      await ref.add(<String, dynamic>{
        'system': true,
        'text': 'Welcome $_myName entered the room.',
        'uid': u.uid,
        'senderId': u.uid,
        'name': _myName,
        'photoUrl': _myPhoto ?? u.photoURL ?? '',
        'countryCode': _myCountry,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Offline atau ditolak aturan: pesan masuk dilewati.
    }
  }

  Future<void> _sendMessage(String text) async {
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    if (ref == null || text.trim().isEmpty) {
      return;
    }
    final String name = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final String isi = text.trim();
    // Kolom ketik langsung kosong setelah Enter, tidak menunggu jaringan.
    _chatCtl.clear();
    FocusScope.of(context).unfocus();
    try {
      await ref.add(<String, dynamic>{
      'text': isi,
      'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'name': name.isEmpty ? 'Kamu' : name,
      'photoUrl': _myPhoto ?? FirebaseAuth.instance.currentUser?.photoURL ?? '',
      'level': _myLevel,
      'countryCode': _myCountry,
      'dj': false,
      'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Gagal kirim: kembalikan teks supaya tidak hilang.
      if (mounted) {
        _chatCtl.text = isi;
        _toast('Pesan gagal dikirim');
      }
    }
  }

  void _takeSeat(int index) {
    if (!NetStatus.instance.online.value) {
      _toast('Tidak ada koneksi internet');
      return;
    }
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

  /// Suara WebRTC mengikuti kursi mic: naik kursi mulai bersuara, turun
  /// kursi berhenti. Minimize tidak menghentikan suara.
  void _syncRtc() {
    final String? rid = widget.room.id;
    final int? seat = _mySeat;
    if (rid == null || seat == null) {
      unawaited(RtcVoice.instance.stop());
      return;
    }
    unawaited(RtcVoice.instance
        .start(roomId: rid, seat: seat, micOn: _micOn)
        .then((_) => _sebarKursi()));
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
    _sebarKursi();
    _syncSeat();
    _syncRtc();
  }

  /// Kirim posisi kursi ke HP lain lewat kanal data WebRTC. Ini jalur cepat
  /// (di bawah 100 ms); Firestore tetap mencatatnya sebagai data resmi.
  void _sebarKursi() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final String foto =
        _myPhoto ?? FirebaseAuth.instance.currentUser?.photoURL ?? '';
    // Dua jalur: WebSocket (Realtime Database) untuk semua orang di room, dan
    // kanal data WebRTC untuk yang sudah tersambung suara. Keduanya JSON kecil.
    unawaited(KursiLive.instance.sebar(
      seat: _mySeat,
      micOn: _micOn,
      name: _myName,
      photoUrl: foto,
    ));
    RtcVoice.instance.sebarKursi(
      seat: _mySeat,
      micOn: _micOn,
      name: _myName,
      photoUrl: foto,
    );
  }

  /// Terapkan perubahan kursi dari HP lain seketika, tanpa menunggu Firestore.
  void _kursiCepat(Map<String, dynamic> m) {
    if (!mounted) {
      return;
    }
    final String uid = (m['uid'] as String?) ?? '';
    if (uid.isEmpty) {
      return;
    }
    final int? seat = (m['seat'] as num?)?.toInt();
    final Map<int, Map<String, dynamic>> baru =
        Map<int, Map<String, dynamic>>.from(_seatUsers);
    // Satu akun hanya di satu kursi.
    for (final int k in baru.keys.toList()) {
      if ((baru[k]?['uid'] as String?) == uid) {
        baru.remove(k);
      }
    }
    if (seat != null) {
      baru[seat] = <String, dynamic>{
        ...?baru[seat],
        'uid': uid,
        'seat': seat,
        'name': ((m['name'] as String?)?.isNotEmpty ?? false)
            ? m['name'] as String
            : (baru[seat]?['name'] ?? ''),
        'photoUrl': ((m['photo'] as String?)?.isNotEmpty ?? false)
            ? m['photo'] as String
            : ((m['photoUrl'] as String?) ?? ''),
        'micOn': m['micOn'] == true,
      };
    }
    _seatsNotifier.value = baru;
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

  /// Aksi khusus owner saat mengetuk kursi mic (gaya AuraVox).
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
    _sebarKursi();
    await VoiceNative.setMicMuted(!_micOn);
    unawaited(RtcVoice.instance.setMic(_micOn));
    final String? rid = widget.room.id;
    final int? seatNow = _mySeat;
    if (rid != null && seatNow != null) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(rid)
          .collection('seats')
          .doc('$seatNow')
          .set(<String, dynamic>{'micOn': _micOn}, SetOptions(merge: true))
          .catchError((Object _) {});
    }
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
    // Bila dibuka lagi lewat bulatan, duduk kembali di kursi yang sama.
    final bool resumed = RoomSession.minimized.value != null &&
        RoomSession.minimized.value!.id == widget.room.id;
    final int? resumeSeat = RoomSession.takeSeat(widget.room.id);
    if (resumeSeat == null) {
      // Masuk room baru: mulai sebagai pendengar di bawah, bukan di kursi.
      _mySeat = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_hapusKursiSaya());
        }
      });
    }
    if (resumeSeat != null) {
      _mySeat = resumeSeat;
      _micOn = true;
      VoiceNative.setMicMuted(false);
    }
    RoomSession.beginOrResume();
    NetStatus.instance.online.addListener(_onNetChange);
    _subKursiCepat = RtcVoice.instance.kursiMasuk.listen(_kursiCepat);
    final String? ridRoom = widget.room.id;
    if (ridRoom != null) {
      unawaited(KursiLive.instance.mulai(ridRoom));
      _subKursiWs = KursiLive.instance.masuk.listen(_kursiCepat);
    }
    // Semua pekerjaan berat ditunda sampai layar room benar-benar tampil,
    // jadi masuk room terasa seketika.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startPresence();
      // Sisa koin lucky bag yang tidak terambil cair ke pemilik saat room dibuka.
      final String? rid = widget.room.id;
      if (rid != null) {
        unawaited(LuckyBagService.cairkanRefund(rid));
      }
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _syncRtc();
        }
      });
    });
    if (!resumed) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _announceJoin();
        }
      });
    }
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || myUid == null) {
        return;
      }
      ProfileStore.load(myUid).then((Map<String, dynamic>? p) {
        final String? url = p?['photoUrl'] as String?;
        final int coins = (p?['coins'] as num?)?.toInt() ?? 0;
        final int lv = (p?['level'] as num?)?.toInt() ?? (1 + coins ~/ 50).clamp(1, 99);
        final String cc = (p?['countryCode'] as String?) ?? '';
        if (mounted) {
          setState(() {
            if (url != null && url.isNotEmpty) {
              _myPhoto = url;
            }
            _myLevel = lv;
            _myCountry = cc;
          });
        }
      });
      // Latar memakai ResImage yang sudah ber-cache; memuat ulang drawable
      // ke bytes hanya membuang waktu saat masuk room.
      VoiceNative.currentRoute().then((String route) {
        _route = route;
      });
    });
    final String? id = widget.room.id;
    if (id != null && myUid != null) {
      _inviteSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(id)
          .collection('invites')
          .doc(myUid)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || !mounted) {
          return;
        }
        final int? seat = (snap.data()?['seat'] as num?)?.toInt();
        _toast(seat == null
            ? 'Owner mengundangmu naik ke mic'
            : 'Owner mengundangmu ke kursi $seat');
        unawaited(snap.reference.delete().catchError((Object _) {}));
      });
    }
    if (id != null) {
      _seatsSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(id)
          .collection('seats')
          .snapshots()
          .listen(_onSeats);
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
    final String cacheKey = widget.room.id ?? '';
    setState(() {
      if (theme.isEmpty) {
        _themeBytes = null;
      } else {
        _themeBytes = _themeCache[cacheKey] ??= base64Decode(theme);
      }
      _announcement = ann.isEmpty ? _announcement : ann;
      _title = title;
      _micMode = micMode;
      _ownerId = ownerId;
      final String cover = (d['coverImage'] as String?) ?? '';
      if (cover.isEmpty) {
        _coverBytes = null;
      } else {
        final Uint8List? sudah = _coverCache[cacheKey];
        if (sudah != null) {
          _coverBytes = sudah;
        } else {
          try {
            _coverBytes = _coverCache[cacheKey] = base64Decode(cover);
          } catch (_) {
            _coverBytes = null;
          }
        }
      }
      if (ownerId.isNotEmpty && _ownerPublicId.isEmpty) {
        _ownerPublicId = ProfileStore.publicId(ownerId);
        _loadOwnerPublicId(ownerId);
      }
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
  /// Koneksi putus atau kembali: beri tahu lewat notif mengambang.
  void _onNetChange() {
    if (!mounted) {
      return;
    }
    if (NetStatus.instance.online.value) {
      _toast('Koneksi internet kembali');
      unawaited(KursiTertunda.bersihkan());
      return;
    }
    final int? seat = _mySeat;
    if (seat != null) {
      setState(() {
        _mySeat = null;
        _micOn = false;
      });
      VoiceNative.setMicMuted(true);
      unawaited(RtcVoice.instance.stop());
      unawaited(KursiTertunda.tambah(widget.room.id, seat));
    }
    _toast('Koneksi internet terputus, kamu turun dari mic');
  }

  void dispose() {
    _hadiahEntry?.remove();
    _subKursiCepat?.cancel();
    _subKursiWs?.cancel();
    _seatsNotifier.dispose();
    NetStatus.instance.online.removeListener(_onNetChange);
    if (RoomSession.minimized.value == null) {
      unawaited(RtcVoice.instance.stop());
    }
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;
    _chatScroll.dispose();
    _chatCtl.dispose();
    _roomSub?.cancel();
    _seatsSub?.cancel();
    _inviteSub?.cancel();
    _membersSub?.cancel();
    _beat?.cancel();
    final String? roomId = widget.room.id;
    final int? seat = _mySeat;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    // Saat room hanya diperkecil, kehadiran dan kursi mic jangan dihapus.
    if (RoomSession.keepAlive) {
      super.dispose();
      return;
    }
    _myMemberRef?.delete().catchError((Object _) {});
    unawaited(KursiTertunda.tambah(roomId, seat));
    unawaited(_hapusKursiSaya());
    super.dispose();
  }

  Future<void> _toggleSpeaker() async {
    final bool next = !_speakerOn;
    setState(() => _speakerOn = next);
    await VoiceNative.setSpeakerphone(next);
    final String route = await VoiceNative.currentRoute();
    if (mounted) {
      _route = route;
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

  Future<void> _openSettings() async {
    final String? id = widget.room.id;
    if (id == null) {
      _toast('Room ini belum tersimpan di database');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RoomSettingsPage(roomId: id)),
    );
    if (!mounted) {
      return;
    }
    // Ambil ulang data room dari server supaya mode mic dan pengaturan lain
    // langsung terpakai di halaman room setelah pengaturan ditutup.
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(id)
              .get(const GetOptions(source: Source.server));
      if (!mounted) {
        return;
      }
      final String before = _micMode;
      _onRoomDoc(snap);
      final String after = (snap.data()?['micMode'] as String?) ?? before;
      if (after != before) {
        _toast('Mic mode: $after');
      }
    } catch (_) {
      // Offline: pakai data yang sudah ada.
    }
  }

  void _shareRoom() {
    final String link = 'https://voiceyanko.web.app/room?name=${Uri.encodeComponent(widget.room.name)}';
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
      'User online ($_onlineCount)',
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
    RoomRankingPage.open(context, widget.room.id);
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

  /// Pilihan jumlah gift (1, 6, 10, 30, 66, 100, 166, 666).
  void _qtySheet(int current, void Function(int) onPick) {
    const List<int> opsi = <int>[1, 6, 10, 30, 66, 100, 166, 666];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(60, 0, 60, 20),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF221A3C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66FFC53D)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final int n in opsi)
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onPick(n);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: n == current
                              ? const Color(0xFFFFC53D)
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: n == current
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGift({String? preselectUid}) {
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Penerima: semua yang sedang duduk di kursi mic (termasuk diri sendiri).
    final List<Map<String, dynamic>> people = <Map<String, dynamic>>[];
    final Set<String> seen = <String>{};
    final List<int> keys = _seatUsers.keys.toList()..sort();
    for (final int k in keys) {
      final Map<String, dynamic>? o = _occupant(k);
      final String uid = (o?['uid'] as String?) ?? '';
      if (o != null && uid.isNotEmpty && seen.add(uid)) {
        people.add(<String, dynamic>{
          'uid': uid,
          'name': (o['name'] as String?) ?? 'User',
          'photoUrl': (o['photoUrl'] as String?) ?? '',
          'owner': uid == _ownerId,
        });
      }
    }
    final Set<String> selected = <String>{
      if (preselectUid != null && seen.contains(preselectUid)) preselectUid,
    };
    bool all = selected.isEmpty && people.isNotEmpty;
    int tab = 1;
    int qty = 1;
    String hadiahDipilih = '';
    int coins = 0;
    bool coinsLoaded = false;
    const List<String> tabs = <String>[
      'Hadiah', 'Cashback', 'CP', 'Game', 'Newbie',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter set) {
            if (!coinsLoaded) {
              coinsLoaded = true;
              ProfileStore.load(myUid).then((Map<String, dynamic>? p) {
                if (ctx.mounted) {
                  set(() => coins = (p?['coins'] as num?)?.toInt() ?? 0);
                }
              });
            }
            Widget avatar(Map<String, dynamic> p) {
              final String uid = p['uid'] as String;
              final bool on = !all && selected.contains(uid);
              final String photo = (p['photoUrl'] as String?) ?? '';
              return GestureDetector(
                onTap: () => set(() {
                  all = false;
                  if (!selected.add(uid)) {
                    selected.remove(uid);
                  }
                  if (selected.isEmpty) {
                    all = true;
                  }
                }),
                child: Container(
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: on ? const Color(0xFFB07CFF) : Colors.white24,
                      width: on ? 2.2 : 1.2,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: ClipOval(
                          child: photo.isEmpty
                              ? Container(
                                  color: const Color(0xFF5B2FA8),
                                  alignment: Alignment.center,
                                  child: Text(
                                    ((p['name'] as String?) ?? 'U')
                                        .characters
                                        .first
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : AvatarImage(
                                  source: photo,
                                  fallback: const ResImage('room_mic_seat_empty'),
                                ),
                        ),
                      ),
                      if (p['owner'] == true)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB07CFF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: const Icon(Icons.home,
                                size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                height: 330 + MediaQuery.viewPaddingOf(ctx).bottom * 0,
                decoration: const BoxDecoration(
                  color: Color(0xFF16121C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  children: <Widget>[
                    // penerima
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: people.isEmpty
                                  ? const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Belum ada user di mic',
                                        style: TextStyle(
                                            color: Colors.white38, fontSize: 12),
                                      ),
                                    )
                                  : ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: <Widget>[
                                        for (final Map<String, dynamic> p
                                            in people)
                                          avatar(p),
                                      ],
                                    ),
                            ),
                          ),
                          GestureDetector(
                            onTap: people.isEmpty
                                ? null
                                : () => set(() {
                                      all = !all;
                                      if (all) {
                                        selected.clear();
                                      }
                                    }),
                            child: Container(
                              width: 44,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: all
                                          ? const Color(0xFF7A4DE0)
                                          : Colors.transparent,
                                      border: Border.all(
                                          color: const Color(0xFF7A4DE0),
                                          width: 1.5),
                                    ),
                                    child: all
                                        ? const Icon(Icons.check,
                                            size: 15, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('All',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: Colors.white10),
                    // kategori
                    SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        children: <Widget>[
                          Container(
                            width: 46,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.access_time,
                                size: 17, color: Colors.white54),
                          ),
                          for (int i = 0; i < tabs.length; i++)
                            GestureDetector(
                              onTap: () => set(() => tab = i + 1),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: tab == i + 1
                                      ? const Color(0xFF7A4DE0)
                                      : Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  tabs[i],
                                  style: TextStyle(
                                    color: tab == i + 1
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // grid hadiah dari panel developer (SVGA, MP4, GIF, WEBP,
                    // PNG, JPG). Ketuk untuk memilih, lalu tekan Berikan.
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _daftarHadiah(),
                        builder: (
                          BuildContext c,
                          AsyncSnapshot<List<Map<String, dynamic>>> snap,
                        ) {
                          final List<Map<String, dynamic>> isi =
                              snap.data ?? const <Map<String, dynamic>>[];
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          if (isi.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const ResImage('room_gift_button',
                                      width: 44, height: 44),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Belum ada hadiah',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Akan muncul setelah diunggah dari panel developer',
                                    style: TextStyle(
                                        color: Colors.white30, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: isi.length,
                            itemBuilder: (BuildContext c, int i) {
                              final Map<String, dynamic> g = isi[i];
                              final bool pilih =
                                  (g['id'] as String?) == hadiahDipilih;
                              return GestureDetector(
                                onTap: () => set(() => hadiahDipilih =
                                    (g['id'] as String?) ?? ''),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: pilih
                                          ? const Color(0xFFB07CFF)
                                          : Colors.transparent,
                                      width: 1.6,
                                    ),
                                  ),
                                  child: Column(
                                    children: <Widget>[
                                      Expanded(
                                        child: AsetMedia.dari(
                                          g,
                                          fallback: const ResImage(
                                              'room_gift_button',
                                              width: 34,
                                              height: 34),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ((g['name'] ?? g['nama'] ?? 'Hadiah')
                                            as String),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          const Icon(Icons.star,
                                              size: 9,
                                              color: Color(0xFFFFD65C)),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${(g['coins'] ?? g['price'] ?? g['harga'] ?? 0) as num}',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // bar bawah
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 12, 12),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Color(0xFFFFD65C),
                                  Color(0xFFE79A19),
                                ],
                              ),
                            ),
                            child: const Icon(Icons.star,
                                size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$coins',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => WalletPage(coins: coins),
                                ),
                              );
                            },
                            child: const Text(
                              'Topup >',
                              style: TextStyle(
                                color: Color(0xFFFFC53D),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                  color: const Color(0xFF7A4DE0), width: 1.4),
                            ),
                            child: Row(
                              children: <Widget>[
                                GestureDetector(
                                  onTap: () => _qtySheet(qty, (int v) {
                                    set(() => qty = v);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: Text(
                                      '$qty \u25B4',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 92,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(19),
                                    ),
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (hadiahDipilih.isEmpty) {
                                        _toast('Pilih hadiah dulu');
                                        return;
                                      }
                                      final List<String> ke = all
                                          ? <String>[
                                              for (final Map<String, dynamic> p
                                                  in people)
                                                (p['uid'] as String?) ?? '',
                                            ]
                                          : selected.toList();
                                      Navigator.of(ctx).pop();
                                      unawaited(_kirimHadiah(
                                          hadiahDipilih, ke, qty));
                                    },
                                    child: const Text(
                                      'Berikan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
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
              ),
            );
          },
        );
      },
    );
  }

  /// Daftar hadiah dari panel developer. Semua format didukung: SVGA, MP4,
  /// GIF, WEBP, PNG, dan JPG.
  Future<List<Map<String, dynamic>>> _daftarHadiah() async {
    final List<Map<String, dynamic>> hasil = <Map<String, dynamic>>[];
    try {
      final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore
          .instance
          .collection('gifts')
          .limit(80)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in q.docs) {
        final Map<String, dynamic> data = d.data();
        if (data['active'] == false || data['aktif'] == false) {
          continue;
        }
        hasil.add(<String, dynamic>{...data, 'id': d.id});
      }
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
    hasil.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int ha =
          ((a['coins'] ?? a['price'] ?? a['harga'] ?? 0) as num).toInt();
      final int hb =
          ((b['coins'] ?? b['price'] ?? b['harga'] ?? 0) as num).toInt();
      return ha.compareTo(hb);
    });
    return hasil;
  }

  /// Kirim hadiah: potong koin, catat di chat, lalu putar animasinya.
  Future<void> _kirimHadiah(
    String giftId,
    List<String> penerima,
    int qty,
  ) async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null || penerima.isEmpty) {
      return;
    }
    final List<Map<String, dynamic>> semua = await _daftarHadiah();
    Map<String, dynamic> g = <String, dynamic>{};
    for (final Map<String, dynamic> e in semua) {
      if ((e['id'] as String?) == giftId) {
        g = e;
        break;
      }
    }
    if (g.isEmpty) {
      _toast('Hadiah tidak ditemukan');
      return;
    }
    final int harga =
        ((g['coins'] ?? g['price'] ?? g['harga'] ?? 0) as num).toInt();
    final int total = harga * qty * penerima.length;
    final Map<String, dynamic>? profil = await ProfileStore.load(u.uid);
    final int koin = ((profil?['coins'] as num?) ?? 0).toInt();
    if (total > koin) {
      _toast('Koin tidak cukup');
      return;
    }
    if (total > 0) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .update(<String, dynamic>{
          'coins': FieldValue.increment(-total),
        });
      } catch (_) {
        _toast('Gagal memotong koin');
        return;
      }
      ProfileStore.lupakan(u.uid);
    }
    final String nama =
        ((g['name'] ?? g['nama'] ?? 'Hadiah') as String);
    _toast('Hadiah terkirim');
    _putarHadiah(g);
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    if (ref != null) {
      try {
        await ref.add(<String, dynamic>{
          'text': '\u{1F381} $_myName mengirim $qty x $nama',
          'uid': u.uid,
          'senderId': u.uid,
          'name': _myName,
          'photoUrl':
              _myPhoto ?? FirebaseAuth.instance.currentUser?.photoURL ?? '',
          'level': _myLevel,
          'countryCode': _myCountry,
          'dj': false,
          'gift': true,
          'giftId': giftId,
          'giftName': nama,
          'giftQty': qty,
          'giftJenis': jenisAset(g),
          'giftSumber': sumberAset(g),
          'giftPenerima': penerima,
          'coins': total,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  OverlayEntry? _hadiahEntry;

  /// Putar animasi hadiah di tengah layar (SVGA, MP4, GIF, WEBP, PNG, JPG).
  void _putarHadiah(Map<String, dynamic> g) {
    if (!mounted) {
      return;
    }
    _hadiahEntry?.remove();
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext c) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SizedBox(
                width: MediaQuery.sizeOf(c).width * 0.7,
                height: MediaQuery.sizeOf(c).width * 0.7,
                child: AsetMedia.dari(g),
              ),
            ),
          ),
        );
      },
    );
    _hadiahEntry = entry;
    Overlay.of(context).insert(entry);
    Timer(const Duration(seconds: 4), () {
      entry.remove();
      if (identical(_hadiahEntry, entry)) {
        _hadiahEntry = null;
      }
    });
  }

  /// Perkecil room: layar ditutup, suara tetap jalan, bulatan kecil tetap
  /// ada di tab Party.
  void _perkecil() {
    RoomSession.minimize(widget.room, mySeat: _mySeat);
    Navigator.of(context).pop();
    _toast('Room diperkecil, audio tetap jalan');
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
                RoomSession.minimize(widget.room, mySeat: _mySeat);
                Navigator.of(context).pop();
                _toast('Room diperkecil, audio tetap jalan');
              },
              child: const Text('Perkecil', style: TextStyle(color: _pink)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                RoomSession.end();
                final int? seatKeluar = _mySeat;
                _mySeat = null;
                unawaited(KursiTertunda.tambah(widget.room.id, seatKeluar));
                unawaited(_hapusKursiSaya());
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

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  /// Notif mengambang di atas semua elemen, tanpa kotak latar, hilang sendiri.
  void _toast(String text) {
    if (!mounted) {
      return;
    }
    _toastTimer?.cancel();
    _toastEntry?.remove();
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    final double bottom = MediaQuery.of(context).padding.bottom + 150;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext ctx) => Positioned(
        left: 24,
        right: 24,
        bottom: bottom,
        child: IgnorePointer(
          child: Center(child: YankoNoticeCard(text: text)),
        ),
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      entry.remove();
      if (_toastEntry == entry) {
        _toastEntry = null;
      }
    });
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? hasil) {
        if (didPop) {
          return;
        }
        // Tombol kembali perangkat memperkecil room, bukan keluar.
        _perkecil();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0B0418),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Lebar decode dibatasi lebar layar: hemat memori dan tidak
          // menghambat saat masuk room.
          if (_themeBytes != null)
            Image.memory(_themeBytes!,
                fit: BoxFit.cover, cacheWidth: _latarW, gaplessPlayback: true)
          else
            const ResImage(AppAssets.roomBg1, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: kb),
              child: LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints c) {
                  final double stageH =
                      (c.maxHeight - (compact ? 158 : 250)).clamp(110.0, 300.0);
                  return Column(
                    children: <Widget>[
                      _topBar(),
                      ValueListenableBuilder<Map<int, Map<String, dynamic>>>(
                        valueListenable: _seatsNotifier,
                        builder: (BuildContext c, _, __) => _stage(stageH),
                      ),
                      if (!compact) _noticeBox(),
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(child: _chatList()),
                            if (!compact)
                              Positioned(
                                right: 0,
                                bottom: 6,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (widget.room.id != null)
                                      LuckyBagSideIcon(
                                        roomId: widget.room.id!,
                                        onClaim: _ambilLuckyBag,
                                      ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _toast('Roket segera hadir'),
                                      child: const ResImage('roomtools_rocket',
                                          width: 44, height: 44),
                                    ),
                                    const SizedBox(height: 8),
                                    _rechargeCard(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
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
              ClipOval(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: _coverBytes != null
                      ? Image.memory(_coverBytes!,
                          fit: BoxFit.cover, gaplessPlayback: true)
                      : const ResImage('demo_m1', fit: BoxFit.cover),
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
                    Text(
                      'ID ${_ownerPublicId.isEmpty ? '-' : _ownerPublicId}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _viewerChip(),
              const SizedBox(width: 4),
              _actionPill(),
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
              '$_onlineCount',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  /// Tiga aksi dalam satu pill gelap: pengaturan, bagikan, keluar.
  Widget _actionPill() {
    Widget divider() => Container(
          width: 1,
          height: 17,
          color: Colors.white.withValues(alpha: 0.28),
        );
    Widget cell(Widget icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: 38, height: 30, child: Center(child: icon)),
        );
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          cell(
            const CustomPaint(
              size: Size(18, 18),
              painter: _GearPainter(),
            ),
            _openSettings,
          ),
          divider(),
          cell(
            Transform.flip(
              flipX: true,
              child: const Icon(Icons.reply, color: Colors.white, size: 20),
            ),
            _shareRoom,
          ),
          divider(),
          cell(
            const Icon(Icons.power_settings_new, color: Colors.white, size: 18),
            _powerPressed,
          ),
        ],
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
    final List<List<int>> rows = _seatRows();
    // Ukuran kursi menyesuaikan jumlah baris supaya semuanya muat tanpa
    // mengecilkan lebar panggung, jadi kursi tetap sampai ke tepi layar.
    final double seatSize = rows.length >= 3 ? 46 : 52;
    return SizedBox(
      height: tinggi,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 6),
                _hostSeat(seatSize),
                const SizedBox(height: 6),
                for (final List<int> row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    // Kursi dibagi rata dengan sisa 20 px dari tepi layar.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          for (final int n in row) _micSeat(n, seatSize),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 40,
            child: _agencyBadge(),
          ),
        ],
      ),
    );
  }

  /// Baris kursi tamu mengikuti mode mic yang dipilih owner
  /// (9 = 4-4, 11 = 5-5, 13 = 4-4-4).
  /// Jumlah mic sesuai mode ('9 Mics' -> 9). Dipakai untuk susunan kursi.
  int get _micTotal => int.tryParse(_micMode.split(' ').first) ?? 11;

  List<List<int>> _seatRows() {
    // roomSeatRows memakai jumlah TOTAL (termasuk host): 9, 11, atau 13.
    final List<int> sizes = roomSeatRows(_micTotal);
    final List<List<int>> rows = <List<int>>[];
    int n = 1;
    for (final int count in sizes) {
      rows.add(<int>[for (int i = 0; i < count; i++) n++]);
    }
    return rows;
  }

  /// Penghuni kursi: data Firestore, dengan nama dan foto terbaru untuk diri
  /// sendiri.
  Map<String, dynamic>? _occupant(int index) {
    final Map<String, dynamic>? o = _seatUsers[index];
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (o != null) {
      if ((o['uid'] as String?) == myUid) {
        return <String, dynamic>{
          'uid': myUid,
          'name': _myName,
          'photoUrl': _myPhoto ??
              FirebaseAuth.instance.currentUser?.photoURL ??
              (o['photoUrl'] as String?) ??
              '',
        };
      }
      return o;
    }
    if (index == 0 && _ownerId.isNotEmpty) {
      return <String, dynamic>{'uid': _ownerId, 'name': 'Owner'};
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>>? get _myMemberRef {
    final String? id = widget.room.id;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) {
      return null;
    }
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(id)
        .collection('members')
        .doc(uid);
  }

  /// Kehadiran: tulis detak tiap 20 detik, hitung anggota yang detaknya
  /// masih segar (kurang dari 60 detik).
  void _startPresence() {
    final String? id = widget.room.id;
    if (id == null) {
      return;
    }
    Future<void> beat() async {
      final User? u = FirebaseAuth.instance.currentUser;
      final DocumentReference<Map<String, dynamic>>? ref = _myMemberRef;
      if (u == null || ref == null) {
        return;
      }
      try {
        await ref.set(<String, dynamic>{
          'uid': u.uid,
          'name': _myName,
          'beat': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    beat();
    _beat = Timer.periodic(const Duration(seconds: 20), (_) => beat());
    _membersSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(id)
        .collection('members')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snap) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      int n = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        final Timestamp? t = d.data()['beat'] as Timestamp?;
        final int ms = t?.millisecondsSinceEpoch ?? now;
        if (now - ms < 60000) {
          n++;
        }
      }
      if (mounted) {
        setState(() => _onlineCount = n < 1 ? 1 : n);
      }
    });
  }

  Future<void> _loadOwnerPublicId(String uid) async {
    final Map<String, dynamic>? p = await ProfileStore.load(uid);
    final String? pid = p?['publicId'] as String?;
    if (mounted && pid != null && pid.isNotEmpty && pid != _ownerPublicId) {
      setState(() => _ownerPublicId = pid);
    }
  }

  /// Hapus semua kursi milik akun ini di room ini. Dipakai saat keluar room
  /// dan saat masuk sebagai pendengar, supaya tidak ada kursi yang tertinggal.
  Future<void> _hapusKursiSaya() async {
    final String? id = widget.room.id;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) {
      return;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> mine = await FirebaseFirestore
          .instance
          .collection('rooms')
          .doc(id)
          .collection('seats')
          .where('uid', isEqualTo: uid)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in mine.docs) {
        await d.reference.delete();
      }
    } catch (_) {
      // Offline atau ditolak aturan: tidak menghalangi keluar room.
    }
  }

  void _onSeats(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) {
      return;
    }
    final Map<int, Map<String, dynamic>> out = <int, Map<String, dynamic>>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
      final Map<String, dynamic> m = d.data();
      final int idx =
          (m['seat'] as num?)?.toInt() ?? int.tryParse(d.id) ?? -1;
      if (idx >= 0) {
        out[idx] = m;
      }
    }
    // Jaga-jaga: satu akun hanya ditampilkan di satu kursi. Untuk akun
    // sendiri, kursi yang berlaku adalah _mySeat; yang lain dibuang dari
    // tampilan sampai server selesai membersihkan.
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final Set<String> terlihat = <String>{};
    final List<int> urut = out.keys.toList()..sort();
    for (final int k in urut) {
      final String? uid = out[k]?['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        continue;
      }
      if (uid == myUid && _mySeat != null && k != _mySeat) {
        out.remove(k);
        continue;
      }
      if (!terlihat.add(uid)) {
        out.remove(k);
      }
    }
    if (mounted) {
      _seatsNotifier.value = out;
    }
  }

  /// Simpan kursiku ke Firestore supaya user lain melihat penghuninya.
  // Kursi terakhir yang berhasil ditulis ke server, dipakai untuk menghapus
  // kursi lama secara pasti saat pindah.
  int? _seatTertulis;
  Future<void>? _seatAntrean;
  StreamSubscription<Map<String, dynamic>>? _subKursiCepat;
  StreamSubscription<Map<String, dynamic>>? _subKursiWs;

  /// Sinkronkan kursi ke server. Pindah kursi dikerjakan sebagai satu batch
  /// atomik (hapus kursi lama + tulis kursi baru) dan diantrekan, jadi akun
  /// tidak pernah tercatat di dua kursi sekaligus.
  Future<void> _syncSeat() {
    final Future<void> sebelumnya = _seatAntrean ?? Future<void>.value();
    final Future<void> kerja = sebelumnya.then((_) => _tulisSeat());
    _seatAntrean = kerja.catchError((Object _) {});
    return kerja;
  }

  Future<void> _tulisSeat() async {
    final String? id = widget.room.id;
    final User? u = FirebaseAuth.instance.currentUser;
    if (id == null || u == null) {
      return;
    }
    final CollectionReference<Map<String, dynamic>> col = FirebaseFirestore
        .instance
        .collection('rooms')
        .doc(id)
        .collection('seats');
    // Ambil keadaan terbaru saat giliran ini jalan, bukan saat dipanggil.
    final int? seat = _mySeat;
    final int? lama = _seatTertulis;
    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      if (lama != null && lama != seat) {
        batch.delete(col.doc('$lama'));
      }
      // Dokumen kursi memakai id = nomor kursi, jadi kursi lama bisa dihapus
      // langsung tanpa query. Dulu ada query `where(uid)` di sini dan itu
      // membuat tiap pindah kursi menunggu satu putaran jaringan sebelum
      // menulis, sehingga nama di kursi baru terlihat telat di HP lain.
      if (seat != null) {
        batch.set(col.doc('$seat'), <String, dynamic>{
          'uid': u.uid,
          'seat': seat,
          'name': _myName,
          'photoUrl': _myPhoto ?? u.photoURL ?? '',
          'micOn': _micOn,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      _seatTertulis = seat;
      // Sisa kursi lama (mis. dari sesi sebelumnya) dibersihkan di latar
      // belakang supaya tidak memperlambat perpindahan kursi.
      unawaited(_bersihkanKursiGanda(col, u.uid, seat));
    } catch (_) {
      // Offline atau ditolak aturan: kursi tetap jalan di perangkat ini.
    }
  }

  /// Hapus kursi lain milik akun ini yang tertinggal. Dijalankan setelah
  /// tulisan kursi selesai, tidak menahan tampilan.
  Future<void> _bersihkanKursiGanda(
    CollectionReference<Map<String, dynamic>> col,
    String uid,
    int? seat,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> mine =
          await col.where('uid', isEqualTo: uid).get();
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      bool ada = false;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in mine.docs) {
        if (seat == null || d.id != '$seat') {
          batch.delete(d.reference);
          ada = true;
        }
      }
      if (ada) {
        await batch.commit();
      }
    } catch (_) {
      // Diabaikan: kursi utama sudah benar.
    }
  }

  Widget _hostSeat(double size) {
    // Kursi atas disamakan dengan kursi lain: kecil, tanpa mahkota. Bila ada
    // penghuninya (data kursi), ketuk membuka sheet profil; bila kosong,
    // ketuk = duduk (khusus owner).
    final Map<String, dynamic>? occ = _seatUsers[0] == null
        ? null
        : _occupant(0);
    final bool mine = _mySeat == 0;
    final String? photo = occ?['photoUrl'] as String?;
    final bool occupied = occ != null;
    return GestureDetector(
      onTap: () {
        if (!occupied) {
          _takeSeat(0);
          return;
        }
        final String uid = (occ?['uid'] as String?) ?? '';
        if (_isOwner && uid.isNotEmpty && uid != _myUid()) {
          _aksiOwner(0, occ!);
        } else {
          _openSeatProfile(0, occ!);
        }
      },
      child: SizedBox(
        width: size + 2,
        child: Column(
          children: <Widget>[
            SizedBox(
              width: size,
              height: size,
              child: _seatFace(
                occupied ? photo : null,
                mine,
                size,
                (occ?['uid'] as String?) ?? '',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              occupied ? ((occ['name'] as String?) ?? 'Owner') : 'Owner',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mine ? const Color(0xFF3DD68C) : Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seatFace(String? photo, bool mine, double size, [String uid = '']) {
    if (photo == null || photo.isEmpty) {
      return ResImage('room_mic_seat_empty', width: size, height: size);
    }
    return BingkaiFoto(uid: uid, ukuran: size, photo: photo);
  }

  Widget _micSeat(int index, double size) {
    final Map<String, dynamic>? occ = _occupant(index);
    final bool mine = _mySeat == index;
    final bool locked = _lockedSeats.contains(index);
    final bool muted = _mutedSeats.contains(index);
    final String? photo = occ?['photoUrl'] as String?;
    final bool occupied = photo != null && photo.isNotEmpty;
    // Mic off: milik sendiri dari status lokal, milik orang lain dari data kursi.
    final bool micOffBadge = (occupied || mine) &&
        (mine
            ? !_micOn
            : (muted || ((_seatUsers[index]?['micOn'] as bool?) == false)));
    return GestureDetector(
      onTap: () {
        if (occ != null) {
          final String uid = (occ['uid'] as String?) ?? '';
          if (_isOwner && uid.isNotEmpty && uid != _myUid()) {
            _aksiOwner(index, occ);
          } else {
            _openSeatProfile(index, occ);
          }
        } else {
          _takeSeat(index);
        }
      },
      child: SizedBox(
        width: size + 2,
        child: Column(
          children: <Widget>[
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: _seatCircle(
                      occupied,
                      mine,
                      locked,
                      muted,
                      photo,
                      size,
                      (occ?['uid'] as String?) ?? '',
                    ),
                  ),
                  if (micOffBadge)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: size * 0.38,
                        height: size * 0.38,
                        decoration: BoxDecoration(
                          color: const Color(0xCC1A1630),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Icon(Icons.mic_off,
                            size: size * 0.22, color: const Color(0xFFFFC53D)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (occ?['name'] as String?) ?? '$index',
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

  /// Lingkaran isi kursi: foto, terkunci, dibisukan, atau kosong.
  Widget _seatCircle(bool occupied, bool mine, bool locked, bool muted,
      String? photo, double size, [String uid = '']) {
    return SizedBox(
              width: size,
              height: size,
              child: occupied || mine
                  ? _seatFace(
                      occupied
                          ? photo
                          : (_myPhoto ??
                              FirebaseAuth.instance.currentUser?.photoURL),
                      mine,
                      size,
                      occupied ? uid : (FirebaseAuth.instance.currentUser?.uid ?? ''),
                    )
                  : locked
                      ? ResImage('room_mic_seat_locked',
                          width: size, height: size)
                      : muted
                          ? ResImage('room_mic_seat_muted',
                              width: size, height: size)
                          : _seatFace(null, false, size),
    );
  }

  // ------------------------------------------------------ sheet profil kursi

  Widget _ownerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFD65C), Color(0xFFE79A19)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Owner',
        style: TextStyle(
          color: Color(0xFF3A2400),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _openFullProfile(
    Map<String, dynamic> data,
    Map<String, dynamic> occ,
    bool isMe,
  ) {
    final Map<String, dynamic> p = <String, dynamic>{...occ, ...data};
    if (((p['displayName'] as String?) ?? '').isEmpty) {
      p['displayName'] = (occ['name'] as String?) ?? 'User';
    }
    if (((p['photoUrl'] as String?) ?? '').isEmpty) {
      p['photoUrl'] = (occ['photoUrl'] as String?) ?? '';
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(profile: p, isOwn: isMe),
      ),
    );
  }

  /// Aksi owner pada kursi: turunkan, undang ke mic, atau keluarkan dari room.
  String _myUid() => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Aksi owner pada kursi: turunkan, undang ke mic, atau keluarkan dari room.
  Future<void> _aksiOwner(int index, Map<String, dynamic> occ) async {
    final String uid = (occ['uid'] as String?) ?? '';
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String? id = widget.room.id;
    if (!_isOwner || id == null || uid.isEmpty || uid == myUid) {
      await _openSeatProfile(index, occ);
      return;
    }
    final String nama = ((occ['name'] as String?) ?? '').isEmpty
        ? 'User'
        : occ['name'] as String;

    final String? pilih = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        Widget baris(String kunci, String label, String ket, Color warna) {
          return InkWell(
            onTap: () => Navigator.of(ctx).pop(kunci),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF241A3D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: warna.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      kunci == 'turun'
                          ? Icons.arrow_downward_rounded
                          : kunci == 'undang'
                              ? Icons.mic_rounded
                              : kunci == 'keluar'
                                  ? Icons.logout_rounded
                                  : Icons.person_rounded,
                      size: 17,
                      color: warna,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                color: warna,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 1),
                        Text(ket,
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFFB9AECB))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1130),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x66FFC53D)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text('Kursi $index',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFB9AECB))),
                    ],
                  ),
                ),
                baris('profil', 'Lihat profil', 'Buka profil pengguna',
                    const Color(0xFFB9AECB)),
                baris('undang', 'Undang ke mic',
                    'Kirim undangan naik ke kursi $index', _pink),
                baris('turun', 'Turunkan dari kursi',
                    'Lepas pengguna dari kursi mic', const Color(0xFFFFC53D)),
                baris('keluar', 'Keluarkan dari room',
                    'Pengguna dikeluarkan dan tidak bisa masuk lagi',
                    const Color(0xFFE5484D)),
              ],
            ),
          ),
        );
      },
    );

    if (pilih == null || !mounted) {
      return;
    }
    final DocumentReference<Map<String, dynamic>> roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(id);
    switch (pilih) {
      case 'profil':
        await _openSeatProfile(index, occ);
      case 'undang':
        try {
          await roomRef.collection('invites').doc(uid).set(<String, dynamic>{
            'seat': index,
            'by': myUid,
            'at': FieldValue.serverTimestamp(),
          });
          _toast('$nama diundang ke kursi $index');
        } catch (_) {
          _toast('Gagal mengundang');
        }
      case 'turun':
        try {
          await roomRef.collection('seats').doc('$index').delete();
          _toast('$nama diturunkan dari kursi');
        } catch (_) {
          _toast('Gagal menurunkan');
        }
      case 'keluar':
        final bool? ya = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Keluarkan $nama?',
                style: const TextStyle(fontSize: 15.5, color: _ink)),
            content: const Text(
              'Pengguna akan dikeluarkan dari room ini dan tidak bisa masuk lagi.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8AA8)),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal', style: TextStyle(color: _ink)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Keluarkan',
                    style: TextStyle(color: Color(0xFFE5484D))),
              ),
            ],
          ),
        );
        if (ya != true) {
          return;
        }
        try {
          await roomRef.update(<String, dynamic>{
            'blacklist': FieldValue.arrayUnion(<String>[uid]),
          });
          await roomRef.collection('seats').doc('$index').delete();
          await roomRef.collection('members').doc(uid).delete();
          _toast('$nama dikeluarkan dari room');
        } catch (_) {
          _toast('Gagal mengeluarkan pengguna');
        }
    }
  }

  Future<void> _openSeatProfile(int index, Map<String, dynamic> occ) async {
    final String uid = (occ['uid'] as String?) ?? '';
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isMe = uid.isNotEmpty && uid == myUid;
    final bool owner = uid.isNotEmpty && uid == _ownerId;
    final bool leaveable = isMe && _mySeat == index;

    // Nilai awal dari data kursi supaya sheet langsung tampil, tanpa menunggu
    // jaringan. Profil lengkap menyusul dan memperbarui isi sheet.
    final ValueNotifier<Map<String, dynamic>> live =
        ValueNotifier<Map<String, dynamic>>(<String, dynamic>{
      'displayName': ((occ['name'] as String?) ?? '').isEmpty
          ? 'User'
          : occ['name'],
      'photoUrl': (occ['photoUrl'] as String?) ?? '',
      'publicId': uid.isEmpty ? '-' : ProfileStore.publicId(uid),
      'level': (occ['level'] as num?)?.toInt() ?? 1,
    });

    if (uid.isNotEmpty) {
      unawaited(FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .then((DocumentSnapshot<Map<String, dynamic>> snap) {
        final Map<String, dynamic>? d = snap.data();
        if (d == null) {
          return;
        }
        final String dn = (d['displayName'] as String?) ?? '';
        final String pu = (d['photoUrl'] as String?) ?? '';
        live.value = <String, dynamic>{
          ...live.value,
          ...d,
          'displayName': dn.isEmpty ? live.value['displayName'] : dn,
          'photoUrl': pu.isEmpty ? live.value['photoUrl'] : pu,
          'publicId': (d['publicId'] as String?) ?? live.value['publicId'],
          'level': (d['level'] as num?)?.toInt() ??
              (1 + ((d['coins'] as num?)?.toInt() ?? 0) ~/ 50).clamp(1, 99),
        };
      }).catchError((Object _) {
        // Profil tidak terbaca: sheet tetap memakai data kursi.
      }));
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext ctx) {
        return ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: live,
          builder: (BuildContext ctx, Map<String, dynamic> v, Widget? _) {
            final String name = (v['displayName'] as String?) ?? 'User';
            final String bendera = benderaNegara(v['countryCode'] as String?);
            final String photo = (v['photoUrl'] as String?) ?? '';
            final String pid = (v['publicId'] as String?) ?? '-';
            final int level = (v['level'] as num?)?.toInt() ?? 1;
            final Map<String, dynamic> data = v;
            return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E1EF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openFullProfile(data, occ, isMe);
                  },
                  child: BingkaiFoto(
                    uid: (data['uid'] as String?) ?? (occ['uid'] as String?) ?? '',
                    ukuran: 52,
                    photo: photo,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (owner) ...<Widget>[
                      _ownerBadge(),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (bendera.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(bendera, style: const TextStyle(fontSize: 16)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5484D),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: pid));
                        _toast('ID $pid disalin');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'ID:$pid',
                            style: const TextStyle(
                              color: Color(0xFF8E8AA8),
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.copy,
                              size: 13, color: Color(0xFF8E8AA8)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: const Color(0xFFEDEBF3)),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      if (leaveable) ...<Widget>[
                        Expanded(
                          child: _sheetAction(
                            icon: const CustomPaint(
                              size: Size(30, 30),
                              painter: _SeatDownPainter(),
                            ),
                            label: 'Turun Mic',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _toggleSeat(index);
                            },
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: const Color(0xFFEDEBF3),
                        ),
                      ],
                      Expanded(
                        child: _sheetAction(
                          icon: const ResImage('room_gift_button',
                              width: 32, height: 32),
                          label: 'Hadiah',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openGift(preselectUid: uid.isEmpty ? null : uid);
                          },
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
        );
      },
    );
    live.dispose();
  }

  Widget _sheetAction({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 34,
              height: 34,
              child: Center(child: icon),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E8AA8),
                fontSize: 12,
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
      onTap: () => _toast('Recharge Event segera hadir'),
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

  // ------------------------------------------------------------- chat

  /// Ambil kantong koin dan tampilkan popup hasil.
  Future<void> _ambilLuckyBag(String bagId, Map<String, dynamic> data) async {
    final String? rid = widget.room.id;
    if (rid == null) {
      return;
    }
    final ({int? coins, String? alasan}) r = await LuckyBagService.claim(rid, bagId);
    if (!mounted) {
      return;
    }
    await showLuckyBagResult(
      context,
      senderName: (data['senderName'] as String?) ?? 'User',
      senderPhoto: (data['senderPhoto'] as String?) ?? '',
      coins: r.coins,
      alasan: r.alasan,
    );
  }

  Widget _chatList() {
    final CollectionReference<Map<String, dynamic>>? ref = _chatRef;
    if (ref == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
        final DateTime? since = RoomSession.chatSince;
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            (snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((QueryDocumentSnapshot<Map<String, dynamic>> d) {
          if (since == null) {
            return true;
          }
          final Timestamp? t = d.data()['createdAt'] as Timestamp?;
          // Pesan tanpa cap waktu dianggap bagian sesi ini.
          return t == null || !t.toDate().isBefore(since);
        }).toList();
        return ListView.builder(
          controller: _chatScroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
          itemCount: docs.length + 1,
          itemBuilder: (BuildContext ctx, int i) {
            if (i >= docs.length) {
              return _announcementLine();
            }
            final Map<String, dynamic> m = docs[i].data();
            if (m['type'] == 'luckybag' && widget.room.id != null) {
              return LuckyBagChatLive(
                roomId: widget.room.id!,
                bagId: (m['bagId'] as String?) ?? docs[i].id,
                onClaim: _ambilLuckyBag,
              );
            }
            if ((m['system'] as bool?) ?? false) {
              return _joinLine(m);
            }
            return _chatRow(m);
          },
        );
      },
    );
  }

  /// Baris chat: foto, nama, slot medal (kosong, aset belum ada), level, lalu
  /// teks pesan dalam gelembung di bawahnya.
  Widget _chatRow(Map<String, dynamic> m) {
    final bool dj = (m['dj'] as bool?) ?? false;
    final String photo = (m['photoUrl'] as String?) ?? '';
    final String name = (m['name'] as String?) ?? 'User';
    final String bendera = benderaNegara(m['countryCode'] as String?);
    final int level = (m['level'] as num?)?.toInt() ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: () => _openChatProfile(m),
            child: SizedBox(
            width: 34,
            height: 34,
            child: ClipOval(
              child: photo.isEmpty
                  ? Container(
                      color: const Color(0xFF5B2FA8),
                      alignment: Alignment.center,
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    )
                  : AvatarImage(
                      source: photo,
                      fallback: const ResImage('demo_m1', fit: BoxFit.cover),
                    ),
            ),
          ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openChatProfile(m),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: dj
                                ? const Color(0xFFFFC53D)
                                : const Color(0xFFB8B5C8),
                          ),
                        ),
                      ),
                    ),
                    if (bendera.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 5),
                      Text(bendera, style: const TextStyle(fontSize: 12)),
                    ],
                    // Slot medal dikosongkan sampai aset medal diunggah.
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFFFFD65C),
                            Color(0xFFE79A19),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv.$level',
                        style: const TextStyle(
                          color: Color(0xFF3A2400),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (m['text'] as String?) ?? '',
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Baris "X entered the room": nama bisa diketuk membuka sheet profil.
  Widget _joinLine(Map<String, dynamic> m) {
    final String name = (m['name'] as String?) ?? 'User';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => _openChatProfile(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: Color(0xFF9B7BFF), fontSize: 10.5),
              children: <InlineSpan>[
                const TextSpan(text: 'Welcome '),
                TextSpan(
                  text: name,
                  style: const TextStyle(
                    color: Color(0xFFFFC53D),
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' entered the room.'),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// Buka sheet profil dari pesan chat, sama seperti mengetuk foto di kursi mic.
  void _openChatProfile(Map<String, dynamic> m) {
    final String uid = ((m['uid'] as String?) ?? (m['senderId'] as String?) ?? '');
    _openSeatProfile(-1, <String, dynamic>{
      'uid': uid,
      'name': (m['name'] as String?) ?? 'User',
      'photoUrl': (m['photoUrl'] as String?) ?? '',
      'level': (m['level'] as num?)?.toInt() ?? 1,
    });
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
          // Tombol mic: hanya tampil saat duduk di kursi mic.
          if (_mySeat != null) ...<Widget>[
            const SizedBox(width: 7),
            GestureDetector(
              onTap: _toggleMic,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _micOn ? Icons.mic : Icons.mic_off,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ],
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


/// Ikon pengaturan: heksagon tebal berlubang, putih (gaya referensi).
class _GearPainter extends CustomPainter {
  const _GearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;
    final Path hex = Path();
    for (int i = 0; i < 6; i++) {
      final double a = math.pi / 6 + i * math.pi / 3;
      final Offset p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        hex.moveTo(p.dx, p.dy);
      } else {
        hex.lineTo(p.dx, p.dy);
      }
    }
    hex.close();
    final Paint fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(hex, fill);
    canvas.drawPath(hex, fill..style = PaintingStyle.stroke);
    canvas.drawCircle(c, r * 0.42, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Ikon "Turun Mic": kursi/sofa abu-abu dengan panah turun di kanan bawah.
class _SeatDownPainter extends CustomPainter {
  const _SeatDownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint p = Paint()
      ..color = const Color(0xFF9A9A9A)
      ..style = PaintingStyle.fill;

    // sandaran punggung
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.10, w * 0.62, h * 0.42),
        Radius.circular(w * 0.18),
      ),
      p,
    );
    // lengan kiri
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.00, h * 0.34, w * 0.22, h * 0.40),
        Radius.circular(w * 0.11),
      ),
      p,
    );
    // dudukan
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.50, w * 0.60, h * 0.28),
        Radius.circular(w * 0.12),
      ),
      p,
    );

    // lingkaran putih sebagai ruang panah
    final Offset c = Offset(w * 0.76, h * 0.72);
    canvas.drawCircle(c, w * 0.25, Paint()..color = Colors.white);
    // panah turun
    final Path a = Path()
      ..moveTo(c.dx - w * 0.15, c.dy - w * 0.02)
      ..lineTo(c.dx + w * 0.15, c.dy - w * 0.02)
      ..lineTo(c.dx, c.dy + w * 0.17)
      ..close();
    canvas.drawPath(a, p);
    canvas.drawRect(
      Rect.fromLTWH(c.dx - w * 0.05, c.dy - w * 0.17, w * 0.10, w * 0.16),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
