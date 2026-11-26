import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import 'app_lang.dart';
import 'social_service.dart';

const Color _bg = Color(0xFF0B0A1F);
const Color _kolom = Color(0xFF1D1B3F);
const Color _garis = Color(0xFF34315E);
const Color _redup = Color(0xFF6E6A99);
const Color _merah = Color(0xFFEC4899);
const Color _oranye = Color(0xFFF59E0B);

/// Chat pribadi dengan satu pengguna.
class DmPage extends StatefulWidget {
  const DmPage({
    super.key,
    required this.targetUid,
    required this.targetNama,
    this.targetFoto = '',
    this.targetPublicId = '',
  });

  final String targetUid;
  final String targetNama;
  final String targetFoto;
  final String targetPublicId;

  @override
  State<DmPage> createState() => _DmPageState();
}

class _DmPageState extends State<DmPage> {
  final TextEditingController _ctl = TextEditingController();
  bool _mengirim = false;
  String _namaSaya = 'User';
  String _fotoSaya = '';

  @override
  void initState() {
    super.initState();
    final User? u = FirebaseAuth.instance.currentUser;
    _namaSaya = (u?.displayName?.isNotEmpty ?? false) ? u!.displayName! : 'User';
    _fotoSaya = u?.photoURL ?? '';
    // Membuka percakapan menandainya sudah dibaca, ditunda sampai tampil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(SocialService.tandaiDibaca(widget.targetUid));
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final String teks = _ctl.text.trim();
    if (teks.isEmpty || _mengirim) {
      return;
    }
    // Kolom langsung dikosongkan supaya terasa seketika.
    _ctl.clear();
    setState(() => _mengirim = true);
    try {
      await SocialService.kirim(
        target: widget.targetUid,
        targetNama: widget.targetNama,
        targetFoto: widget.targetFoto,
        targetPublicId: widget.targetPublicId,
        teks: teks,
        namaSaya: _namaSaya,
        fotoSaya: _fotoSaya,
      );
    } catch (_) {
      if (mounted) {
        _ctl.text = teks;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan gagal terkirim')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _mengirim = false);
      }
    }
  }

  Widget _foto(double ukuran) {
    final String f = widget.targetFoto;
    Widget isi = Icon(Icons.person, size: ukuran * 0.5, color: const Color(0xFFB9B5E0));
    if (f.startsWith('data:image')) {
      try {
        isi = Image.memory(
          base64Decode(f.substring(f.indexOf(',') + 1)),
          width: ukuran,
          height: ukuran,
          fit: BoxFit.cover,
          cacheWidth: (ukuran * 3).round(),
          gaplessPlayback: true,
        );
      } catch (_) {}
    } else if (f.startsWith('http')) {
      isi = Image.network(f,
          width: ukuran,
          height: ukuran,
          fit: BoxFit.cover,
          cacheWidth: (ukuran * 3).round());
    }
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: const BoxDecoration(color: Color(0xFF2A2754), shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: isi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String me = SocialService.myUid ?? '';
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFE6E3FF)),
                  ),
                  const SizedBox(width: 6),
                  _foto(44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.targetNama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.targetPublicId.isNotEmpty)
                          Text(
                            'ID: ${widget.targetPublicId}',
                            style: const TextStyle(fontSize: 12, color: _redup),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_vert, color: Color(0xFFE6E3FF)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: SocialService.pesan(widget.targetUid),
                builder: (BuildContext c,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                      snap.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 60, color: _merah),
                          const SizedBox(height: 22),
                          const Text(
                            'Say hi to start the conversation.',
                            style: TextStyle(fontSize: 14, color: _redup),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    itemCount: docs.length,
                    itemBuilder: (BuildContext c, int i) {
                      final Map<String, dynamic> d = docs[i].data();
                      final bool saya = d['from'] == me;
                      return Align(
                        alignment:
                            saya ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.74,
                          ),
                          decoration: BoxDecoration(
                            gradient: saya
                                ? const LinearGradient(
                                    colors: <Color>[_oranye, _merah])
                                : null,
                            color: saya ? null : _kolom,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(saya ? 16 : 4),
                              bottomRight: Radius.circular(saya ? 4 : 16),
                            ),
                          ),
                          child: Text(
                            (d['text'] as String?) ?? '',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1B1940))),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kolom,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _garis, width: 1.4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: _ctl,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _kirim(),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: _redup),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _kirim,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.send_rounded, size: 34, color: _merah),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
