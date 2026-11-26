import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'auth_service.dart';
import 'create_profile_page.dart';
import 'profile_store.dart';
import 'app_shell.dart';
import 'legal_page.dart';
import 'main.dart' show HomePage;
import 'register_page.dart';

const Color kBrand = Color(0xFF8B5CF6);
const Color kBrandLight = Color(0xFFA855F7);
const Color kInk = Color(0xFF111318);

/// Nama merek dan maskot yang tampil di halaman login.
const String kBrandName = 'AuraVox';
const String kMascotAsset = 'assets/mascot.png';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _agreed = false;
  bool _loading = false;

  void _openRooms() {
    if (!_agreed) {
      _snack('Centang persetujuan Terms of Service dulu ya');
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  Future<void> _googleLogin() async {
    if (!_agreed) {
      _snack('Centang persetujuan Terms of Service dulu ya');
      return;
    }
    setState(() => _loading = true);
    try {
      final UserCredential cred = await AuthService.signInWithGoogle();
      final User? user = cred.user;
      if (!mounted || user == null) {
        return;
      }
      final bool complete = await ProfileStore.isComplete(user);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              complete ? const AppShell() : const CreateProfilePage(),
        ),
      );
    } on AuthCancelledException {
      _snack('Login dibatalkan');
    } on FirebaseAuthException catch (error) {
      _snack('Gagal login: ${error.code}');
    } catch (error) {
      _snack('Gagal login Google: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openLegal(String title, String asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, asset: asset),
      ),
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
                    _GoogleButton(onTap: _googleLogin, loading: _loading),
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
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: Colors.black54,
                                ),
                                children: <TextSpan>[
                                  const TextSpan(
                                    text: 'By continuing , you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: const TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _openLegal(
                                            'Terms of Service',
                                            'assets/legal/terms_of_service.md',
                                          ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _openLegal(
                                            'Privacy Policy',
                                            'assets/legal/privacy_policy.md',
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
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: kBrand.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          kMascotAsset,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext c, Object e, StackTrace? st) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF8B5CF6), Color(0xFF3A0CA3)],
              ),
            ),
            child: const Icon(Icons.graphic_eq, size: 62, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap, this.loading = false});

  final VoidCallback onTap;
  final bool loading;

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
            onTap: loading ? null : onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
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
                Text(
                  loading ? 'Memproses...' : 'Google Login',
                  style: const TextStyle(
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
