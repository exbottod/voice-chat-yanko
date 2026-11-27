import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';
import 'package:flutter/services.dart';

import 'edit_profile_page.dart';
import 'dm_page.dart';
import 'profile_store.dart';
import 'social_service.dart';
import 'avatar_image.dart';
import 'frame_active.dart';
import 'res_image.dart';

import 'countries.dart';

const Color _pink = Color(0xFFFF4F8B);
const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);

/// Layar profil: foto besar, nama, ID, tab Tentang/Hubungan/Penghargaan/Momen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    this.isOwn = true,
  });

  final Map<String, dynamic> profile;

  /// true: profil sendiri (ada tombol Edit). false: profil orang lain.
  final bool isOwn;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;
  late Map<String, dynamic> _data;
  StreamSubscription<bool>? _followSub;
  bool _mengikuti = false;
  bool _prosesFollow = false;

  /// uid pemilik profil yang sedang dilihat.
  String get _targetUid => (_data['uid'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.profile);
    final String t = _targetUid;
    if (t.isNotEmpty) {
      // Segarkan dari Firestore supaya bendera negara dan data lain terbaru.
      ProfileStore.load(t).then((Map<String, dynamic>? p) {
        if (p != null && mounted) {
          setState(() => _data = <String, dynamic>{..._data, ...p});
        }
      });
    }
    if (!widget.isOwn && t.isNotEmpty) {
      _followSub = SocialService.sayaMengikuti(t).listen((bool v) {
        if (mounted) {
          setState(() => _mengikuti = v);
        }
      });
    }
  }

  @override
  void dispose() {
    _followSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleFollow() async {
    if (_prosesFollow || _targetUid.isEmpty) {
      return;
    }
    final bool baru = !_mengikuti;
    // Tampilan berubah seketika; server menyusul.
    setState(() {
      _mengikuti = baru;
      _prosesFollow = true;
    });
    try {
      await SocialService.setFollow(_targetUid, baru);
    } catch (_) {
      if (mounted) {
        setState(() => _mengikuti = !baru);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal, coba lagi')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _prosesFollow = false);
      }
    }
  }

  void _bukaChat() {
    final String t = _targetUid;
    if (t.isEmpty) {
      return;
    }
    final String nama = ((_data['displayName'] as String?) ?? '').isEmpty
        ? 'User'
        : _data['displayName'] as String;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DmPage(
          targetUid: t,
          targetNama: nama,
          targetFoto: (_data['photoUrl'] as String?) ?? '',
          targetPublicId:
              (_data['publicId'] as String?) ?? ProfileStore.publicId(t),
        ),
      ),
    );
  }

  Future<void> _openEdit() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfilePage(profile: _data),
      ),
    );
    if (saved == true) {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final Map<String, dynamic>? fresh = await ProfileStore.load(user.uid);
        if (fresh != null && mounted) {
          setState(() => _data = fresh);
        }
      }
    }
  }

  static const List<String> _tabs = <String>[
    'Tentang',
    'Hubungan',
    'Penghargaan',
    'Momen',
  ];

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Map<String, dynamic> p = _data;
    final String name = (p['displayName'] as String?)?.isNotEmpty == true
        ? p['displayName'] as String
        : (user?.displayName ?? 'My name');
    final String gender = (p['gender'] as String?) ?? 'male';
    final int age = ProfileStore.ageFromBirth((p['birthDate'] as String?) ?? '');
    final String pid =
        (p['publicId'] as String?) ?? ProfileStore.publicId(user?.uid ?? '0');
    final String? photo = (p['photoUrl'] as String?) ?? user?.photoURL;
    final bool male = gender != 'female';
    final String bendera = benderaNegara(p['countryCode'] as String?);
    const double coverHeight = 200;
    const double avatarSize = 62;

    final bool tampilAksi = !widget.isOwn && _targetUid.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: tampilAksi ? _barAksi() : null,
      body: Column(
        children: <Widget>[
          // Cover + tombol atas + avatar yang menjorok ke panel
          SizedBox(
            height: coverHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: ResImage(
                    male ? 'demo_m1' : 'demo_f1',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Row(
                      children: <Widget>[
                        _RoundBtn(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        if (widget.isOwn)
                        _RoundBtn(
                          wide: true,
                          onTap: _openEdit,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Panel putih berisi semua info, bisa digulir
          Expanded(
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -18, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        BingkaiAktif(
                          uid: _targetUid.isEmpty
                              ? (FirebaseAuth.instance.currentUser?.uid ?? '')
                              : _targetUid,
                          ukuran: avatarSize,
                          anak: _AvatarBlock(photo: photo, male: male, size: avatarSize),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                  if (bendera.isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Text(bendera,
                                        style: const TextStyle(fontSize: 16)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              _GenderChip(male: male, age: age),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _IdRow(pid: pid),
                    const SizedBox(height: 12),
                    _TabsRow(
                      tabs: _tabs,
                      index: _tab,
                      onSelect: (int i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 14),
                    _tabBody(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dua tombol di bawah profil orang lain: Follow dan Chat.
  Widget _barAksi() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1EFF6))),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: _toggleFollow,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _mengikuti ? const Color(0xFFF4F2FA) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: _mengikuti
                          ? const Color(0xFFD9D5EA)
                          : const Color(0xFFEC4899),
                      width: 1.6,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _mengikuti ? Icons.check : Icons.add,
                        size: 20,
                        color: _mengikuti
                            ? const Color(0xFF8E8AA8)
                            : const Color(0xFFEC4899),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _mengikuti ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _mengikuti
                              ? const Color(0xFF8E8AA8)
                              : _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: _bukaChat,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFFFB923C),
                        Color(0xFFEC4899),
                        Color(0xFF9333EA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.chat_bubble_rounded,
                          size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case 0:
        if (!widget.isOwn) {
          // Profil orang lain: tidak ada tombol tambah foto.
          return const _Empty(
              asset: 'empty_empty_photos', text: 'Belum ada foto');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Album profil',
              style: TextStyle(fontSize: 16, color: _ink),
            ),
            const SizedBox(height: 14),
            Container(
              width: 158,
              height: 158,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _pink.withValues(alpha: 0.7), width: 1.6),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.add, size: 38, color: _pink),
                  SizedBox(height: 8),
                  Text(
                    'Tambah foto',
                    style: TextStyle(fontSize: 12.5, color: _pink),
                  ),
                ],
              ),
            ),
          ],
        );
      case 1:
        return const _Empty(asset: 'empty_empty_people', text: 'Belum ada hubungan');
      case 2:
        return const _Empty(asset: 'empty_empty_items', text: 'Belum ada penghargaan');
      default:
        return const _Empty(asset: 'empty_empty_photos', text: 'Belum ada momen');
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.asset, required this.text});

  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: <Widget>[
            ResImage(asset, width: 170, height: 150),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 14, color: _muted)),
          ],
        ),
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.photo,
    required this.male,
    required this.size,
  });

  final String? photo;
  final bool male;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String fallback = male ? 'demo_m1' : 'demo_f1';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        color: const Color(0xFFE8F1FB),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: photo != null
            ? AvatarImage(
                source: photo,
                width: size,
                height: size,
                fallback: ResImage(fallback, fit: BoxFit.cover),
              )
            : ResImage(fallback, fit: BoxFit.cover),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.male, required this.age});

  final bool male;
  final int age;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: male ? const Color(0xFF4C8DF6) : const Color(0xFFFF6FA5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(male ? Icons.male : Icons.female, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$age',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdRow extends StatelessWidget {
  const _IdRow({required this.pid});

  final String pid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text('ID:$pid', style: const TextStyle(fontSize: 11.5, color: _muted)),
        const SizedBox(width: 6),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: pid));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ID disalin'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Icon(Icons.copy_outlined, size: 14, color: _muted),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 14, color: const Color(0xFFE2E0EC)),
        const SizedBox(width: 12),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Online',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF22C55E)),
        ),
      ],
    );
  }
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Empat kolom sama lebar. Teks menyusut otomatis (FittedBox) sehingga tidak
    // pernah terpotong di layar sempit, dan skala font perangkat dikunci.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: 22,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tabs[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                index == i ? FontWeight.w700 : FontWeight.w400,
                            color: index == i
                                ? _ink
                                : _muted.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: index == i ? _pink : Colors.transparent,
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

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.child, required this.onTap, this.wide = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 52,
        width: wide ? 92 : 52,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(child: child),
      ),
    );
  }
}
