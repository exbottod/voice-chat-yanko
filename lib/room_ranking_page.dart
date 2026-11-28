import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'avatar_image.dart';
import 'native_bridge.dart';
import 'profile_store.dart';
import 'res_image.dart';
import 'rooms_live.dart';

const Color _gold = Color(0xFFF4D27A);
const Color _goldDeep = Color(0xFFB98A2E);
const Color _teal = Color(0xFF0E3B34);

/// Peringkat di dalam room: tab Supporters (pengirim gift) dan Charm
/// (penerima gift), dengan rentang Daily / Weekly / Monthly.
///
/// Data: rooms/{id}/rank/{uid} berisi
///   name, photoUrl, sent{Daily,Weekly,Monthly}, got{Daily,Weekly,Monthly}
/// Diisi saat gift dikirim. Sebelum gift aktif semua bernilai 0.
///
/// Bingkai TOP1/2/3: bila aset drawable `rank_frame_top1/2/3` sudah
/// ditambahkan, otomatis dipakai; kalau belum, dipakai bingkai CSS sementara.
class RoomRankingPage extends StatefulWidget {
  const RoomRankingPage({super.key, required this.roomId});

  final String? roomId;

  static Future<void> open(BuildContext context, String? roomId) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => RoomRankingPage(roomId: roomId),
        transitionsBuilder: (_, Animation<double> a, __, Widget c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  State<RoomRankingPage> createState() => _RoomRankingPageState();
}

class _RoomRankingPageState extends State<RoomRankingPage> {
  int _kind = 0; // 0 = Supporters, 1 = Charm
  int _range = 0; // 0 = Daily, 1 = Weekly, 2 = Monthly
  static const List<String> _ranges = <String>['Daily', 'Weekly', 'Monthly'];

  String get _field {
    final String r = _ranges[_range];
    return (_kind == 0 ? 'sent' : 'got') + r;
  }

  Duration _untilReset() {
    final DateTime now = DateTime.now().toUtc();
    final DateTime next;
    if (_range == 0) {
      next = DateTime.utc(now.year, now.month, now.day + 1);
    } else if (_range == 1) {
      next = DateTime.utc(now.year, now.month, now.day)
          .add(Duration(days: 8 - now.weekday));
    } else {
      next = DateTime.utc(now.year, now.month + 1, 1);
    }
    return next.difference(now);
  }

  String _fmtLeft(Duration d) {
    if (d.inDays >= 1) {
      return '${d.inDays} D ${d.inHours % 24} H';
    }
    return '${d.inHours} H ${d.inMinutes % 60}M';
  }

