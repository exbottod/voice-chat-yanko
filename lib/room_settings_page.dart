import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'square_crop_page.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF8E8AA8);
const Color _pink = Color(0xFFFF4F8B);
const Color _gold = Color(0xFFE8C577);

/// Pengaturan room: foto, nama, pengumuman, sandi, mic, tema, admin,
/// blacklist, dan riwayat kick.
class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);

  Map<String, dynamic> _data = <String, dynamic>{};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ref.snapshots().listen((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (mounted) {
        setState(() {
          _data = snap.data() ?? <String, dynamic>{};
          _loading = false;
        });
      }
    });
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    try {
      await _ref.set(patch, SetOptions(merge: true));
    } catch (_) {
      if (mounted) {
        _toast('Gagal menyimpan. Periksa izin database.');
      }
    }
  }

  Future<Uint8List?> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 62,
    );
    if (file == null) {
      return null;
    }
    return file.readAsBytes();
  }

  Future<void> _pickRoomPhoto() async {
    setState(() => _busy = true);
    final Uint8List? picked = await _pickImage();
    if (picked == null || !mounted) {
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }
    final Uint8List? bytes = await SquareCropPage.open(context, picked);
    if (bytes == null) {
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }
    await _save(<String, dynamic>{'coverImage': base64Encode(bytes)});
    _data['coverImage'] = base64Encode(bytes);
    if (mounted) {
      setState(() => _busy = false);
      _toast('Foto room diperbarui');
    }
  }

  Future<void> _pickTheme() async {
    setState(() => _busy = true);
    final Uint8List? bytes = await _pickImage();
    if (bytes == null) {
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }
    await _save(<String, dynamic>{'themeImage': base64Encode(bytes)});
    if (mounted) {
      setState(() => _busy = false);
      _toast('Background room diperbarui');
    }
  }

  Future<void> _editText(String title, String field, String value, int max) async {
    final TextEditingController c = TextEditingController(text: value);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontSize: 16, color: _ink)),
        content: TextField(
          controller: c,
          maxLength: max,
          autofocus: true,
          style: const TextStyle(fontSize: 14, color: _ink),
          decoration: const InputDecoration(hintText: 'Tulis di sini'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: const Text('Simpan', style: TextStyle(color: _pink)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    await _save(<String, dynamic>{field: result});
    if (mounted) {
      _toast('$title disimpan');
    }
  }

  Future<void> _passwordDialog() async {
    final String current = (_data['password'] as String?) ?? '';
    final TextEditingController c = TextEditingController();
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sandi room', style: TextStyle(fontSize: 16, color: _ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              current.isEmpty
                  ? 'Masukkan 6 angka. Room otomatis terkunci dan tidak ada yang bisa masuk tanpa sandi.'
                  : 'Room sedang terkunci. Hapus sandi untuk membuat room publik lagi.',
              style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.35),
            ),
            if (current.isEmpty) ...<Widget>[
              const SizedBox(height: 14),
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 18, letterSpacing: 8, color: _ink),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: '••••••', counterText: ''),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('buka'),
              child: const Text('Jadikan publik', style: TextStyle(color: _pink)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: _muted)),
          ),
          if (current.isEmpty)
            TextButton(
              onPressed: () {
                if (c.text.length != 6) {
                  return;
                }
                Navigator.of(ctx).pop(c.text);
              },
              child: const Text('Simpan', style: TextStyle(color: _pink)),
            ),
        ],
      ),
    );
    if (action == null) {
      return;
    }
    if (action == 'buka') {
      await _save(<String, dynamic>{'password': '', 'isOpen': true});
      if (mounted) {
        _toast('Room publik lagi');
      }
      return;
    }
    await _save(<String, dynamic>{'password': action, 'isOpen': false});
    if (mounted) {
      _toast('Room terkunci dengan sandi');
    }
  }

  void _micModeSheet() {
    final String saved = (_data['micMode'] as String?) ?? '11 Mics';
    String picked = saved;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: _ink, size: 28),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            'Mic mode',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        for (final int n in <int>[9, 11, 13])
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                setSheet(() => picked = '$n Mics');
                                await _save(<String, dynamic>{
                                  'micMode': '$n Mics',
                                });
                                if (mounted) {
                                  _toast('Mic mode: $n Mics');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  children: <Widget>[
                                    _modePreview(n, picked == '$n Mics'),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$n Mics',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: picked == '$n Mics'
                                            ? const Color(0xFF00C97B)
                                            : _muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D88A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Submit',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Pratinjau tata letak kursi sesuai mode: baris host lalu baris kursi.
  Widget _modePreview(int total, bool selected) {
    final List<int> rows = roomSeatRows(total);
    int n = 0;
    return Container(
      height: 150,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0E4A47), Color(0xFF0A2E33)],
        ),
        border: Border.all(
          color: selected ? const Color(0xFF00D88A) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _dot(),
              const SizedBox(height: 6),
              for (final int count in rows) ...<Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < count; i++) ...<Widget>[
                      _dot(),
                      if (i != count - 1) const SizedBox(width: 3),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
              ],
            ],
          ),
          if (selected)
            const Center(
              child: Icon(Icons.check_circle_outline, color: Color(0xFF00D88A), size: 26),
            ),
        ],
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
    );
  }

  void _whoCanTakeMicSheet() {
    _options('Siapa yang bisa ambil mic', <String>['Anyone', 'Admin only', 'Host only'],
        (_data['micPermission'] as String?) ?? 'Anyone', (String v) async {
      await _save(<String, dynamic>{'micPermission': v});
    });
  }

  void _options(String title, List<String> items, String current, Future<void> Function(String) onPick) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            ),
            for (final String it in items)
              ListTile(
                title: Text(it, style: const TextStyle(fontSize: 14, color: _ink)),
                trailing: it == current
                    ? const Icon(Icons.check, color: _pink, size: 20)
                    : null,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await onPick(it);
                  if (mounted) {
                    _toast('$title: $it');
                  }
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openList(String title, List<String> field, String empty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RoomListPage(
          roomId: widget.roomId,
          title: title,
          field: field.first,
          emptyText: empty,
          allowUnblock: field.first == 'blacklist',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _ink, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pengaturan room',
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              children: <Widget>[
                Center(child: _photo()),
                const SizedBox(height: 18),
                _block(<Widget>[
                  _row('Nama room', (_data['title'] as String?) ?? 'Room',
                      () => _editText('Nama room', 'title', (_data['title'] as String?) ?? '', 24)),
                  _row('Pengumuman room', (_data['announcement'] as String?) ?? 'Selamat datang semua!',
                      () => _editText('Pengumuman room', 'announcement',
                          (_data['announcement'] as String?) ?? '', 80)),
                  _switchRow('Public chat', (_data['publicChat'] as bool?) ?? true,
                      (bool v) => _save(<String, dynamic>{'publicChat': v})),
                  _row(
                    'Sandi room',
                    ((_data['password'] as String?) ?? '').isEmpty ? 'Publik' : 'Terkunci',
                    _passwordDialog,
                    locked: ((_data['password'] as String?) ?? '').isNotEmpty,
                  ),
                ]),
                _block(<Widget>[
                  _row('Mic mode', (_data['micMode'] as String?) ?? '11 Mics', _micModeSheet),
                  _row('Tema room', ((_data['themeImage'] as String?) ?? '').isEmpty
                      ? 'Default'
                      : 'Sudah diunggah', _pickTheme),
                  _switchRow('Super mic', (_data['superMic'] as bool?) ?? false,
                      (bool v) => _save(<String, dynamic>{'superMic': v})),
                  _row('Siapa yang bisa ambil mic',
                      (_data['micPermission'] as String?) ?? 'Anyone', _whoCanTakeMicSheet),
                ]),
                _block(<Widget>[
                  _row('Admin', '${((_data['admins'] as List<dynamic>?) ?? <dynamic>[]).length} admin',
                      () => _openList('Admin room', <String>['admins'], 'Belum ada admin room')),
                  _row('Blacklist', '${((_data['blacklist'] as List<dynamic>?) ?? <dynamic>[]).length} user',
                      () => _openList('Blacklist', <String>['blacklist'], 'Belum ada user di blacklist')),
                ]),
                _block(<Widget>[
                  _row('Riwayat kick', '${((_data['kickHistory'] as List<dynamic>?) ?? <dynamic>[]).length} catatan',
                      () => _openList('Riwayat kick', <String>['kickHistory'], 'Belum ada riwayat kick')),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Perubahan tersimpan otomatis ke database room.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        elevation: 3,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close, color: _ink),
      ),
    );
  }

  Widget _photo() {
    final String b64 = (_data['coverImage'] as String?) ?? '';
    return Stack(
      children: <Widget>[
        Container(
          width: 116,
          height: 116,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: <Color>[_gold, Color(0xFFB08A3E)]),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: b64.isEmpty
                ? Container(
                    color: const Color(0xFFEDE9FF),
                    child: const Icon(Icons.meeting_room, color: _pink, size: 40),
                  )
                : Image.memory(base64Decode(b64), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          bottom: -6,
          right: -6,
          child: GestureDetector(
            onTap: _busy ? null : _pickRoomPhoto,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _pink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera, color: Colors.white, size: 17),
            ),
          ),
        ),
      ],
    );
  }

  Widget _block(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value, VoidCallback onTap, {bool locked = false}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, color: _ink)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (locked) const Icon(Icons.lock, size: 15, color: _muted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ),
          const Icon(Icons.chevron_right, color: _muted, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, color: _ink)),
      value: value,
      activeThumbColor: const Color(0xFF3DD68C),
      onChanged: onChanged,
    );
  }
}

