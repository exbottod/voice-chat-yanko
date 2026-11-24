import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _bg = Color(0xFFF7F6FB);
const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);
const Color _pink = Color(0xFFFF4F8B);

/// Koleksi milik user: bingkai avatar, lencana, gelembung chat, efek masuk.
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  static const List<String> _labels = <String>[
    'Bingkai',
    'Lencana',
    'Gelembung',
    'Efek',
  ];

  static const List<String> _keys = <String>[
    'frame',
    'badge',
    'bubble',
    'effect',
  ];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Koleksi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: _pink,
          unselectedLabelColor: _muted,
          indicatorColor: _pink,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: <Widget>[for (final String l in _labels) Tab(text: l)],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
          final List<dynamic> all =
              (snap.data?.data()?['collection'] as List<dynamic>?) ?? <dynamic>[];
          return TabBarView(
            controller: _tabs,
            children: <Widget>[
              for (final String key in _keys)
                _grid(
                  all
                      .where((dynamic e) => (e is Map) && (e['type'] as String?) == key)
                      .map((dynamic e) => Map<String, dynamic>.from(e as Map))
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _grid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, color: _pink, size: 34),
              ),
              const SizedBox(height: 14),
              const Text(
                'Belum ada koleksi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Koleksi yang kamu beli atau terima akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _muted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext ctx, int i) {
        final Map<String, dynamic> it = items[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F0FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome, color: _pink, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (it['name'] as String?) ?? 'Koleksi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _ink),
              ),
            ],
          ),
        );
      },
    );
  }
}