  String _k(int v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}K';
    }
    return '$v';
  }

  /// Peringkat room dibaca dari Realtime Database (satu listener kecil).
  /// Bila belum ada catatan di sana, Firestore dipakai sebagai cadangan supaya
  /// peringkat lama tetap terlihat.
  Stream<List<Map<String, dynamic>>> _stream() {
    final String? id = widget.roomId;
    if (id == null) {
      return Stream<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
    }
    List<Map<String, dynamic>> rapikan(Map<dynamic, dynamic> isi) {
      final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
      isi.forEach((dynamic uid, dynamic nilai) {
        if (uid is! String || nilai is! Map) {
          return;
        }
        final Map<String, dynamic> m = <String, dynamic>{};
        nilai.forEach((dynamic k, dynamic v) {
          m['$k'] = v;
        });
        m['uid'] = uid;
        if (((m[_field] as num?)?.toInt() ?? 0) > 0) {
          out.add(m);
        }
      });
      out.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          ((b[_field] as num?)?.toInt() ?? 0)
              .compareTo((a[_field] as num?)?.toInt() ?? 0));
      return out;
    }

    final Stream<List<Map<String, dynamic>>> dariFirestore =
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(id)
            .collection('rank')
            .snapshots()
            .map((QuerySnapshot<Map<String, dynamic>> s) {
      final List<Map<String, dynamic>> out = s.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              <String, dynamic>{...d.data(), 'uid': d.id})
          .where((Map<String, dynamic> m) =>
              ((m[_field] as num?)?.toInt() ?? 0) > 0)
          .toList()
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
            ((b[_field] as num?)?.toInt() ?? 0)
                .compareTo((a[_field] as num?)?.toInt() ?? 0));
      return out;
    });

    return RoomsLive.instance.pantauRank(id, _field).asyncExpand(
      (Map<String, dynamic> isi) {
        final List<Map<String, dynamic>> hasil = rapikan(isi);
        if (hasil.isEmpty) {
          return dariFirestore;
        }
        return Stream<List<Map<String, dynamic>>>.value(hasil);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(height: MediaQuery.paddingOf(context).top + 52),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFF123F34),
                    Color(0xFF0B2A25),
                    Color(0xFF07191A),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _stream(),
                  builder: (BuildContext c,
                      AsyncSnapshot<List<Map<String, dynamic>>> snap) {
                    final List<Map<String, dynamic>> list =
                        snap.data ?? <Map<String, dynamic>>[];
                    return Column(
                      children: <Widget>[
                        _tabs(),
                        const SizedBox(height: 10),
                        _rangeBar(),
                        const SizedBox(height: 10),
                        _chips(list),
                        Expanded(child: _body(list)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(String t, int i) {
      final bool on = _kind == i;
      return GestureDetector(
        onTap: () => setState(() => _kind = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            t,
            style: TextStyle(
              color: on ? _gold : Colors.white54,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: <Widget>[
          const Spacer(),
          tab('Supporters', 0),
          const SizedBox(width: 18),
          tab('Charm', 1),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.close, color: _gold, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _gold.withValues(alpha: 0.7), width: 1.6),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _ranges.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _range = i),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: _range == i
                        ? const LinearGradient(
                            colors: <Color>[Color(0xFFFFE9A6), Color(0xFFE7B94F)],
                          )
                        : null,
                  ),
                  child: Text(
                    _ranges[i],
                    style: TextStyle(
                      color: _range == i ? const Color(0xFF4A3300) : Colors.white70,
                      fontSize: _range == i ? 17 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chips(List<Map<String, dynamic>> list) {
    int total = 0;
    for (final Map<String, dynamic> m in list) {
      total += (m[_field] as num?)?.toInt() ?? 0;
    }
    Widget chip(Widget icon, String t) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _goldDeep, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            icon,
            const SizedBox(width: 6),
            Text(t,
                style: const TextStyle(
                    color: _gold, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          chip(const Icon(Icons.emoji_events, color: _gold, size: 20), _k(total)),
          chip(const Icon(Icons.timer_outlined, color: _gold, size: 20),
              _fmtLeft(_untilReset())),
          chip(const Icon(Icons.sync, color: _gold, size: 20),
              _range == 0 ? 'Today' : (_range == 1 ? 'Week' : 'Month')),
        ],
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> list) {
    Map<String, dynamic>? at(int i) => i < list.length ? list[i] : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      children: <Widget>[
        _top1(at(0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Expanded(child: _topSmall(at(1), 2)),
              const SizedBox(width: 8),
              Expanded(child: _topSmall(at(2), 3)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (int i = 3; i < list.length; i++) _row(i + 1, list[i]),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Center(
              child: Text(
                'Belum ada peringkat. Poin muncul dari gift yang dikirim di room ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _photo(Map<String, dynamic>? m, double size) {
    final String photo = (m?['photoUrl'] as String?) ?? '';
    final String name = (m?['name'] as String?) ?? '';
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: photo.isNotEmpty
            ? AvatarImage(
                source: photo,
                fallback: const ResImage('room_mic_seat_empty'),
              )
            : Container(
                color: const Color(0xFF5B2FA8),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  /// Bingkai: pakai aset drawable bila ada, kalau tidak bingkai CSS.
  Widget _frame(int rank, double size, Widget child, List<Color> ring) {
    return FutureBuilder<Uint8List?>(
      future: VoiceNative.loadDrawable('rank_frame_top$rank'),
      builder: (BuildContext c, AsyncSnapshot<Uint8List?> s) {
        final Uint8List? bytes = s.data;
        if (bytes != null && bytes.isNotEmpty) {
          return SizedBox(
            width: size * 1.9,
            height: size * 1.9,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
                Transform.translate(
                  offset: Offset(0, -size * 0.12),
                  child: child,
                ),
              ],
            ),
          );
        }
        return Container(
          width: size + 14,
          height: size + 14,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ring,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ring.first.withValues(alpha: 0.45),
                blurRadius: 18,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  Widget _label(int rank, List<Color> ring) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: ring),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'TOP$rank',
        style: const TextStyle(
          color: Color(0xFF2A1E00),
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _top1(Map<String, dynamic>? m) {
    const List<Color> ring = <Color>[Color(0xFFFFE9A6), Color(0xFFB98A2E)];
    final int pts = (m?[_field] as num?)?.toInt() ?? 0;
    return Column(
      children: <Widget>[
        const SizedBox(height: 6),
        _frame(1, 130, _photo(m, 130), ring),
        const SizedBox(height: 6),
        _label(1, ring),
        const SizedBox(height: 6),
        Text(
          m == null ? 'Waiting for you' : ((m['name'] as String?) ?? 'User'),
          style: const TextStyle(
              color: _gold, fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        _coin(pts),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _topSmall(Map<String, dynamic>? m, int rank) {
    final List<Color> ring = rank == 2
        ? <Color>[const Color(0xFFE6EEF5), const Color(0xFF7C8A99)]
        : <Color>[const Color(0xFFF1C6BE), const Color(0xFF8E5A56)];
    final int pts = (m?[_field] as num?)?.toInt() ?? 0;
    return Column(
      children: <Widget>[
        _frame(
          rank,
          92,
          m == null
              ? Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0B2A25),
                  ),
                  child: const Icon(Icons.event_seat,
                      color: _gold, size: 36),
                )
              : _photo(m, 92),
          ring,
        ),
        const SizedBox(height: 4),
        _label(rank, ring),
        const SizedBox(height: 6),
        Text(
          m == null ? 'Waiting for you' : ((m['name'] as String?) ?? 'User'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: _gold, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (m != null) ...<Widget>[
          const SizedBox(height: 2),
          _coin(pts),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _coin(int v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_k(v),
            style: const TextStyle(
                color: _gold, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        const Icon(Icons.monetization_on, color: Color(0xFFFFC53D), size: 18),
      ],
    );
  }

  Widget _row(int rank, Map<String, dynamic> m) {
    final int pts = (m[_field] as num?)?.toInt() ?? 0;
    final String uid = (m['uid'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        border: Border(
          top: BorderSide(color: _goldDeep.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text('$rank',
                style: const TextStyle(color: _gold, fontSize: 19)),
          ),
          _photo(m, 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (m['name'] as String?) ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _gold, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  'ID:${ProfileStore.publicId(uid)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          _coin(pts),
        ],
      ),
    );
  }
}
