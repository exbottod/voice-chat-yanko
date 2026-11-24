import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'res_image.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF9A97B0);
const Color _pink = Color(0xFFFF4F8B);
const Color _bg = Color(0xFFF6F5FA);

/// Satu kategori di Toko barang.
class StoreCategory {
  const StoreCategory(this.key, this.label, this.icon);

  final String key;
  final String label;
  final String icon;
}

const List<StoreCategory> kStoreCategories = <StoreCategory>[
  StoreCategory('frame', 'Bingkai', 'store_cat_frame'),
  StoreCategory('enter', 'Efek masuk', 'store_cat_entry'),
  StoreCategory('bubble', 'Gelembung chat', 'store_cat_bubble'),
  StoreCategory('name_effect', 'Efek nama', 'store_cat_tools'),
  StoreCategory('id_effect', 'Efek ID', 'store_cat_tools'),
  StoreCategory('unique_id', 'ID unik', 'store_cat_items'),
  StoreCategory('profile_card', 'Kartu profil', 'store_cat_card'),
];

/// Toko barang: semua tab sengaja kosong sampai item diunggah lewat panel
/// developer (koleksi Firestore `store_items` dengan field `category`).
class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int _cat = 0;
  int _sub = 0;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final StoreCategory cat = kStoreCategories[_cat];

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
          'Toko barang',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyItemsPage()),
            ),
            child: const Text(
              'Barangku',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: kStoreCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (BuildContext context, int i) {
                  final StoreCategory c = kStoreCategories[i];
                  final bool on = i == _cat;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 74,
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: on
                                  ? const Color(0xFFFFF0F5)
                                  : const Color(0xFFF3F2F7),
                              border: Border.all(
                                color: on ? _pink : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: ResImage(c.icon, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: on ? _ink : _muted,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: <Widget>[
                _SubTab(
                  label: 'Beli dengan koin',
                  active: _sub == 0,
                  onTap: () => setState(() => _sub = 0),
                ),
                const SizedBox(width: 18),
                _SubTab(
                  label: 'Khusus VIP',
                  active: _sub == 1,
                  onTap: () => setState(() => _sub = 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _ItemGrid(
              category: cat.key,
              vipOnly: _sub == 1,
            ),
          ),
          _FooterBar(user: user),
        ],
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: active ? _ink : _muted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: active ? 54 : 0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF7B5CFA), _pink, Color(0xFFFFB74D)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid item. Selama panel developer belum mengunggah apa pun, daftar kosong
/// dan yang tampil hanya keterangan kosong.
class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.category, required this.vipOnly});

  final String category;
  final bool vipOnly;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('store_items')
          .where('category', isEqualTo: category)
          .where('vipOnly', isEqualTo: vipOnly)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
      ) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return const _EmptyStore();
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: docs.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> d = docs[i].data();
            return _ItemCard(data: d);
          },
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String name = (data['name'] as String?) ?? 'Item';
    final String rarity = (data['rarity'] as String?) ?? 'Umum';
    final int price = (data['price'] as int?) ?? 0;
    final int days = (data['days'] as int?) ?? 7;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Center(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
          ),
          Text(
            rarity,
            style: const TextStyle(fontSize: 10, color: _muted),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const Icon(Icons.monetization_on, size: 13, color: _pink),
              const SizedBox(width: 3),
              Text(
                '$price',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Text(
                '$days hari',
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyStore extends StatelessWidget {
  const _EmptyStore();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 150,
              height: 138,
              child: const ResImage('empty_empty_items', fit: BoxFit.contain),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum ada barang',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Barang akan muncul di sini setelah ditambahkan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barang yang sudah dimiliki user. Juga kosong sampai ada pembelian.
class MyItemsPage extends StatelessWidget {
  const MyItemsPage({super.key});

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
          'Barangku',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        centerTitle: true,
      ),
      body: const _EmptyStore(),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDECF3))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            const Icon(Icons.monetization_on, size: 20, color: _pink),
            const SizedBox(width: 6),
            const Text(
              '30',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Isi ulang koin belum tersedia')),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Isi ulang',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