/// Daftar admin / blacklist / riwayat kick.
class _RoomListPage extends StatelessWidget {
  const _RoomListPage({
    required this.roomId,
    required this.title,
    required this.field,
    required this.emptyText,
    required this.allowUnblock,
  });

  final String roomId;
  final String title;
  final String field;
  final String emptyText;
  final bool allowUnblock;

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('rooms').doc(roomId);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _ink, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
            style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
          final List<dynamic> items =
              (snap.data?.data()?[field] as List<dynamic>?) ?? <dynamic>[];
          if (items.isEmpty) {
            return Center(
              child: Text(emptyText, style: const TextStyle(fontSize: 13.5, color: _muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext ctx, int i) {
              final Map<String, dynamic> u = Map<String, dynamic>.from(items[i] as Map);
              final String name = (u['name'] as String?) ?? 'User';
              final String pid = (u['publicId']?.toString()) ?? '-';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFEDE9FF),
                      child: Icon(Icons.person, color: _pink, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(name, style: const TextStyle(fontSize: 14, color: _ink)),
                          Text('ID $pid',
                              style: const TextStyle(fontSize: 11.5, color: _muted)),
                        ],
                      ),
                    ),
                    if (allowUnblock)
                      TextButton(
                        onPressed: () async {
                          final List<dynamic> next = items
                              .where((dynamic e) =>
                                  (e as Map)['uid'] != (u['uid'] as String?))
                              .toList();
                          await ref.set(<String, dynamic>{field: next}, SetOptions(merge: true));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('$name bisa masuk room lagi')),
                            );
                          }
                        },
                        child: const Text('Buka blokir',
                            style: TextStyle(fontSize: 12, color: _pink)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Baris kursi (tidak termasuk host) menurut mode mic.
/// 9 Mics: 4-4 (+1 host di atas = 9). 11 Mics: 5-5. 13 Mics: 4-4-4.
List<int> roomSeatRows(int total) {
  switch (total) {
    case 9:
      return <int>[4, 4];
    case 13:
      return <int>[4, 4, 4];
    case 11:
    default:
      return <int>[5, 5];
  }
}

/// Jumlah kursi tamu menurut teks mode ("9 Mics").
int roomSeatCount(String mode) {
  final int total = int.tryParse(mode.split(' ').first) ?? 11;
  return roomSeatRows(total).fold<int>(0, (int a, int b) => a + b);
}
