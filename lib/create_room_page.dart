import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'res_image.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);
const Color _pink = Color(0xFFFF4F8B);

/// Form buat room baru. Room disimpan di Firestore: rooms/{autoId}
class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _topic = TextEditingController();
  String _category = 'Ngobrol';
  bool _saving = false;

  static const List<String> _categories = <String>[
    'Ngobrol',
    'Musik',
    'Game',
    'Kencan',
    'Cerita',
  ];

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final String name = _name.text.trim();
    if (name.length < 3) {
      _toast('Nama room minimal 3 huruf');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('rooms').add(<String, dynamic>{
        'title': name,
        'topic': _topic.text.trim(),
        'category': _category,
        'ownerId': user.uid,
        'ownerName': user.displayName ?? '',
        'listeners': 0,
        'coverAsset': 'demo_room_bg_1',
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Gagal membuat room. Coba lagi.');
      }
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          'Buat room',
          style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: const ResImage('demo_room_bg_1', height: 150, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          const Text('Nama room', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _field(_name, 'Contoh: Ngobrol sore', 24),
          const SizedBox(height: 18),
          const Text('Topik (opsional)', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _field(_topic, 'Mau ngobrolin apa?', 40),
          const SizedBox(height: 18),
          const Text('Kategori', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String c in _categories)
                GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: _category == c ? _pink.withValues(alpha: 0.12) : const Color(0xFFF4F4F8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _category == c ? _pink : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _category == c ? _pink : _muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                    )
                  : const Text('Buat room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Room akan tampil di tab Party untuk semua pengguna.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, int max) {
    return TextField(
      controller: c,
      maxLength: max,
      style: const TextStyle(color: _ink, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: hint,
        counterStyle: const TextStyle(color: _muted, fontSize: 11),
        filled: true,
        fillColor: const Color(0xFFF4F4F8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
