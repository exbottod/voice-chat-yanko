import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_assets.dart';
import 'res_image.dart';
import 'system_notice.dart';

/// Pilihan nominal kantong koin.
const List<int> luckyBagAmounts = <int>[675000, 4050000, 8100000, 13500000];

/// Pilihan jumlah penerima.
const List<int> luckyBagPeople = <int>[10, 30, 60, 100];

/// Pilihan hitung mundur (menit). 0 = langsung bisa diambil.
const List<int> luckyBagDelays = <int>[0, 5, 10, 20];

/// Lama kantong bisa diambil setelah terbuka. Lewat dari ini, sisa koin yang
/// tidak terambil otomatis kembali ke pemilik.
const int luckyBagClaimMinutes = 5;

const Color _gold = Color(0xFFF5C451);
const Color _goldDark = Color(0xFFB8860B);
const Color _purple1 = Color(0xFF7B2FF2);
const Color _purple2 = Color(0xFF3A0CA3);

/// Logika kantong koin: bagi acak, kirim, ambil.
class LuckyBagService {
  LuckyBagService._();

  static CollectionReference<Map<String, dynamic>> _bags(String roomId) =>
      FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('luckybags');

  static CollectionReference<Map<String, dynamic>> _chatMsg(String roomId) =>
      FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watch(String roomId) =>
      _bags(roomId).orderBy('createdAt', descending: true).limit(20).snapshots();

  /// Membagi [total] menjadi [people] bagian acak. Tiap bagian minimal 1 dan
  /// jumlah seluruh bagian selalu persis sama dengan [total].
  static List<int> splitRandom(int total, int people, [Random? rnd]) {
    final Random r = rnd ?? Random.secure();
    final int n = people.clamp(1, total);
    final List<int> parts = List<int>.filled(n, 1);
    int sisa = total - n;
    // Bobot acak supaya ada yang kecil dan ada yang besar.
    final List<double> w = List<double>.generate(n, (_) => r.nextDouble() + 0.05);
    final double sum = w.fold(0.0, (double a, double b) => a + b);
    for (int i = 0; i < n; i++) {
      final int tambah = (sisa * (w[i] / sum)).floor();
      parts[i] += tambah;
    }
    int dipakai = parts.fold(0, (int a, int b) => a + b);
    int kurang = total - dipakai;
    while (kurang > 0) {
      parts[r.nextInt(n)] += 1;
      kurang--;
    }
    parts.shuffle(r);
    return parts;
  }

