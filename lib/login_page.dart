import 'package:flutter/material.dart';

import 'main.dart' show HomePage;
import 'register_page.dart';

const Color kBrand = Color(0xFF8B5CF6);
const Color kBrandLight = Color(0xFFA855F7);
const Color kInk = Color(0xFF111318);

/// Ganti dua nilai ini saat logo/maskot YAHLLA yang asli sudah siap.
const String kBrandName = 'YAHLLA';
const String kMascotAsset = 'assets/mascot.png';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _agreed = false;

  void _openRooms() {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centang persetujuan Terms of Service dulu ya'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            const Positioned(
              left: 22,
              top: 18,
              child: _DecorIcon(
                icon: Icons.sports_esports,
                color: kBrand,
              ),
            ),
            const Positioned(
              right: 22,
              top: 18,
              child: _DecorIcon(
                icon: Icons.music_note,
                color: Color(0xFF3B82F6),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const _Mascot(),
                    const SizedBox(height: 18),
                    const Text(
                      kBrandName,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 42),
                    _GoogleButton(onTap: _openRooms),
                    const SizedBox(height: 20),
                    const Text(
                      'or',
                      style: TextStyle(fontSize: 13, color: Colors.black45),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _RoundButton(
                          icon: Icons.person_outline,
                          onTap: _openRooms,
                        ),
                        const SizedBox(width: 18),
                        _RoundButton(
                          icon: Icons.smartphone_outlined,
                          onTap: _openRegister,
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
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
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: Colors.black54,
                                ),
                                children: <TextSpan>[
                                  TextSpan(text: 'By continuing , you agree to our '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorIcon extends StatelessWidget {
  const _DecorIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.15,
      child: Icon(icon, size: 30, color: color),
    );
  }
}

class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 150,
            height: 130,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFBFD9FF), Color(0xFFF3C4E8)],
              ),
              borderRadius: BorderRadius.circular(70),
            ),
            child: const Icon(
              Icons.pets,
              size: 58,
              color: Colors.white,
            ),
          ),
          const Positioned(
            left: 16,
            top: 34,
            child: Icon(Icons.favorite, size: 22, color: Color(0xFFF472B6)),
          ),
          const Positioned(
            right: 20,
            bottom: 26,
            child: Icon(
              Icons.card_giftcard,
              size: 26,
              color: Color(0xFFA855F7),
            ),
          ),
          Positioned(
            right: 34,
            top: 12,
            child: Transform.rotate(
              angle: 0.2,
              child: const Icon(
                Icons.workspace_premium,
                size: 26,
                color: Color(0xFFFBBF24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[kBrand, kBrandLight],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Google Login',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Icon(icon, size: 24, color: kInk),
      ),
    );
  }
}
