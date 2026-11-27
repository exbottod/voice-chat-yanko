import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'avatar_image.dart';
import 'svga_view.dart';
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
            childAspectRatio: 0.80,
          ),
          itemCount: docs.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> d = docs[i].data();
            return _ItemCard(id: docs[i].id, data: d);
          },
        );
      },
    );
  }
}

/// Muat potongan media besar (gif/webp/mp4 yang dipecah di panel) dari
/// koleksi `svip_assets_media`, lalu susun jadi data URL.
Future<String?> _muatMedia(String assetId, String mime) async {
  try {
    final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore
        .instance
        .collection('svip_assets_media')
        .where('assetId', isEqualTo: assetId)
        .get();
    final List<Map<String, dynamic>> bagian =
        q.docs.map((d) => d.data()).toList()
          ..sort((a, b) =>
              ((a['i'] as num?) ?? 0).compareTo((b['i'] as num?) ?? 0));
    final String gabung = bagian.map((e) => (e['data'] as String?) ?? '').join();
    if (gabung.isEmpty) {
      return null;
    }
    return 'data:${mime.isEmpty ? 'image/webp' : mime};base64,$gabung';
  } catch (_) {
    return null;
  }
}

String _sumberGambar(Map<String, dynamic> d) {
  final String a = (d['url'] as String?) ?? '';
  if (a.isNotEmpty) {
    return a;
  }
  return (d['image'] as String?) ?? '';
}

/// Foto contoh pemakai: foto profil sendiri, atau siluet bila belum ada.
class _FotoSaya extends StatelessWidget {
  const _FotoSaya({required this.ukuran});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final User? u = FirebaseAuth.instance.currentUser;
    final Widget cadangan = Container(
      color: const Color(0xFFE6E3F2),
      child: Icon(Icons.person, size: ukuran * 0.62, color: Colors.white),
    );
    if (u == null) {
      return cadangan;
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .snapshots(),
      builder: (BuildContext c,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
        final String? foto = (snap.data?.data()?['photoUrl'] as String?) ??
            u.photoURL;
        return AvatarImage(source: foto, fallback: cadangan);
      },
    );
  }
}

/// Bingkai di atas foto. Bingkai dibuat sedikit lebih besar dari foto supaya
/// ornamen di tepinya tidak terpotong, sama seperti di ruang pesta.
class _BingkaiPratinjau extends StatelessWidget {
  const _BingkaiPratinjau({
    required this.data,
    required this.ukuran,
    this.src,
    this.id = '',
  });

  final Map<String, dynamic> data;
  final double ukuran;
  final String? src;
  final String id;

