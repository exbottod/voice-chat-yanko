import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'login_page.dart' show kBrand, kInk;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      _snack('Nama dan nomor HP wajib diisi');
      return;
    }
    if (!_agreed) {
      _snack('Centang persetujuan Terms of Service dulu ya');
      return;
    }
    _snack('Kode verifikasi dikirim ke ${_phone.text.trim()}');
    Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kInk,
        title: const Text(
          'Daftar akun',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Buat akun baru',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Isi nama dan nomor HP untuk mulai ngobrol di voice room.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 28),
            _Field(
              controller: _name,
              label: 'Nama',
              hint: 'Nama kamu',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _phone,
              label: 'Nomor HP',
              hint: '08xxxxxxxxxx',
              icon: Icons.smartphone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Checkbox(
                    value: _agreed,
                    activeColor: kBrand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (bool? value) {
                      setState(() => _agreed = value ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'Saya setuju dengan Terms of Service dan Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Daftar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.black45),
            filled: true,
            fillColor: const Color(0xFFF6F6F8),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
