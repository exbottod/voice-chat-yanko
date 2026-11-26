import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'profile_store.dart';
import 'res_image.dart';

const Color _violet = Color(0xFF8B5CF6);
const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF9A97B0);
const Color _soft = Color(0xFFF5F2FF);
const Color _pinkSoft = Color(0xFFFFEEF3);

/// Layar Undang teman: kode undangan = ID publik user.
class InvitePage extends StatefulWidget {
  const InvitePage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final TextEditingController _code = TextEditingController();
  bool _sending = false;
  List<Map<String, dynamic>> _invited = <Map<String, dynamic>>[];

  String get _myCode {
    final String? pid = widget.profile['publicId'] as String?;
    if (pid != null && pid.isNotEmpty) return pid;
    return ProfileStore.publicId(FirebaseAuth.instance.currentUser?.uid ?? '0');
  }

  @override
  void initState() {
    super.initState();
    _loadInvited();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadInvited() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore.instance
          .collection('users')
          .where('inviteCode', isEqualTo: _myCode)
          .limit(30)
          .get();
      if (!mounted) return;
      setState(() {
        _invited = q.docs.map((d) => d.data()).toList();
      });
    } catch (_) {}
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _myCode));
    _toast('Kode disalin');
  }

  Future<void> _share() async {
    await Share.share(
      'Gabung ke AuraVox! Masukkan kode undanganku: $_myCode\n'
      'Unduh: https://auravox-chat.web.app/download',
    );
  }

  Future<void> _submit() async {
    final String code = _code.text.trim();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (code.length != 8) {
      _toast('Kode undangan harus 8 digit');
      return;
    }
    if (code == _myCode) {
      _toast('Kamu tidak bisa memakai kodemu sendiri');
      return;
    }
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{'inviteCode': code},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      _code.clear();
      _toast('Kode terkirim');
    } catch (error) {
      if (mounted) _toast('Gagal: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String spaced = _myCode.split('').join(' ');
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFFA),
      body: Stack(
        children: <Widget>[
          Container(
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFFF6FA8), Color(0xFF9B5CF6)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 48,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Undang teman',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Undang teman, untung bersama',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Ajak teman-temanmu ke AuraVox dan kumpulkan reward bersama.',
                                    style: TextStyle(
                                      color: Color(0xE6FFFFFF),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 118,
                              height: 118,
                              decoration: const BoxDecoration(
                                color: Color(0x33FFFFFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: ResImage('tasks_daily_gift', fit: BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3EFFA),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                        child: Column(
                          children: <Widget>[
                            _card(
                              child: Column(
                                children: <Widget>[
                                  const Text(
                                    'Kode undanganmu',
                                    style: TextStyle(color: _muted, fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    decoration: BoxDecoration(
                                      color: _soft,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: const Color(0xFFC9B6F7),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Text(
                                          spaced,
                                          style: const TextStyle(
                                            color: _violet,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: _copy,
                                          child: const Icon(
                                            Icons.copy_rounded,
                                            color: _violet,
                                            size: 22,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        flex: 11,
                                        child: _GradBtn(
                                          label: 'Bagikan',
                                          icon: Icons.share,
                                          onTap: _share,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 10,
                                        child: _SoftBtn(
                                          label: 'Salin kode',
                                          icon: Icons.copy,
                                          onTap: _copy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Cara kerjanya',
                                    style: TextStyle(color: _ink, fontSize: 15),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const <Widget>[
                                      Expanded(
                                        child: _Step(
                                          n: '1',
                                          color: Color(0xFFFF6FA8),
                                          bg: _pinkSoft,
                                          icon: Icons.share,
                                          label: 'Bagikan kodemu',
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(top: 26),
                                        child: Icon(Icons.chevron_right, color: _muted, size: 18),
                                      ),
                                      Expanded(
                                        child: _Step(
                                          n: '2',
                                          color: Color(0xFF9B5CF6),
                                          bg: _soft,
                                          icon: Icons.edit_note,
                                          label: 'Temanmu memasukkannya',
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(top: 26),
                                        child: Icon(Icons.chevron_right, color: _muted, size: 18),
                                      ),
                                      Expanded(
                                        child: _Step(
                                          n: '3',
                                          color: Color(0xFFF0A21B),
                                          bg: Color(0xFFFFF3DE),
                                          icon: Icons.card_giftcard,
                                          label: 'Reward setelah 2 hari aktif',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Temanmu memasukkan kodemu saat mendaftar, atau dalam 7 hari setelahnya, lewat Saya › Undang teman.',
                                    style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Reward',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _RewardBox(
                                          title: 'Kamu',
                                          value: '+200',
                                          bg: _pinkSoft,
                                          note: null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _RewardBox(
                                          title: 'Temanmu',
                                          value: '+100',
                                          bg: _soft,
                                          note: 'wanita mendapat 800',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F4F8),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        _Stat(value: '0', label: 'Total diperoleh'),
                                        const _VDivider(),
                                        _Stat(value: '${_invited.length}', label: 'Diundang'),
                                        const _VDivider(),
                                        _Stat(
                                          value: '${_invited.length}/30',
                                          label: 'Batas bulanan',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _invited.length / 30,
                                      minHeight: 5,
                                      backgroundColor: const Color(0xFFE9DDFB),
                                      valueColor: const AlwaysStoppedAnimation<Color>(_violet),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Kamu bisa mendapat reward untuk maksimal 30 undangan per bulan. Kamu tidak bisa memakai kodemu sendiri; reward dari akun palsu atau ganda akan ditarik kembali.',
                                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Punya kode undangan?',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Masukkan kode 8 digit temanmu dan kalian berdua akan mendapat reward.',
                                    style: TextStyle(color: _muted, fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: TextField(
                                          controller: _code,
                                          keyboardType: TextInputType.number,
                                          maxLength: 8,
                                          decoration: InputDecoration(
                                            hintText: 'Kode undangan',
                                            counterText: '',
                                            filled: true,
                                            fillColor: const Color(0xFFF4F4F8),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 15,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(26),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 74,
                                        height: 48,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: <Color>[
                                                Color(0xFFFFA2C4),
                                                Color(0xFFFFC7A8),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: TextButton(
                                            onPressed: _sending ? null : _submit,
                                            child: const Text(
                                              'Kirim',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _card(
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Expanded(
                                        child: Text(
                                          'Orang yang kamu undang',
                                          style: TextStyle(
                                            color: _ink,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _soft,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_invited.length}',
                                          style: const TextStyle(color: _violet, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  if (_invited.isEmpty) ...<Widget>[
                                    const Icon(Icons.people_outline, size: 54, color: Color(0xFFC9C6D8)),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Belum ada yang bergabung dengan kodemu. Bagikan untuk memulai!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 10),
                                  ] else
                                    for (final Map<String, dynamic> u in _invited)
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const CircleAvatar(
                                          backgroundColor: _soft,
                                          child: Icon(Icons.person, color: _violet),
                                        ),
                                        title: Text(
                                          (u['displayName'] as String?) ?? 'Pengguna',
                                          style: const TextStyle(color: _ink, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          'ID ${(u['publicId'] as String?) ?? '-'}',
                                          style: const TextStyle(color: _muted, fontSize: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _GradBtn extends StatelessWidget {
  const _GradBtn({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFF6FA8), Color(0xFF9B5CF6)],
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _SoftBtn extends StatelessWidget {
  const _SoftBtn({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFEFE8FD),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: _violet, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: _violet, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.color,
    required this.bg,
    required this.icon,
    required this.label,
  });

  final String n;
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          width: 66,
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    n,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontSize: 12.5, height: 1.3),
        ),
      ],
    );
  }
}

class _RewardBox extends StatelessWidget {
  const _RewardBox({
    required this.title,
    required this.value,
    required this.bg,
    required this.note,
  });

  final String title;
  final String value;
  final Color bg;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: <Widget>[
          Text(title, style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB020),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Y',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(note!, style: const TextStyle(color: _muted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value, style: const TextStyle(color: _ink, fontSize: 17)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: const Color(0xFFE0DEEA));
  }
}
