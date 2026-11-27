import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Suara room memakai WebRTC antar pengguna (peer ke peer).
///
/// Penanda tangan (offer, answer, kandidat ICE) ditulis ke Firestore:
/// rooms/{roomId}/voice/{uid} untuk daftar yang sedang di kursi mic,
/// rooms/{roomId}/signal/{pasangan} untuk pertukaran SDP dan ICE.
class RtcVoice {
  RtcVoice._();

  static final RtcVoice instance = RtcVoice._();

  static const Map<String, dynamic> _konfigurasi = <String, dynamic>{
    'iceServers': <Map<String, dynamic>>[
      <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      <String, dynamic>{'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  final Map<String, _Peer> _peers = <String, _Peer>{};
  final Map<String, int> _candLawan = <String, int>{};
  MediaStream? _lokal;
  String? _roomId;
  String? _uid;
  int? _kursi;
  bool _micOn = true;
  bool _aktif = false;
  bool _mulai = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  // Kanal data dipakai menyebar posisi kursi langsung ke HP lain tanpa
  // menunggu Firestore, jadi perpindahan kursi terlihat di bawah 100 ms.
  final StreamController<Map<String, dynamic>> _kursiMasuk =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _kursiTerakhir;

  bool get aktif => _aktif;

  /// Perubahan kursi yang datang dari HP lain lewat kanal data.
  Stream<Map<String, dynamic>> get kursiMasuk => _kursiMasuk.stream;

  /// Sebarkan posisi kursi ke semua lawan yang sudah tersambung. Ringan dan
  /// tanpa server, jadi sampai di HP lain dalam hitungan milidetik.
  void sebarKursi({
    required int? seat,
    required bool micOn,
    String name = '',
    String photoUrl = '',
  }) {
    final String? uid = _uid;
    if (uid == null) {
      return;
    }
    _kursiTerakhir = <String, dynamic>{
      't': 'kursi',
      'uid': uid,
      'seat': seat,
      'micOn': micOn,
      'name': name,
      'photoUrl': photoUrl,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    for (final _Peer p in _peers.values) {
      _kirimKursi(p);
    }
  }

  void _kirimKursi(_Peer p) {
    final RTCDataChannel? dc = p.dc;
    final Map<String, dynamic>? data = _kursiTerakhir;
    if (dc == null || data == null) {
      return;
    }
    try {
      dc.send(RTCDataChannelMessage(jsonEncode(data)));
    } catch (_) {
      // Kanal belum terbuka: Firestore tetap jadi jalur cadangan.
    }
  }

  /// Pasang penerima pada kanal data satu lawan.
  void _pasangKanal(_Peer p, RTCDataChannel dc) {
    p.dc = dc;
    dc.onMessage = (RTCDataChannelMessage m) {
      try {
        final Object? isi = jsonDecode(m.text);
        if (isi is Map<String, dynamic> && isi['t'] == 'kursi') {
          if (!_kursiMasuk.isClosed) {
            _kursiMasuk.add(isi);
          }
        }
      } catch (_) {}
    };
    // Begitu kanal terbuka, kirim keadaan kursi terakhir agar lawan langsung
    // sinkron tanpa menunggu tulisan Firestore.
    dc.onDataChannelState = (RTCDataChannelState? st) {
      if (st == RTCDataChannelState.RTCDataChannelOpen) {
        _kirimKursi(p);
      }
    };
  }

  CollectionReference<Map<String, dynamic>>? get _suaraRef {
    final String? id = _roomId;
    if (id == null) {
      return null;
    }
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(id)
        .collection('voice');
  }

  /// Mulai mengirim suara dari kursi [seat]. Aman dipanggil berulang.
  Future<void> start({
    required String roomId,
    required int seat,
    required bool micOn,
  }) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    _roomId = roomId;
    _uid = uid;
    _kursi = seat;
    _micOn = micOn;
    if (_mulai) {
      await _tulisKehadiran();
      await setMic(micOn);
      return;
    }
    _mulai = true;
    try {
      _lokal = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      _lokal!.getAudioTracks().forEach((MediaStreamTrack t) {
        t.enabled = micOn;
      });
    } catch (_) {
      _mulai = false;
      _lokal = null;
      return;
    }
    _aktif = true;
    await _tulisKehadiran();
    final CollectionReference<Map<String, dynamic>>? ref = _suaraRef;
    if (ref == null) {
      return;
    }
    _sub = ref.snapshots().listen((QuerySnapshot<Map<String, dynamic>> snap) {
      final Set<String> hadir = <String>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        final String lain = (d.data()['uid'] as String?) ?? d.id;
        if (lain.isEmpty || lain == _uid) {
          continue;
        }
        hadir.add(lain);
        if (!_peers.containsKey(lain)) {
          unawaited(_sambung(lain));
        }
      }
      // Yang sudah tidak di kursi: putuskan sambungannya.
      for (final String lain in _peers.keys.toList()) {
        if (!hadir.contains(lain)) {
          unawaited(_putus(lain));
        }
      }
    });
  }

  /// Nyalakan atau matikan pengiriman suara tanpa turun dari kursi.
  Future<void> setMic(bool on) async {
    _micOn = on;
    final MediaStream? s = _lokal;
    if (s != null) {
      s.getAudioTracks().forEach((MediaStreamTrack t) {
        t.enabled = on;
      });
    }
    await _tulisKehadiran();
  }

  /// Berhenti total: tutup sambungan, hapus penanda, matikan mikrofon.
  Future<void> stop() async {
    _aktif = false;
    _mulai = false;
    await _sub?.cancel();
    _sub = null;
    for (final String lain in _peers.keys.toList()) {
      await _putus(lain);
    }
    _peers.clear();
    _candLawan.clear();
    final MediaStream? s = _lokal;
    _lokal = null;
    if (s != null) {
      for (final MediaStreamTrack t in s.getTracks()) {
        await t.stop();
      }
      await s.dispose();
    }
    final String? uid = _uid;
    final CollectionReference<Map<String, dynamic>>? ref = _suaraRef;
    if (uid != null && ref != null) {
      try {
        await ref.doc(uid).delete();
      } catch (_) {}
    }
    _roomId = null;
    _uid = null;
    _kursi = null;
  }

  Future<void> _tulisKehadiran() async {
    final String? uid = _uid;
    final int? kursi = _kursi;
    final CollectionReference<Map<String, dynamic>>? ref = _suaraRef;
    if (uid == null || kursi == null || ref == null) {
      return;
    }
    try {
      await ref.doc(uid).set(<String, dynamic>{
        'uid': uid,
        'seat': kursi,
        'micOn': _micOn,
        'ts': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  String _idPasangan(String a, String b) {
    final List<String> dua = <String>[a, b]..sort();
    return '${dua[0]}__${dua[1]}';
  }

  bool _pemanggil(String lain) => (_uid ?? '').compareTo(lain) < 0;

  DocumentReference<Map<String, dynamic>> _sinyal(String pasangan) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(_roomId)
        .collection('signal')
        .doc(pasangan);
  }

  Future<void> _sambung(String lain) async {
    final MediaStream? lokal = _lokal;
    if (lokal == null) {
      return;
    }
    final RTCPeerConnection pc = await createPeerConnection(_konfigurasi);
    final _Peer p = _Peer(lain, pc);
    _peers[lain] = p;
    final String pasangan = _idPasangan(_uid ?? '', lain);
    p.pasangan = pasangan;
    final DocumentReference<Map<String, dynamic>> doc = _sinyal(pasangan);
    final bool akuPemanggil = _pemanggil(lain);
    final String sisiku = akuPemanggil ? 'a' : 'b';
    final String sisiLawan = akuPemanggil ? 'b' : 'a';

    for (final MediaStreamTrack t in lokal.getTracks()) {
      await pc.addTrack(t, lokal);
    }

    pc.onDataChannel = (RTCDataChannel? ch) {
      if (ch != null) {
        _pasangKanal(p, ch);
      }
    };
    try {
      _pasangKanal(p, await pc.createDataChannel('kursi', RTCDataChannelInit()));
    } catch (_) {}

    pc.onIceCandidate = (RTCIceCandidate c) async {
      if (c.candidate == null) {
        return;
      }
      try {
        await doc.set(<String, dynamic>{
          '${sisiku}Cand': FieldValue.arrayUnion(<Map<String, dynamic>>[
            <String, dynamic>{
              'candidate': c.candidate,
              'sdpMid': c.sdpMid,
              'sdpMLineIndex': c.sdpMLineIndex,
            },
          ]),
        }, SetOptions(merge: true));
      } catch (_) {}
    };

    p.sub = doc.snapshots().listen((DocumentSnapshot<Map<String, dynamic>> s) async {
      final Map<String, dynamic>? d = s.data();
      if (d == null) {
        return;
      }
      try {
        if (akuPemanggil) {
          final Map<String, dynamic>? ans =
              d['answer'] as Map<String, dynamic>?;
          if (!p.pasangJawaban && ans != null) {
            p.pasangJawaban = true;
            await pc.setRemoteDescription(RTCSessionDescription(
              ans['sdp'] as String?,
              ans['type'] as String?,
            ));
          }
        } else {
          final Map<String, dynamic>? off = d['offer'] as Map<String, dynamic>?;
          if (!p.pasangTawaran && off != null) {
            p.pasangTawaran = true;
            await pc.setRemoteDescription(RTCSessionDescription(
              off['sdp'] as String?,
              off['type'] as String?,
            ));
            final RTCSessionDescription jawab = await pc.createAnswer();
            await pc.setLocalDescription(jawab);
            await doc.set(<String, dynamic>{
              'answer': <String, dynamic>{
                'sdp': jawab.sdp,
                'type': jawab.type,
              },
            }, SetOptions(merge: true));
          }
        }
        // Kandidat dari lawan, ditambahkan sekali saja.
        final List<dynamic> cand =
            (d['${sisiLawan}Cand'] as List<dynamic>?) ?? <dynamic>[];
        final int sudah = _candLawan[pasangan] ?? 0;
        for (int i = sudah; i < cand.length; i++) {
          final Map<String, dynamic> m = cand[i] as Map<String, dynamic>;
          await pc.addCandidate(RTCIceCandidate(
            m['candidate'] as String?,
            m['sdpMid'] as String?,
            m['sdpMLineIndex'] as int?,
          ));
        }
        _candLawan[pasangan] = cand.length;
      } catch (_) {}
    });

    if (akuPemanggil) {
      final RTCSessionDescription tawaran = await pc.createOffer();
      await pc.setLocalDescription(tawaran);
      await doc.set(<String, dynamic>{
        'a': _uid,
        'b': lain,
        'offer': <String, dynamic>{
          'sdp': tawaran.sdp,
          'type': tawaran.type,
        },
        'ts': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _putus(String lain) async {
    final _Peer? p = _peers.remove(lain);
    if (p == null) {
      return;
    }
    await p.sub?.cancel();
    try {
      await p.dc?.close();
    } catch (_) {}
    try {
      await p.pc.close();
    } catch (_) {}
    final String? pasangan = p.pasangan;
    if (pasangan != null) {
      _candLawan.remove(pasangan);
      try {
        await _sinyal(pasangan).delete();
      } catch (_) {}
    }
  }
}

class _Peer {
  _Peer(this.uid, this.pc);

  final String uid;
  final RTCPeerConnection pc;
  String? pasangan;
  RTCDataChannel? dc;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
  bool pasangTawaran = false;
  bool pasangJawaban = false;
}
