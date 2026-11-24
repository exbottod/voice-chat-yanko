import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edit_profile_page.dart';
import 'profile_store.dart';
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
    final double top = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          SizedBox(
            height: top,
            width: double.infinity,
            child: photo != null
                ? Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover),
                  )
                : ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: <Widget>[
                  _RoundBtn(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
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
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: top - 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: <Widget>[
                  Transform.translate(
                    offset: const Offset(0, -34),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: const Color(0xFFE8F1FB),
                          ),
                          child: ClipOval(
                            child: photo != null
                                ? Image.network(
                                    photo,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => ResImage(
                                      male ? 'demo_m1' : 'demo_f1',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-26, -4),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _pink.withValues(alpha: 0.45),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.add, color: _pink, size: 30),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 18, left: 0),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: male
                                ? const Color(0xFF4C8DF6)
                                : const Color(0xFFFF6FA5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                male ? Icons.male : Icons.female,
                                size: 14,
                                color: Colors.white,
                              ),
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
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Text(
                              'ID:$pid',
                              style: const TextStyle(fontSize: 13, color: _muted),
                            ),
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
                              child: const Icon(
                                Icons.copy_outlined,
                                size: 16,
                                color: _muted,
                              ),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: <Widget>[
                            for (int i = 0; i < _tabs.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(right: 26),
                                child: InkWell(
                                  onTap: () => setState(() => _tab = i),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        _tabs[i],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: _tab == i
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: _tab == i
                                              ? _ink
                                              : _muted.withValues(alpha: 0.65),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        width: 26,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          color: _tab == i
                                              ? _pink
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _tabBody(),
                      ],
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

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.child, required this.onTap, this.wide = false});

  final Widget child;
  final VoidCallback onTap;
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
