import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'collection_page.dart';
import 'lucky_bag.dart';
import 'room_session.dart';
import 'store_page.dart' show StorePage, MyItemsPage;

const Color _ink = Color(0xFF1F1A3D);
const Color _pink = Color(0xFFFF4F8B);
const Color _muted = Color(0xFF8E8AA8);

/// Menu kotak di dalam room: Lucky Game, Party, dan Tools.
class RoomMenuPage extends StatefulWidget {
  const RoomMenuPage({super.key, required this.roomId, required this.roomName});

  final String roomId;
  final String roomName;

  @override
  State<RoomMenuPage> createState() => _RoomMenuPageState();
}

class _RoomMenuPageState extends State<RoomMenuPage> {
  CollectionReference<Map<String, dynamic>> get _chat => FirebaseFirestore.instance
      .collection('rooms')
      .doc(widget.roomId)
      .collection('messages');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _name {
    final String? n = FirebaseAuth.instance.currentUser?.displayName;
    return (n == null || n.isEmpty) ? 'Kamu' : n;
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _sendChat(String text, {bool dj = false}) async {
    if (text.trim().isEmpty) {
      return;
    }
    await _chat.add(<String, dynamic>{
      'text': text.trim(),
      'uid': _uid,
      'senderId': _uid,
      'name': dj ? 'DJ' : _name,
      'dj': dj,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _luckyNumber() async {
    final int number = Random().nextInt(100) + 1;
    await _sendChat('Lucky Number $number', dj: true);
    if (mounted) {
      Navigator.of(context).pop();
      _toast('Lucky Number $number terkirim ke chat room');
    }
  }

  Future<void> _luckyBag() async {
    final User? u = FirebaseAuth.instance.currentUser;
    String foto = u?.photoURL ?? '';
    try {
      final DocumentSnapshot<Map<String, dynamic>> p =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final String? url = p.data()?['photoUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        foto = url;
      }
    } catch (_) {}
    if (!mounted) {
      return;
    }
    final bool terkirim = await showLuckyBagSheet(
      context,
      roomId: widget.roomId,
      senderName: _name,
      senderPhoto: foto,
    );
    if (terkirim && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<int> _readCoins() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      return (snap.data()?['coins'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Hapus riwayat chat room untuk semua user.
  ///
  /// Owner room menghapus seluruh pesan, user lain hanya pesannya sendiri.
  /// Pesan dihapus bertahap 400 dokumen per batch (batas Firestore 500).
  Future<void> _clearChat() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear chat', style: TextStyle(fontSize: 16, color: _ink)),
        content: const Text(
          'Riwayat chat di room ini akan dihapus untuk semua user dan langsung '
          'hilang dari layar semua orang.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus semua', style: TextStyle(color: Color(0xFFE5484D))),
          ),
        ],
      ),
    );
    if (yes != true) {
      return;
    }

    if (mounted) {
      _toast('Membersihkan chat...');
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> room = await FirebaseFirestore
          .instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      final String ownerId = (room.data()?['ownerId'] as String?) ?? '';
      final bool isOwner = ownerId.isNotEmpty && ownerId == _uid;

      final QuerySnapshot<Map<String, dynamic>> semua = isOwner
          ? await _chat.get()
          : await _chat.where('senderId', isEqualTo: _uid).get();

      if (semua.docs.isEmpty) {
        if (mounted) {
          _toast(isOwner ? 'Chat room sudah kosong' : 'Tidak ada chat milikmu');
        }
        return;
      }

      int terhapus = 0;
      for (int i = 0; i < semua.docs.length; i += 400) {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d
            in semua.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
        terhapus += semua.docs.skip(i).take(400).length;
      }

      // Sesi chat dimulai ulang supaya layar room langsung bersih.
      RoomSession.chatSince = DateTime.now();

      if (mounted) {
        _toast(isOwner
            ? '$terhapus chat dihapus untuk semua user'
            : '$terhapus chat kamu dihapus. Semua chat hanya bisa dihapus owner room.');
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        _toast(e.code == 'permission-denied'
            ? 'Tidak diizinkan. Hanya owner room yang bisa menghapus semua chat.'
            : 'Gagal menghapus chat: ${e.code}');
      }
    } catch (e) {
      if (mounted) {
        _toast('Gagal menghapus chat.');
      }
    }
  }

  void _soon(String name) => _toast('$name segera hadir');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120E24),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: <Widget>[
                  _section('Lucky Game'),
                  const SizedBox(height: 10),
                  _emptyGames(),
                  const SizedBox(height: 20),
                  _section('Party'),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _icon('Lucky Number', Icons.eco, const Color(0xFF3DD68C), _luckyNumber),
                      _icon('Truth or Dare', Icons.help_outline, const Color(0xFFE5484D),
                          () => _soon('Truth or Dare')),
                      _icon('Lucky Bag', Icons.card_giftcard, const Color(0xFFFF4F4F), _luckyBag),
                      _icon('PK', Icons.bolt, const Color(0xFF5AA9F5), () => _soon('PK')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      _icon('Lucky Pick', Icons.casino_outlined, const Color(0xFFFFC53D),
                          () => _soon('Lucky Pick')),
                      _icon('Store', Icons.storefront, const Color(0xFF9B7BFF), () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const StorePage()),
                        );
                      }),
                      _icon('Score Board', Icons.emoji_events, const Color(0xFFFFC53D),
                          () => _soon('Score Board')),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section('Tools'),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _icon('Music', Icons.music_note, const Color(0xFF9B7BFF),
                          () => _soon('Music')),
                      _icon('My Items', Icons.shopping_bag_outlined, const Color(0xFFFFC53D), () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const MyItemsPage()),
                        );
                      }),
                      _icon('Clear Chat', Icons.chat_bubble_outline, const Color(0xFF3DD68C),
                          _clearChat),
                      _icon('Room Effect', Icons.auto_fix_high, const Color(0xFF5AA9F5),
                          () => _soon('Room Effect')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      _icon('Koleksi', Icons.collections_bookmark_outlined,
                          const Color(0xFFFF8FB0), () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const CollectionPage()),
                        );
                      }),
                      const Spacer(),
                      const Spacer(),
                      const Spacer(),
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

  Widget _section(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _emptyGames() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sports_esports_outlined, color: Colors.white38, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Belum ada game. Daftar Lucky Game akan muncul di sini setelah diunggah dari panel developer.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
