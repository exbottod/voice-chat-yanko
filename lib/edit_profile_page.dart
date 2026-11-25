import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'avatar_image.dart';
import 'profile_store.dart';
import 'res_image.dart';

const Color _pink = Color(0xFFFF4D8D);
const Color _ink = Color(0xFF16151A);
const Color _muted = Color(0xFF9A97A6);
const Color _line = Color(0xFFEDECF2);
const Color _fill = Color(0xFFF4F3F8);

/// Info dasar: kelengkapan profil, nama, tinggi, pekerjaan, kota, bio, album.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _job;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _newPhoto;
  bool _photoChanged = false;

  String _s(String key) => (widget.profile[key] as String?) ?? '';

  String get _photo => _newPhoto ?? _s('photoUrl');

  /// Buka galeri, pilih foto (jpg/png/webp/gif) lalu simpan ke profil.
  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final PickedAvatar? picked = await AvatarPicker.pick(context);
      if (picked == null) {
        if (mounted) setState(() => _uploadingPhoto = false);
        return;
      }
      await ProfileStore.updatePhoto(user, picked.dataUrl);
      if (!mounted) return;
      setState(() {
        _newPhoto = picked.dataUrl;
        _photoChanged = true;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(picked.animated
              ? 'Foto profil animasi diperbarui'
              : 'Foto profil diperbarui'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is String ? error : 'Gagal mengunggah foto')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    _name = TextEditingController(
      text: _s('displayName').isNotEmpty
          ? _s('displayName')
          : (user?.displayName ?? ''),
    );
    _height = TextEditingController(text: _s('height'));
    _job = TextEditingController(text: _s('job'));
    _city = TextEditingController(text: _s('city'));
    _bio = TextEditingController(text: _s('bio'));
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _job.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  double get _completeness {
    int done = 0;
    if (_photo.isNotEmpty) done++;
    if (_bio.text.trim().isNotEmpty) done++;
    return done / 6;
  }

  Future<void> _save() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await ProfileStore.updateDetails(
        user: user,
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        job: _job.text.trim(),
        city: _city.text.trim(),
        height: _height.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool male = _s('gender') != 'female';
    final String birth = _s('birthDate');
    final String lockText =
        '${birth.isEmpty ? '-' : birth} · ${male ? 'Pria' : 'Wanita'}';
    final int pct = (_completeness * 100).round();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.of(context).pop(_photoChanged);
        }
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: _ink),
          onPressed: () => Navigator.of(context).pop(_photoChanged),
        ),
        title: const Text(
          'Info dasar',
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '...' : 'Simpan',
              style: const TextStyle(
                color: _pink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Kelengkapan profil',
                style: TextStyle(color: _ink, fontSize: 16),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: _pink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _completeness < 0.04 ? 0.04 : _completeness,
              minHeight: 8,
              backgroundColor: const Color(0xFFFFDCE8),
              valueColor: const AlwaysStoppedAnimation<Color>(_pink),
            ),
          ),
          const SizedBox(height: 10),
          ...<String>[
            'Foto profil',
            '3 foto album',
            'Tentang saya',
            'Perkenalan suara',
            'Foto unggulan',
            'Verifikasi orang asli',
          ].map(
            (String t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 22,
                    color: Color(0xFFBDBBC8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t, style: const TextStyle(color: _ink, fontSize: 15)),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBDBBC8)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFC53D),
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
                const SizedBox(width: 8),
                const Text(
                  'Lengkapi untuk mendapat 100 koin',
                  style: TextStyle(color: Color(0xFFB07A00), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: <Widget>[
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8F1FB),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _photo.isNotEmpty
                            ? AvatarImage(
                                source: _photo,
                                fallback: ResImage(
                                    male ? 'demo_m1' : 'demo_f1',
                                    fit: BoxFit.cover),
                              )
                            : ResImage(male ? 'demo_m1' : 'demo_f1',
                                fit: BoxFit.cover),
                        if (_uploadingPhoto)
                          Container(
                            color: Colors.black38,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _pink, width: 1.6),
                      ),
                      child: const Icon(Icons.edit, size: 15, color: _pink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const _Label('Info dasar'),
          _Box(
            controller: _name,
            hint: 'Nama',
            maxLength: 20,
            center: true,
            counter: true,
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(lockText, style: const TextStyle(color: _muted, fontSize: 15)),
                const SizedBox(width: 10),
                const Icon(Icons.lock, size: 17, color: Color(0xFFBDBBC8)),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _Box(
                  controller: _height,
                  hint: 'Tinggi (cm)',
                  keyboard: TextInputType.number,
                  center: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Box(
                  controller: TextEditingController(),
                  hint: '',
                  center: true,
                ),
              ),
            ],
          ),
          _Box(
            controller: _job,
            hint: 'Pekerjaan',
            maxLength: 20,
            center: true,
            counter: true,
          ),
          _Box(
            controller: _city,
            hint: 'Negara / kota',
            maxLength: 40,
            center: true,
            counter: true,
          ),
          const SizedBox(height: 14),
          const _Label('Bio'),
          _Box(
            controller: _bio,
            hint: 'Ceritakan sedikit tentang dirimu',
            maxLength: 140,
            maxLines: 5,
            center: true,
            counter: true,
          ),
          const SizedBox(height: 14),
          const _Label('Perkenalan suara'),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Center(
                    child: Text('Tambah', style: TextStyle(color: _muted, fontSize: 15)),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB020),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, size: 24, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _Label('Album profil'),
          const Text(
            'Terlihat oleh semua orang.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const _AddPhoto(),
          const SizedBox(height: 26),
          const _Label('Album pribadi'),
          const Text(
            'Terlihat oleh orang dengan level keakraban 10 atau lebih tinggi.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const _AddPhoto(),
        ],
      ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.center = false,
    this.counter = false,
    this.keyboard,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final bool center;
  final bool counter;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboard,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontSize: 15, color: _ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB9B6C6), fontSize: 15),
          filled: true,
          fillColor: _fill,
          counterText: counter ? null : '',
          counterStyle: const TextStyle(color: Color(0xFFB9B6C6), fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _AddPhoto extends StatelessWidget {
  const _AddPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9DBB), width: 1.4),
      ),
      child: const Icon(Icons.add, size: 30, color: _pink),
    );
  }
}
