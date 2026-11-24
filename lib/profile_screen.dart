import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';
import 'package:flutter/services.dart';

import 'edit_profile_page.dart';
import 'profile_store.dart';
import 'avatar_image.dart';
import 'res_image.dart';

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

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.profile);
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
    const double coverHeight = 250;
    const double avatarSize = 78;

    return Scaffold(
      backgroundColor: Colors.white,
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _AvatarBlock(photo: photo, male: male, size: avatarSize),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _GenderChip(male: male, age: age),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _IdRow(pid: pid),
                    const SizedBox(height: 18),
                    _TabsRow(
                      tabs: _tabs,
                      index: _tab,
                      onSelect: (int i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 18),
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

  Widget _tabBody() {
    switch (_tab) {
      case 0:
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
        Text('ID:$pid', style: const TextStyle(fontSize: 13, color: _muted)),
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
          child: const Icon(Icons.copy_outlined, size: 16, color: _muted),
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
          style: TextStyle(fontSize: 13, color: Color(0xFF22C55E)),
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
    return Row(
      children: <Widget>[
        for (int i = 0; i < tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 26),
            child: InkWell(
              onTap: () => onSelect(i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: index == i ? FontWeight.w600 : FontWeight.w400,
                      color: index == i ? _ink : _muted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 26,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: index == i ? _pink : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