  /// Kirim kantong. Mengurangi koin pengirim dan membuat dokumen kantong.
  static Future<String> send({
    required String roomId,
    required String senderName,
    required String senderPhoto,
    required int total,
    required int people,
    required int delayMinutes,
  }) async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('Belum masuk');
    }
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> me = db.collection('users').doc(u.uid);
    final DocumentReference<Map<String, dynamic>> bag = _bags(roomId).doc();
    final List<int> parts = splitRandom(total, people);
    final DateTime openAt = DateTime.now().add(Duration(minutes: delayMinutes));

    // Catatan: sebelumnya pengiriman memakai runTransaction. Transaksi
    // menunggu jawaban server sebelum dianggap selesai, dan kalau server
    // lambat tombol Kirim berputar tanpa ujung. Sekarang saldo dibaca sekali,
    // lalu semua tulisan dikirim dalam satu batch supaya cepat dan tetap
    // konsisten (koin berkurang hanya jika kantong benar-benar dibuat).
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await me.get().timeout(const Duration(seconds: 12));
    final int saldo = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
    if (saldo < total) {
      throw StateError('Coin kamu tidak cukup');
    }

    final WriteBatch batch = db.batch();
    batch.set(me, <String, dynamic>{'coins': saldo - total}, SetOptions(merge: true));
    batch.set(_chatMsg(roomId).doc(bag.id), <String, dynamic>{
      'type': 'luckybag',
      'bagId': bag.id,
      'text': 'mengirim Lucky Bag',
      'uid': u.uid,
      'senderId': u.uid,
      'name': senderName,
      'photoUrl': senderPhoto,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(bag, <String, dynamic>{
      'senderId': u.uid,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'total': total,
      'people': parts.length,
      'parts': parts,
      'claimedCount': 0,
      'claimedBy': <String, dynamic>{},
      'openAt': Timestamp.fromDate(openAt),
      'expiresAt': Timestamp.fromDate(openAt.add(const Duration(minutes: luckyBagClaimMinutes))),
      'refunded': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw StateError(
          'Jaringan lambat. Periksa room dulu: kantong mungkin sudah terkirim.');
    }
    return bag.id;
  }

  /// Batas akhir ambil. Kantong lama tanpa `expiresAt` dihitung dari `openAt`.
  static DateTime? _batas(Map<String, dynamic> d) {
    final Object? e = d['expiresAt'];
    if (e is Timestamp) {
      return e.toDate();
    }
    final Object? o = d['openAt'];
    if (o is Timestamp) {
      return o.toDate().add(const Duration(minutes: luckyBagClaimMinutes));
    }
    return null;
  }

  static bool _kedaluwarsa(Map<String, dynamic> d) {
    final DateTime? b = _batas(d);
    return b != null && !b.isAfter(DateTime.now());
  }

  /// Apakah kantong ini sudah lewat batas ambil.
  static bool sudahKedaluwarsa(Map<String, dynamic> d) => _kedaluwarsa(d);

  /// Tandai sisa koin yang tidak terambil agar kembali ke pengirim. Aman
  /// dipanggil perangkat mana pun: hanya menulis dokumen kantong (penanda
  /// `refundDue`), bukan koin akun orang lain. Pencairan dilakukan pemilik
  /// sendiri lewat [cairkanRefund] karena aturan keamanan hanya mengizinkan
  /// pemilik menambah koin akunnya.
  static Future<int> kembalikanSisa(String roomId, String bagId) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> bag = _bags(roomId).doc(bagId);
    try {
      final int sisa = await db.runTransaction<int>((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> b = await tx.get(bag);
        final Map<String, dynamic>? d = b.data();
        if (d == null || !_kedaluwarsa(d)) {
          return 0;
        }
        final int sudah = (d['refundDue'] as num?)?.toInt() ?? 0;
        if (d['refunded'] == true || sudah > 0) {
          return sudah;
        }
        final List<dynamic> parts = List<dynamic>.from(d['parts'] as List? ?? <dynamic>[]);
        final int diambil = (d['claimedCount'] as num?)?.toInt() ?? 0;
        int sisa = 0;
        for (int i = diambil; i < parts.length; i++) {
          sisa += (parts[i] as num).toInt();
        }
        tx.update(bag, <String, dynamic>{
          'refundDue': sisa,
          'refundAt': FieldValue.serverTimestamp(),
        });
        return sisa;
      });
      if (sisa > 0) {
        await cairkanRefund(roomId);
      }
      return sisa;
    } catch (_) {
      return 0;
    }
  }

  /// Cairkan sisa kantong milik pengguna yang sedang masuk. Hanya pemilik yang
  /// menulis koin akunnya sendiri, jadi aturan keamanan tetap ketat.
  static Future<int> cairkanRefund(String roomId) async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return 0;
    }
    final FirebaseFirestore db = FirebaseFirestore.instance;
    int total = 0;
    try {
      final QuerySnapshot<Map<String, dynamic>> q = await _bags(roomId)
          .where('senderId', isEqualTo: u.uid)
          .limit(20)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in q.docs) {
        final int bayar = await db.runTransaction<int>((Transaction tx) async {
          final DocumentSnapshot<Map<String, dynamic>> b = await tx.get(doc.reference);
          final Map<String, dynamic>? d = b.data();
          final int sisa = (d?['refundDue'] as num?)?.toInt() ?? 0;
          if (d == null || sisa <= 0 || d['refunded'] == true) {
            return 0;
          }
          final DocumentReference<Map<String, dynamic>> akun =
              db.collection('users').doc(u.uid);
          final DocumentSnapshot<Map<String, dynamic>> s = await tx.get(akun);
          final int saldo = (s.data()?['coins'] as num?)?.toInt() ?? 0;
          tx.set(akun, <String, dynamic>{'coins': saldo + sisa}, SetOptions(merge: true));
          tx.update(doc.reference, <String, dynamic>{
            'refunded': true,
            'refundedAmount': sisa,
            'refundDue': 0,
            'refundedAt': FieldValue.serverTimestamp(),
          });
          return sisa;
        });
        if (bayar > 0) {
          total += bayar;
          SystemNotice.kirim(
            type: 'reward',
            emoji: '\u{1F4B0}',
            title: 'Sisa Lucky Bag kembali',
            body: 'Sisa koin yang tidak terambil sudah kembali: +${formatKoin(bayar)} koin.',
          );
        }
      }
    } catch (_) {
      /* diamkan, coba lagi nanti */
    }
    return total;
  }

  /// Ambil satu bagian. Atomik: satu user hanya sekali, bagian tidak ganda.
  /// Mengembalikan jumlah koin, atau null dengan [alasan] bila gagal.
  static Future<({int? coins, String? alasan})> claim(String roomId, String bagId) async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return (coins: null, alasan: 'Belum masuk');
    }
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final DocumentReference<Map<String, dynamic>> bag = _bags(roomId).doc(bagId);
    final DocumentReference<Map<String, dynamic>> me = db.collection('users').doc(u.uid);
    try {
      // Batas waktu supaya tombol Ambil tidak menggantung saat jaringan lambat:
      // dialog hasil tetap muncul, berisi pesan kenapa belum berhasil.
      final int? hasil = await db.runTransaction<int?>((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> b = await tx.get(bag);
        final Map<String, dynamic>? d = b.data();
        if (d == null) {
          throw StateError('Kantong tidak ditemukan');
        }
        final Map<String, dynamic> by = Map<String, dynamic>.from(d['claimedBy'] as Map? ?? <String, dynamic>{});
        if (by.containsKey(u.uid)) {
          throw StateError('Kamu sudah mengambil kantong ini');
        }
        final Timestamp? open = d['openAt'] as Timestamp?;
        if (open != null && open.toDate().isAfter(DateTime.now())) {
          throw StateError('Belum waktunya, tunggu hitung mundur');
        }
        if (_kedaluwarsa(d)) {
          throw StateError('Waktu mengambil sudah habis, sisa koin dikembalikan ke pengirim');
        }
        final List<dynamic> parts = List<dynamic>.from(d['parts'] as List? ?? <dynamic>[]);
        final int idx = (d['claimedCount'] as num?)?.toInt() ?? 0;
        if (idx >= parts.length) {
          throw StateError('Kantong sudah habis');
        }
        final int dapat = (parts[idx] as num).toInt();
        by[u.uid] = dapat;
        tx.update(bag, <String, dynamic>{
          'claimedCount': idx + 1,
          'claimedBy': by,
        });
        final DocumentSnapshot<Map<String, dynamic>> s = await tx.get(me);
        final int saldo = (s.data()?['coins'] as num?)?.toInt() ?? 0;
        tx.set(me, <String, dynamic>{'coins': saldo + dapat}, SetOptions(merge: true));
        return dapat;
      }, timeout: const Duration(seconds: 15));
      SystemNotice.kirim(
        type: 'reward',
        emoji: '\u{1F9E7}',
        title: 'Kamu mendapat hadiah Lucky Bag',
        body: 'Selamat! Kamu mendapat +${formatKoin(hasil ?? 0)} koin dari Lucky Bag.',
      );
      return (coins: hasil, alasan: null);
    } on StateError catch (e) {
      return (coins: null, alasan: e.message);
    } on FirebaseException catch (e) {
      return (coins: null, alasan: 'Gagal mengambil: ${e.code}');
    } on TimeoutException {
      return (coins: null, alasan: 'Jaringan lambat. Coba ambil lagi.');
    } catch (e) {
      return (coins: null, alasan: 'Gagal mengambil. Coba lagi.');
    }
  }
}

