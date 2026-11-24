import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'app_shell.dart';
import 'login_page.dart' show LoginPage;
import 'profile_store.dart';

const Color _pink = Color(0xFFFF4F8B);
const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _birth = TextEditingController();
  final TextEditingController _invite = TextEditingController();
  final TextEditingController _agency = TextEditingController();

  String _gender = 'female';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    final String? name = user?.displayName;
    if (name != null && name.isNotEmpty) {
      _name.text = name;
    }
    _name.addListener(_refresh);
    _birth.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _birth.dispose();
    _invite.dispose();
    _agency.dispose();
    super.dispose();
  }

  bool get _valid {
    return _name.text.trim().length >= 2 && _parseBirth(_birth.text) != null;
  }

  DateTime? _parseBirth(String raw) {
    final RegExpMatch? m =
        RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(raw.trim());
    if (m == null) {
      return null;
    }
    final int d = int.parse(m.group(1)!);
    final int mo = int.parse(m.group(2)!);
    final int y = int.parse(m.group(3)!);
    final DateTime date = DateTime(y, mo, d);
    if (date.day != d || date.month != mo || date.year != y) {
      return null;
    }
    final DateTime now = DateTime.now();
    int age = now.year - y;
    if (now.month < mo || (now.month == mo && now.day < d)) {
      age--;
    }
    return age >= 17 && age <= 100 ? date : null;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 17, now.month, now.day),
      helpText: 'Tanggal lahir',
    );
    if (picked != null) {
      final String d = picked.day.toString().padLeft(2, '0');
      final String m = picked.month.toString().padLeft(2, '0');
      _birth.text = '$d.$m.${picked.year}';
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !_valid || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ProfileStore.save(
        user: user,
        displayName: _name.text.trim(),
        gender: _gender,
        birthDate: _birth.text.trim(),
        inviteCode: _invite.text.trim(),
        agencyCode: _agency.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AppShell(initialIndex: 4)),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      _snack('Gagal menyimpan profil: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? photo = user?.photoURL;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFFFE3EC), Color(0xFFFFF6EE), Colors.white],
            stops: <double>[0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Buat profilmu',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Beberapa detail agar kami bisa mengenalmu',
                  style: TextStyle(fontSize: 15, color: _muted),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _pink.withValues(alpha: 0.45),
                            width: 2,
                          ),
                          image: photo == null
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(photo),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: photo == null
                            ? const Icon(Icons.photo_camera, size: 40, color: _pink)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tambah foto',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _pink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const _Label('Nama panggilan'),
                _Input(
                  controller: _name,
                  hint: 'Kami harus memanggilmu apa?',
                ),
                const SizedBox(height: 22),
                const _Label('Gender'),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _GenderChip(
                        label: 'Wanita',
                        icon: Icons.female,
                        selected: _gender == 'female',
                        onTap: () => setState(() => _gender = 'female'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderChip(
                        label: 'Pria',
                        icon: Icons.male,
                        selected: _gender == 'male',
                        onTap: () => setState(() => _gender = 'male'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gender dan tanggal lahir tidak dapat diubah nanti.',
                  style: TextStyle(fontSize: 12.5, color: _muted),
                ),
                const SizedBox(height: 22),
                const _Label('Tanggal lahir'),
                _Input(
                  controller: _birth,
                  hint: 'DD.MM.YYYY',
                  keyboardType: TextInputType.datetime,
                  onTap: _pickDate,
                  readOnly: true,
                ),
                const SizedBox(height: 22),
                const _Label('Kode undangan (opsional)'),
                _Input(controller: _invite, hint: 'Kode 8 digit temanmu'),
                const SizedBox(height: 8),
                const Text(
                  'Jika temanmu mengundangmu, masukkan kodenya; setelah kamu '
                  'melengkapi profil dan masuk selama 2 hari, kalian berdua dapat koin.',
                  style: TextStyle(fontSize: 12.5, color: _muted, height: 1.45),
                ),
                const SizedBox(height: 22),
                const _Label('Kode agensi (opsional)'),
                _Input(controller: _agency, hint: ''),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: LinearGradient(
                        colors: <Color>[
                          const Color(0xFFFF8FB4).withValues(alpha: _valid ? 1 : 0.55),
                          const Color(0xFFFFC8A5).withValues(alpha: _valid ? 1 : 0.55),
                        ],
                      ),
                    ),
                    child: TextButton(
                      onPressed: _valid && !_saving ? _submit : null,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Mulai',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _logout,
                    child: const Text(
                      'Keluar',
                      style: TextStyle(fontSize: 16, color: _muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        style: const TextStyle(fontSize: 16, color: _ink),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onTap,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 17, color: _ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 17, color: Color(0xFFB4B1C7)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFEFEDF6), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _pink, width: 1.5),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? _pink : const Color(0xFFEFEDF6),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 28, color: selected ? _pink : _muted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: selected ? _pink : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