  @override
  Widget build(BuildContext context) {
    final String sumber = src ?? _sumberGambar(data);
    final bool bingkai = (data['category'] as String?) == 'frame';
    final bool animasi = asetSvga(data);
    final double foto = bingkai ? ukuran * 0.62 : ukuran * 0.78;

    final Widget gambar = animasi
        ? SvgaAnimasi(
            sumber: sumber,
            id: id,
            fit: BoxFit.contain,
            fallback: const SizedBox.shrink(),
          )
        : AvatarImage(
            source: sumber,
            fit: BoxFit.contain,
            width: ukuran,
            height: ukuran,
            fallback: const SizedBox.shrink(),
          );

    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (bingkai)
            ClipOval(
              child: SizedBox(
                width: foto,
                height: foto,
                child: const _FotoSaya(ukuran: 100),
              ),
            ),
          SizedBox(width: ukuran, height: ukuran, child: gambar),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String name =
        (data['name'] as String?) ?? (data['nama'] as String?) ?? 'Item';
    final String rarity = (data['rarity'] as String?) ?? 'Umum';
    final int price = ((data['price'] ?? data['harga']) as num?)?.toInt() ?? 0;
    final int days = (data['days'] as num?)?.toInt() ?? 7;

    return GestureDetector(
      onTap: () => _bukaPratinjau(context, id, data),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: LayoutBuilder(
                        builder: (BuildContext c, BoxConstraints k) {
                          final double u = k.biggest.shortestSide * 0.92;
                          return _BingkaiPratinjau(data: data, ukuran: u, id: id);
                        },
                      ),
                    ),
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.open_in_full,
                          size: 15, color: Color(0xFFB9B4CC)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              rarity,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const _KoinBulat(ukuran: 16),
                const SizedBox(width: 5),
                Text(
                  '$price',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$days hari',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KoinBulat extends StatelessWidget {
  const _KoinBulat({required this.ukuran});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFFFD54F), Color(0xFFFFA000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        'Y',
        style: TextStyle(
          fontSize: ukuran * 0.58,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

Future<void> _bukaPratinjau(
  BuildContext context,
  String id,
  Map<String, dynamic> data,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext c) => _LembarPratinjau(id: id, data: data),
  );
}

/// Lembar preview: bingkai besar di atas foto sendiri, pilihan masa aktif
/// (7 atau 30 hari), saldo, dan tombol Beli.
class _LembarPratinjau extends StatefulWidget {
  const _LembarPratinjau({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  @override
  State<_LembarPratinjau> createState() => _LembarPratinjauState();
}

class _LembarPratinjauState extends State<_LembarPratinjau> {
  int _pilih = 0;
  bool _sibuk = false;
  String? _besar;

  @override
  void initState() {
    super.initState();
    if (_sumberGambar(widget.data).isEmpty) {
      _muatMedia(widget.id, (widget.data['mime'] as String?) ?? '')
          .then((String? v) {
        if (mounted && v != null) {
          setState(() => _besar = v);
        }
      });
    }
  }

  int get _harga7 =>
      ((widget.data['price'] ?? widget.data['harga']) as num?)?.toInt() ?? 0;

  int get _harga30 {
    final int? h = (widget.data['price30'] as num?)?.toInt();
    if (h != null && h > 0) {
      return h;
    }
    return (_harga7 * 27 / 10).round();
  }

  int get _hari => _pilih == 0 ? 7 : 30;
  int get _bayar => _pilih == 0 ? _harga7 : _harga30;

  Future<void> _beli() async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null || _sibuk) {
      return;
    }
    setState(() => _sibuk = true);
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> me =
        db.collection('users').doc(u.uid);
    final DocumentReference<Map<String, dynamic>> milik =
        me.collection('inventory').doc(widget.id);
    final String nama = (widget.data['name'] as String?) ??
        (widget.data['nama'] as String?) ??
        'Item';
    try {
      await db.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> s = await tx.get(me);
        final DocumentSnapshot<Map<String, dynamic>> lama = await tx.get(milik);
        final int saldo = (s.data()?['coins'] as num?)?.toInt() ?? 0;
        if (saldo < _bayar) {
          throw StateError('Koin kamu tidak cukup');
        }
        final DateTime sekarang = DateTime.now();
        DateTime dasar = sekarang;
        final Object? akhirLama = lama.data()?['expiresAt'];
        if (akhirLama is Timestamp && akhirLama.toDate().isAfter(sekarang)) {
          dasar = akhirLama.toDate();
        }
        tx.set(me, <String, dynamic>{'coins': saldo - _bayar},
            SetOptions(merge: true));
        tx.set(milik, <String, dynamic>{
          'itemId': widget.id,
          'name': nama,
          'category': widget.data['category'],
          'image': _sumberGambar(widget.data),
          'mime': widget.data['mime'],
          'chunks': widget.data['chunks'],
          'days': _hari,
          'expiresAt': Timestamp.fromDate(dasar.add(Duration(days: _hari))),
          'boughtAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nama dibeli untuk $_hari hari')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _sibuk = false);
      final String pesan =
          e is StateError ? e.message : 'Pembelian gagal, coba lagi';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nama = (widget.data['name'] as String?) ??
        (widget.data['nama'] as String?) ??
        'Item';
    final User? u = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDAE8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: <Widget>[
                  LayoutBuilder(
                    builder: (BuildContext c, BoxConstraints k) {
                      final double ukuran = (k.maxWidth - 40).clamp(200.0, 300.0);
                      return _BingkaiPratinjau(
                        data: widget.data,
                        ukuran: ukuran,
                        src: _besar,
                        id: widget.id,
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _PilihHari(
                    hari: 7,
                    harga: _harga7,
                    aktif: _pilih == 0,
                    onTap: () => setState(() => _pilih = 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PilihHari(
                    hari: 30,
                    harga: _harga30,
                    aktif: _pilih == 1,
                    onTap: () => setState(() => _pilih = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                if (u == null)
                  const Text('Saldo: 0',
                      style: TextStyle(fontSize: 13, color: _muted))
                else
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(u.uid)
                        .snapshots(),
                    builder: (BuildContext c,
                        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> s) {
                      final int saldo =
                          (s.data?.data()?['coins'] as num?)?.toInt() ?? 0;
                      return Text('Saldo: $saldo',
                          style: const TextStyle(fontSize: 13, color: _muted));
                    },
                  ),
                const Spacer(),
                SizedBox(
                  height: 48,
                  width: 130,
                  child: ElevatedButton(
                    onPressed: _sibuk ? null : _beli,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      disabledBackgroundColor: const Color(0xFFFFB3CC),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _sibuk
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Beli',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PilihHari extends StatelessWidget {
  const _PilihHari({
    required this.hari,
    required this.harga,
    required this.aktif,
    required this.onTap,
  });

  final int hari;
  final int harga;
  final bool aktif;
  final VoidCallback onTap;

  String _titik(int n) {
    final String s = n.toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        b.write('.');
      }
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: aktif ? const Color(0xFFFFF0F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: aktif ? _pink : const Color(0xFFE6E4EE),
            width: aktif ? 2 : 1.2,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '$hari hari',
              style: TextStyle(
                fontSize: 14,
                color: aktif ? _pink : _ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const _KoinBulat(ukuran: 16),
                const SizedBox(width: 5),
                Text(
                  _titik(harga),
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ],
        ),
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

/// Kategori barang milik user. Dokumen lama bisa belum punya `category`,
/// jadi dianggap bingkai.
String _kategoriBarang(Map<String, dynamic> d) {
  final Object? k = d['category'];
  final String t = k is String ? k.trim() : '';
  return t.isEmpty ? 'frame' : t;
}

/// ID barang yang sedang dipakai untuk satu kategori.
String _aktifId(Map<String, dynamic>? me, String kategori) {
  final Object? e = me?['equipped'];
  if (e is Map) {
    final Object? f = e[kategori];
    if (f is Map) {
      return (f['itemId'] as String?) ?? '';
    }
  }
  return '';
}

/// Pasang barang: tulis ke `users/{uid}.equipped.<kategori>`.
Future<void> pasangBarang({
  required String uid,
  required String id,
  required Map<String, dynamic> data,
}) async {
  final String kategori = _kategoriBarang(data);
  final String nama = (data['name'] as String?) ??
      (data['nama'] as String?) ??
      'Item';
  // Data URL besar (mis. SVGA 1 MB) tidak boleh disalin ke dokumen user,
  // karena batas satu dokumen Firestore 1 MB dan penulisan akan gagal.
  String gambar = (data['image'] as String?) ?? '';
  if (gambar.length > 40000) {
    try {
      final QuerySnapshot<Map<String, dynamic>> potong = await FirebaseFirestore
          .instance
          .collection('svip_assets_media')
          .where('assetId', isEqualTo: id)
          .limit(1)
          .get();
      if (potong.docs.isNotEmpty) {
        gambar = '';
      }
    } catch (_) {
      /* biarkan */
    }
  }
  final DocumentReference<Map<String, dynamic>> dok =
      FirebaseFirestore.instance.collection('users').doc(uid);
  // HARUS bersarang: `set` tidak membaca titik sebagai jalur, jadi
  // 'equipped.frame' akan jadi nama kolom aneh dan bingkai tidak terbaca.
  await dok.set(
    <String, dynamic>{
      'equipped': <String, dynamic>{
        kategori: <String, dynamic>{
          'itemId': id,
          'assetId': id,
          'name': nama,
          'image': gambar,
          'mime': data['mime'],
          'chunks': data['chunks'],
          'category': kategori,
          'at': FieldValue.serverTimestamp(),
        },
      },
    },
    SetOptions(merge: true),
  );
  // Bersihkan sisa penulisan lama yang memakai titik di nama kolom.
  try {
    await dok.update(<Object, Object?>{
      FieldPath(<String>['equipped.$kategori']): FieldValue.delete(),
    });
  } catch (_) {
    /* tidak ada sisa, aman */
  }
}

/// Lepas barang dari kategori itu.
Future<void> lepasBarang({
  required String uid,
  required String kategori,
}) async {
  // `update` membaca titik sebagai jalur, jadi ini menghapus sarangnya.
  await FirebaseFirestore.instance.collection('users').doc(uid).update(
    <String, dynamic>{'equipped.$kategori': FieldValue.delete()},
  );
}

/// Barangku: barang yang sudah dibeli, dengan tab kategori seperti Toko,
/// pratinjau animasi, dan tombol Pakai/Lepas.
class MyItemsPage extends StatefulWidget {
  const MyItemsPage({super.key});

  @override
  State<MyItemsPage> createState() => _MyItemsPageState();
}

class _MyItemsPageState extends State<MyItemsPage> {
  int _cat = 0;

  @override
  Widget build(BuildContext context) {
    final User? u = FirebaseAuth.instance.currentUser;
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
          'Barangku',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
        ),
        centerTitle: true,
      ),
      body: u == null
          ? const _EmptyStore()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(u.uid)
                  .collection('inventory')
                  .snapshots(),
              builder: (
                BuildContext c,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
              ) {
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> semua =
                    snap.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final Map<String, int> jumlah = <String, int>{};
                for (final QueryDocumentSnapshot<Map<String, dynamic>> d
                    in semua) {
                  final String k = _kategoriBarang(d.data());
                  jumlah[k] = (jumlah[k] ?? 0) + 1;
                }
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    semua
                        .where((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                            _kategoriBarang(d.data()) == cat.key)
                        .toList();

                return Column(
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
                          itemBuilder: (BuildContext c, int i) {
                            final StoreCategory ct = kStoreCategories[i];
                            final bool on = i == _cat;
                            final int n = jumlah[ct.key] ?? 0;
                            return GestureDetector(
                              onTap: () => setState(() => _cat = i),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 74,
                                child: Column(
                                  children: <Widget>[
                                    Stack(
                                      clipBehavior: Clip.none,
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
                                          child: ResImage(ct.icon, fit: BoxFit.contain),
                                        ),
                                        if (n > 0)
                                          Positioned(
                                            right: -4,
                                            top: -4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: _pink,
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                              child: Text(
                                                '$n',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ct.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: on ? _ink : _muted,
                                        fontWeight:
                                            on ? FontWeight.w700 : FontWeight.w500,
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
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(u.uid)
                            .snapshots(),
                        builder: (
                          BuildContext c,
                          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                              meSnap,
                        ) {
                          final Map<String, dynamic>? me = meSnap.data?.data();
                          final String aktif = _aktifId(me, cat.key);
                          if (docs.isEmpty) {
                            return _KosongBarang(label: cat.label);
                          }
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.74,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (BuildContext c, int i) {
                              final QueryDocumentSnapshot<Map<String, dynamic>> d =
                                  docs[i];
                              return _BarangKartu(
                                uid: u.uid,
                                id: d.id,
                                data: d.data(),
                                aktif: aktif == d.id,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _KosongBarang extends StatelessWidget {
  const _KosongBarang({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inventory_2_outlined, size: 46, color: Color(0xFFD9D5E8)),
            const SizedBox(height: 10),
            Text(
              'Belum ada $label',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Beli dulu di Toko barang, nanti muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarangKartu extends StatefulWidget {
  const _BarangKartu({
    required this.uid,
    required this.id,
    required this.data,
    required this.aktif,
  });

  final String uid;
  final String id;
  final Map<String, dynamic> data;
  final bool aktif;

  @override
  State<_BarangKartu> createState() => _BarangKartuState();
}

class _BarangKartuState extends State<_BarangKartu> {
  bool _sibuk = false;

  String get _nama => (widget.data['name'] as String?) ??
      (widget.data['nama'] as String?) ??
      'Item';

  DateTime? get _sampai {
    final Object? a = widget.data['expiresAt'];
    return a is Timestamp ? a.toDate() : null;
  }

  bool get _habis {
    final DateTime? s = _sampai;
    return s != null && s.isBefore(DateTime.now());
  }

  String get _sisa {
    final DateTime? s = _sampai;
    if (s == null) {
      return 'Selamanya';
    }
    return _habis ? 'Sudah habis' : 'Sampai ${_tanggal(s)}';
  }

  Future<void> _ubah() async {
    if (_sibuk) {
      return;
    }
    setState(() => _sibuk = true);
    final String kategori = _kategoriBarang(widget.data);
    try {
      if (widget.aktif) {
        await lepasBarang(uid: widget.uid, kategori: kategori);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_nama dilepas')),
          );
        }
      } else {
        await pasangBarang(
          uid: widget.uid,
          id: widget.id,
          data: widget.data,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_nama dipakai')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sibuk = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool habis = _habis;
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _LembarBarang(uid: widget.uid, id: widget.id, data: widget.data),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.aktif ? _pink : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: _BingkaiPratinjau(
                  data: widget.data,
                  ukuran: 96,
                  id: widget.id,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _sisa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: habis ? const Color(0xFFD94A6A) : _muted,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: habis || _sibuk ? null : _ubah,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.aktif ? const Color(0xFFEDEAF7) : _pink,
                  disabledBackgroundColor: widget.aktif
                      ? const Color(0xFFEDEAF7)
                      : const Color(0xFFE6E3F0),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _sibuk
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        habis ? 'Habis' : (widget.aktif ? 'Lepas' : 'Pakai'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.aktif ? _ink : Colors.white,
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

/// Pratinjau besar satu barang milik user, lengkap dengan tombol Pakai/Lepas.
class _LembarBarang extends StatefulWidget {
  const _LembarBarang({
    required this.uid,
    required this.id,
    required this.data,
  });

  final String uid;
  final String id;
  final Map<String, dynamic> data;

  @override
  State<_LembarBarang> createState() => _LembarBarangState();
}

class _LembarBarangState extends State<_LembarBarang> {
  bool _sibuk = false;

  String get _nama => (widget.data['name'] as String?) ??
      (widget.data['nama'] as String?) ??
      'Item';

  @override
  Widget build(BuildContext context) {
    final String kategori = _kategoriBarang(widget.data);
    final Object? a = widget.data['expiresAt'];
    final DateTime? sampai = a is Timestamp ? a.toDate() : null;
    final bool habis = sampai != null && sampai.isBefore(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDAE8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: <Widget>[
                  LayoutBuilder(
                    builder: (BuildContext c, BoxConstraints k) {
                      final double ukuran =
                          (k.maxWidth - 40).clamp(200.0, 300.0);
                      return _BingkaiPratinjau(
                        data: widget.data,
                        ukuran: ukuran,
                        id: widget.id,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _nama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sampai == null
                        ? 'Selamanya'
                        : habis
                            ? 'Sudah habis'
                            : 'Sampai ${_tanggal(sampai)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: habis ? const Color(0xFFD94A6A) : _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .snapshots(),
              builder: (
                BuildContext c,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> meSnap,
              ) {
                final String aktif = _aktifId(meSnap.data?.data(), kategori);
                final bool dipakai = aktif == widget.id;
                return SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: habis || _sibuk
                        ? null
                        : () async {
                            setState(() => _sibuk = true);
                            try {
                              if (dipakai) {
                                await lepasBarang(
                                  uid: widget.uid,
                                  kategori: kategori,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$_nama dilepas')),
                                  );
                                }
                              } else {
                                await pasangBarang(
                                  uid: widget.uid,
                                  id: widget.id,
                                  data: widget.data,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$_nama dipakai')),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: ${e.toString()}')),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _sibuk = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          dipakai ? const Color(0xFFEDEAF7) : _pink,
                      disabledBackgroundColor: const Color(0xFFE6E3F0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    child: _sibuk
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            habis
                                ? 'Sudah habis'
                                : dipakai
                                    ? 'Lepas'
                                    : 'Pakai',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: dipakai ? _ink : Colors.white,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _tanggal(DateTime d) {
  const List<String> bulan = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
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
            const _KoinBulat(ukuran: 26),
            const SizedBox(width: 8),
            _SaldoTeks(user: user),
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

class _SaldoTeks extends StatelessWidget {
  const _SaldoTeks({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    const TextStyle gaya = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: _ink,
    );
    if (user == null) {
      return const Text('0', style: gaya);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (BuildContext c,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> s) {
        final int saldo = (s.data?.data()?['coins'] as num?)?.toInt() ?? 0;
        return Text('$saldo', style: gaya);
      },
    );
  }
}