String formatKoin(int n) {
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

/// Sheet "Lucky Bag" untuk mengirim kantong koin.
Future<bool> showLuckyBagSheet(
  BuildContext context, {
  required String roomId,
  required String senderName,
  required String senderPhoto,
}) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _LuckyBagSheet(
      roomId: roomId,
      senderName: senderName,
      senderPhoto: senderPhoto,
    ),
  );
  return ok == true;
}

class _LuckyBagSheet extends StatefulWidget {
  const _LuckyBagSheet({
    required this.roomId,
    required this.senderName,
    required this.senderPhoto,
  });

  final String roomId;
  final String senderName;
  final String senderPhoto;

  @override
  State<_LuckyBagSheet> createState() => _LuckyBagSheetState();
}

class _LuckyBagSheetState extends State<_LuckyBagSheet> {
  int _amount = 0;
  int _people = 0;
  int _delay = 0;
  int _saldo = 0;
  bool _busy = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSaldo());
  }

  Future<void> _loadSaldo() async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> s =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() => _saldo = (s.data()?['coins'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _kirim() async {
    final int total = luckyBagAmounts[_amount];
    if (total > _saldo) {
      setState(() => _err = 'Coin kamu tidak cukup. Saldo: ${formatKoin(_saldo)}');
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await LuckyBagService.send(
        roomId: widget.roomId,
        senderName: widget.senderName,
        senderPhoto: widget.senderPhoto,
        total: total,
        people: luckyBagPeople[_people],
        delayMinutes: luckyBagDelays[_delay],
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on StateError catch (e) {
      setState(() {
        _busy = false;
        _err = e.message;
      });
    } on TimeoutException {
      setState(() {
        _busy = false;
        _err = 'Jaringan lambat. Periksa room dulu: kantong mungkin sudah terkirim.';
      });
    } on FirebaseException catch (e) {
      setState(() {
        _busy = false;
        _err = 'Gagal mengirim (${e.code}). Coba lagi.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _err = 'Gagal mengirim: $e';
      });
    }
  }

  Widget _judul(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.diamond, size: 9, color: _gold),
            const SizedBox(width: 8),
            Text(t, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.diamond, size: 9, color: _gold),
          ],
        ),
      );

  Widget _pill(String t, bool on, VoidCallback tap) => Expanded(
        child: GestureDetector(
          onTap: _busy ? null : tap,
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: on
                  ? const LinearGradient(colors: <Color>[Color(0xFFFFE08A), _gold])
                  : const LinearGradient(colors: <Color>[_purple1, _purple2]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold, width: 1.4),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: on ? const Color(0xFF4A2A00) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final int total = luckyBagAmounts[_amount];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF5B1FB5), Color(0xFF2B0A66)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: _gold, width: 2)),
      ),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Lucky Bag',
                style: TextStyle(color: _gold, fontSize: 26, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: <Color>[_goldDark, _gold, _goldDark]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text('tas koin',
                  style: TextStyle(color: Color(0xFF4A2A00), fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            _judul('Total harga'),
            Row(
              children: List<Widget>.generate(luckyBagAmounts.length, (int i) {
                final bool on = i == _amount;
                return Expanded(
                  child: GestureDetector(
                    onTap: _busy ? null : () => setState(() => _amount = i),
                    child: Container(
                      height: 96,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: on
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Color(0xFFFFD36B), Color(0xFFE59A1E)])
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Color(0xFF8A3DE0), Color(0xFF4A168F)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: on ? Colors.white : _gold.withValues(alpha: 0.6), width: on ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(i == 3 ? Icons.inventory_2 : Icons.savings,
                              size: 34, color: on ? const Color(0xFF7A4A00) : _gold),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(Icons.monetization_on, size: 11, color: _gold),
                              const SizedBox(width: 2),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(formatKoin(luckyBagAmounts[i]),
                                      style: TextStyle(
                                          color: on ? const Color(0xFF4A2A00) : Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pemain lain dapat ambil 1~${formatKoin(total - luckyBagPeople[_people] + 1)} koin emas acak',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            _judul('Lucky People'),
            Row(
              children: List<Widget>.generate(luckyBagPeople.length,
                  (int i) => _pill('${luckyBagPeople[i]}', i == _people, () => setState(() => _people = i))),
            ),
            _judul('hitung mundur'),
            Row(
              children: List<Widget>.generate(
                luckyBagDelays.length,
                (int i) => _pill(luckyBagDelays[i] == 0 ? 'Sekarang' : '${luckyBagDelays[i]} menit', i == _delay,
                    () => setState(() => _delay = i)),
              ),
            ),
            const SizedBox(height: 10),
            Text('Saldo kamu: ${formatKoin(_saldo)} koin',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_err, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 12.5)),
              ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _busy ? null : _kirim,
              child: Container(
                height: 50,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: <Color>[Color(0xFFFFE08A), Color(0xFFE59A1E)]),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF4A2A00)))
                    : const Text('Kirim',
                        style: TextStyle(color: Color(0xFF4A2A00), fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Popup hasil: "Selamat, Anda mendapatkan N koin".
Future<void> showLuckyBagResult(
  BuildContext context, {
  required String senderName,
  required String senderPhoto,
  required int? coins,
  String? alasan,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (BuildContext ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF6A2BC9), Color(0xFF3A1180)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _gold, width: 2.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Lucky Bag',
                style: TextStyle(color: _gold, fontSize: 28, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
            Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              child: ClipOval(
                child: senderPhoto.isEmpty
                    ? Container(
                        color: const Color(0xFF5B2FA8),
                        alignment: Alignment.center,
                        child: Text(senderName.isEmpty ? '?' : senderName.characters.first.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 32)))
                    : Image.network(senderPhoto, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF5B2FA8))),
              ),
            ),
            const SizedBox(height: 14),
            Text('lucky bag koin dari "$senderName"',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 14),
            Text(
              coins != null
                  ? 'Selamat~~Anda mendapatkan ${formatKoin(coins)} koin! Koin emas akan langsung masuk ke dompet Anda.'
                  : (alasan ?? 'Gagal mengambil'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFE066), fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                height: 46,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: <Color>[Color(0xFFFFE08A), Color(0xFFE59A1E)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text('Terima kasih',
                    style: TextStyle(color: Color(0xFF4A2A00), fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hitung mundur `mm:ss` menuju [bukaPada]. Berdetak tiap detik dan berhenti
/// sendiri saat waktunya tiba (lalu menampilkan [saatTiba]).
class LuckyBagCountdown extends StatefulWidget {
  const LuckyBagCountdown({
    super.key,
    required this.bukaPada,
    this.saatTiba = 'Ambil',
    this.gaya,
  });

  final DateTime? bukaPada;
  final String saatTiba;
  final TextStyle? gaya;

  @override
  State<LuckyBagCountdown> createState() => _LuckyBagCountdownState();
}

class _LuckyBagCountdownState extends State<LuckyBagCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      final DateTime? t = widget.bukaPada;
      if (t == null || !t.isAfter(DateTime.now())) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _dua(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final DateTime? t = widget.bukaPada;
    final Duration sisa = t == null ? Duration.zero : t.difference(DateTime.now());
    final bool tunggu = sisa > Duration.zero;
    String teks = widget.saatTiba;
    if (tunggu) {
      final int total = sisa.inSeconds + (sisa.inMilliseconds % 1000 > 0 ? 1 : 0);
      final int jam = total ~/ 3600;
      final int mnt = (total % 3600) ~/ 60;
      final int dtk = total % 60;
      teks = jam > 0 ? '$jam:${_dua(mnt)}:${_dua(dtk)}' : '${_dua(mnt)}:${_dua(dtk)}';
    }
    return Text(
      teks,
      style: widget.gaya ??
          const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            shadows: <Shadow>[Shadow(color: Color(0xAA000000), blurRadius: 3)],
          ),
    );
  }
}

/// Ikon kantong di samping roket. Tampil bila ada kantong yang belum diambil.
/// Tujuan hitung mundur: belum terbuka -> waktu buka, sudah terbuka -> batas
/// ambil (setelah itu sisa koin kembali ke pemilik).
/// Waktu buka bila kantong masih menunggu. Bila sudah terbuka (termasuk yang
/// dikirim "Sekarang") hasilnya null, jadi tidak ada hitung mundur dan
/// langsung bisa diambil.
DateTime? _menungguBuka(Map<String, dynamic> d) {
  final DateTime? buka = (d['openAt'] as Timestamp?)?.toDate();
  if (buka != null && buka.isAfter(DateTime.now())) {
    return buka;
  }
  return null;
}

DateTime? _tujuan(Map<String, dynamic> d) {
  final DateTime? buka = (d['openAt'] as Timestamp?)?.toDate();
  if (buka != null && buka.isAfter(DateTime.now())) {
    return buka;
  }
  final Object? e = d['expiresAt'];
  if (e is Timestamp) {
    return e.toDate();
  }
  return buka?.add(const Duration(minutes: luckyBagClaimMinutes));
}

class LuckyBagSideIcon extends StatefulWidget {
  const LuckyBagSideIcon({super.key, required this.roomId, required this.onClaim});

  final String roomId;
  final Future<void> Function(String bagId, Map<String, dynamic> data) onClaim;

  @override
  State<LuckyBagSideIcon> createState() => _LuckyBagSideIconState();
}

class _LuckyBagSideIconState extends State<LuckyBagSideIcon> {
  Timer? _timer;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      LuckyBagService.watch(widget.roomId);

  @override
  void initState() {
    super.initState();
    // Detak tiap detik: memperbarui hitung mundur, menyembunyikan kantong yang
    // sudah lewat batas ambil, dan memicu pengembalian sisa koin ke pengirim.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String roomId = widget.roomId;
    final Future<void> Function(String bagId, Map<String, dynamic> data) onClaim =
        widget.onClaim;
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (BuildContext c, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> terbuka =
            (snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]).where((d) {
          final Map<String, dynamic> m = d.data();
          final Map<dynamic, dynamic> by = (m['claimedBy'] as Map?) ?? <dynamic, dynamic>{};
          final int n = (m['claimedCount'] as num?)?.toInt() ?? 0;
          final int tot = (m['people'] as num?)?.toInt() ?? 0;
          if (LuckyBagService.sudahKedaluwarsa(m)) {
            if (m['refunded'] != true && n < tot) {
              LuckyBagService.kembalikanSisa(roomId, d.id);
            }
            return false;
          }
          return !by.containsKey(uid) && n < tot;
        }).toList();
        if (terbuka.isEmpty) {
          return const SizedBox.shrink();
        }
        final QueryDocumentSnapshot<Map<String, dynamic>> first = terbuka.first;
        return GestureDetector(
          onTap: () => onClaim(first.id, first.data()),
          child: SizedBox(
            width: 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      const ResImage(AppAssets.luckyBagClosed, width: 46, height: 46),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
                          child: Text('${terbuka.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
                LuckyBagCountdown(
                  bukaPada: _menungguBuka(first.data()),
                  saatTiba: 'Ambil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kartu "kirim lucky bag happy every day" di chat dengan tombol Ambil.
class LuckyBagChatCard extends StatelessWidget {
  const LuckyBagChatCard({super.key, required this.data, required this.onClaim});

  final Map<String, dynamic> data;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String nama = (data['senderName'] as String?) ?? 'User';
    final Map<dynamic, dynamic> by = (data['claimedBy'] as Map?) ?? <dynamic, dynamic>{};
    final int n = (data['claimedCount'] as num?)?.toInt() ?? 0;
    final int tot = (data['people'] as num?)?.toInt() ?? 0;
    final bool sudah = by.containsKey(uid);
    final bool habis = n >= tot;
    final Timestamp? open = data['openAt'] as Timestamp?;
    final bool menunggu = open != null && open.toDate().isAfter(DateTime.now());
    final bool lewat = LuckyBagService.sudahKedaluwarsa(data);
    final String label = sudah
        ? 'Sudah diambil'
        : habis
            ? 'Habis'
            : lewat
                ? 'Kedaluwarsa'
                : menunggu
                    ? 'Segera'
                    : 'Ambil';
    final bool aktif = !sudah && !habis && !menunggu && !lewat;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 60),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFF8A2BE2), Color(0xFFD63AF9)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.8), width: 1.4),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$nama kirim lucky bag happy every day',
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    lewat && data['refunded'] == true
                        ? '$n/$tot mengambil. Sisa ${formatKoin((data['refundedAmount'] as num?)?.toInt() ?? 0)} koin dikembalikan ke pengirim'
                        : '$n/$tot sudah mengambil',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: aktif ? onClaim : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: aktif
                            ? const <Color>[Color(0xFFFFE08A), Color(0xFFE59A1E)]
                            : const <Color>[Color(0xFF9E9E9E), Color(0xFF757575)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(label,
                        style: const TextStyle(color: Color(0xFF4A2A00), fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ResImage(
                sudah ? AppAssets.luckyBagOpen : AppAssets.luckyBagClosed,
                width: 64,
                height: 64,
              ),
              // Hitung mundur hanya tampil selama menunggu waktu buka. Setelah
              // terbuka (atau bila dikirim "Sekarang") langsung bisa diambil,
              // tanpa angka menit.
              if (!sudah && !habis && !lewat && menunggu)
                LuckyBagCountdown(
                  bukaPada: open.toDate(),
                  saatTiba: 'Siap diambil',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu chat yang selalu menampilkan status terbaru kantong. Selama masih
/// menunggu hitung mundur, kartu dibangun ulang tiap detik supaya tombol
/// langsung aktif begitu waktunya tiba.
class LuckyBagChatLive extends StatefulWidget {
  const LuckyBagChatLive({super.key, required this.roomId, required this.bagId, required this.onClaim});

  final String roomId;
  final String bagId;
  final Future<void> Function(String bagId, Map<String, dynamic> data) onClaim;

  @override
  State<LuckyBagChatLive> createState() => _LuckyBagChatLiveState();
}

class _LuckyBagChatLiveState extends State<LuckyBagChatLive> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('luckybags')
          .doc(widget.bagId)
          .snapshots(),
      builder: (BuildContext c, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
        final Map<String, dynamic>? d = snap.data?.data();
        if (d == null) {
          return const SizedBox.shrink();
        }
        final Timestamp? open = d['openAt'] as Timestamp?;
        if (open == null || !open.toDate().isAfter(DateTime.now())) {
          _timer?.cancel();
        }
        return LuckyBagChatCard(data: d, onClaim: () => widget.onClaim(widget.bagId, d));
      },
    );
  }
}
