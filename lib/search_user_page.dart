import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'profile_store.dart';
import 'res_image.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);
const Color _pink = Color(0xFFFF4F8B);

/// Cari user terdaftar lewat ID, lalu buka profil orang tersebut.
class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final TextEditingController _id = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String q = _id.text.trim();
    if (q.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _result = null;
    });
    Map<String, dynamic>? found;
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
          .instance
          .collection('users')
          .where('publicId', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        found = snap.docs.first.data();
      }
    } catch (_) {
      found = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _result = found;
    });
  }

  void _open(Map<String, dynamic> profile) {
    final String? me = FirebaseAuth.instance.currentUser?.uid;
    final bool own = profile['uid'] == me;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(profile: profile, isOwn: own),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _ink, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cari user',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _id,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: _ink, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Masukkan ID user',
                    hintStyle: const TextStyle(color: _muted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: _muted, size: 22),
                    filled: true,
                    fillColor: const Color(0xFFF4F4F8),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _search,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _pink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(color: _pink),
              ),
            )
          else if (_result != null)
            _userCard(_result!)
          else if (_searched)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: <Widget>[
                  ResImage('empty_empty_search', width: 200, height: 200),
                  SizedBox(height: 10),
                  Text(
                    'User tidak ditemukan',
                    style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Periksa lagi ID-nya. ID ada di halaman profil user.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: <Widget>[
                  ResImage('empty_empty_people', width: 200, height: 200),
                  SizedBox(height: 10),
                  Text(
                    'Cari teman lewat ID',
                    style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ketik ID user lalu tekan tombol cari.',
                    style: TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> p) {
    final String name = (p['displayName'] as String?)?.isNotEmpty == true
        ? p['displayName'] as String
        : 'Yanko User';
    final String gender = (p['gender'] as String?) ?? 'male';
    final bool male = gender != 'female';
    final String? photo = p['photoUrl'] as String?;
    final int age = ProfileStore.ageFromBirth((p['birthDate'] as String?) ?? '');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _open(p),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            ClipOval(
              child: SizedBox(
                width: 58,
                height: 58,
                child: photo != null
                    ? Image.network(photo, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover))
                    : ResImage(male ? 'demo_m1' : 'demo_f1', fit: BoxFit.cover),
              ),
            ),
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
                      color: _ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID ${p['publicId'] ?? '-'}  ·  $age th',
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }
}
