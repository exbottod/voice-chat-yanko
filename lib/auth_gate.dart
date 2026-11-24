import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_profile_page.dart';
import 'app_shell.dart';
import 'login_page.dart';
import 'profile_store.dart';

/// Menentukan layar awal: login, buat profil, atau beranda.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolve() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const LoginPage();
      }
      final bool complete = await ProfileStore.isComplete(user);
      return complete ? const AppShell() : const CreateProfilePage();
    } catch (_) {
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolve(),
      builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4F8B)),
            ),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
