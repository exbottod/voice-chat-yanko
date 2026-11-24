import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'legal_page.dart';
import 'login_page.dart';
import 'profile_store.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF9A97B0);
const Color _pink = Color(0xFFFF4F8B);
const Color _bg = Color(0xFFF4F4F8);

/// Layar Setelan: bahasa, sapaan, mode lite, privasi, akun, izin, hukum.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SharedPreferences? _prefs;
  String _version = '';
  String _cache = '...';
  List<String> _blocked = <String>[];

  static const List<String> _languages = <String>[
    'Bahasa Indonesia',
    'English',
    'Melayu',
    'Turkce',
    'Arabic',
  ];
  static const List<String> _greetings = <String>[
    'Default',
    'Halo!',
    'Hai, apa kabar?',
    'Selamat datang!',
  ];
  static const List<String> _callPolicy = <String>[
    'Semua orang',
    'Teman saja',
    'Tidak ada',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String cache = await _cacheSize();
    if (!mounted) {
      return;
    }
    setState(() {
      _prefs = prefs;
      _version = 'v${info.version}';
      _cache = cache;
      _blocked = prefs.getStringList('blocked') ?? <String>[];
    });
  }

  Future<String> _cacheSize() async {
    try {
      final Directory dir = await getTemporaryDirectory();
      int total = 0;
      if (await dir.exists()) {
        await for (final FileSystemEntity f
            in dir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            total += await f.length();
          }
        }
      }
      final double mb = total / 1048576;
      return '${mb.toStringAsFixed(1)} MB';
    } catch (_) {
      return '0 MB';
    }
  }

  String _str(String key, String fallback) =>
      _prefs?.getString(key) ?? fallback;
  bool _bool(String key, bool fallback) => _prefs?.getBool(key) ?? fallback;

  Future<void> _setStr(String key, String value) async {
    await _prefs?.setString(key, value);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
    if (mounted) {
      setState(() {});
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pick(
    String title,
    String key,
    List<String> options,
    String fallback,
  ) async {
    final String current = _str(key, fallback);
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheet) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              for (final String o in options)
                ListTile(
                  title: Text(o, style: const TextStyle(color: _ink)),
                  trailing: o == current
                      ? const Icon(Icons.check, color: _pink)
                      : null,
                  onTap: () => Navigator.of(sheet).pop(o),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null) {
      await _setStr(key, chosen);
    }
  }

  Future<void> _lockedSwitch(String key, String label) async {
    _toast('$label hanya untuk anggota Bangsawan / SVIP.');
  }

  Future<void> _openBlocked() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BlockedPage(
          initial: _blocked,
          onChanged: (List<String> list) async {
            await _prefs?.setStringList('blocked', list);
            if (mounted) {
              setState(() => _blocked = list);
            }
          },
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isGoogle = user?.providerData
            .any((UserInfo p) => p.providerId == 'google.com') ??
        false;
    if (isGoogle || user?.email == null) {
      _toast('Akun ini masuk dengan Google, jadi tidak memakai kata sandi.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      _toast('Tautan ubah kata sandi dikirim ke ${user.email}');
    } catch (e) {
      _toast('Gagal mengirim: $e');
    }
  }

  Future<void> _clearCache() async {
    final bool? ok = await _confirm(
      'Hapus cache?',
      'File sementara ($_cache) akan dihapus. Akunmu tidak terpengaruh.',
      'Hapus',
    );
    if (ok != true) {
      return;
    }
    try {
      final Directory dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        for (final FileSystemEntity f in dir.listSync()) {
          try {
            await f.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    final String size = await _cacheSize();
    if (mounted) {
      setState(() => _cache = size);
      _toast('Cache dihapus');
    }
  }

  Future<bool?> _confirm(String title, String body, String yes) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Batal', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(yes, style: const TextStyle(color: _pink)),
          ),
        ],
      ),
    );
  }

  void _legal(String title, String asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, asset: asset),
      ),
    );
  }

  Future<void> _rate() async {
    final Uri uri = Uri.parse('https://login-9604e.web.app/download');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _feedback() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'developerex100@gmail.com',
      queryParameters: <String, String>{
        'subject': 'Masukan Voice Chat Yanko $_version',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Kirim masukan ke developerex100@gmail.com');
    }
  }

  Future<void> _about() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    showAboutDialog(
      context: context,
      applicationName: 'Voice Chat Yanko',
      applicationVersion: 'v${info.version} (${info.buildNumber})',
      applicationLegalese: 'Kontak: developerex100@gmail.com',
    );
  }

  Future<void> _deleteAccount() async {
    final bool? ok = await _confirm(
      'Hapus akun?',
      'Akun dan profilmu akan dihapus permanen dan tidak bisa dikembalikan.',
      'Hapus akun',
    );
    if (ok != true) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      await ProfileStore.deleteProfile(user.uid);
      await user.delete();
      await AuthService.signOut();
      _backToLogin();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _toast('Demi keamanan, keluar lalu masuk lagi sebelum menghapus akun.');
      } else {
        _toast('Gagal menghapus akun: ${e.message}');
      }
    } catch (e) {
      _toast('Gagal menghapus akun: $e');
    }
  }

  Future<void> _logout() async {
    final bool? ok = await _confirm('Keluar?', 'Kamu akan keluar dari akun ini.', 'Keluar');
    if (ok != true) {
      return;
    }
    await AuthService.signOut();
    _backToLogin();
  }

  void _backToLogin() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String email = FirebaseAuth.instance.currentUser?.email ?? '-';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: _ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Setelan',
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 24),
        children: <Widget>[
          _group(<Widget>[
            _nav('Bahasa', _str('lang', 'Bahasa Indonesia'),
                () => _pick('Bahasa', 'lang', _languages, 'Bahasa Indonesia')),
            _nav('Sapaan', _str('greeting', 'Default'),
                () => _pick('Sapaan', 'greeting', _greetings, 'Default')),
            _switch('Mode Lite', _bool('lite', false),
                (bool v) => _setBool('lite', v)),
          ]),
          _note(
            'Hemat data dan baterai: lebih sedikit animasi berat, thumbnail lebih kecil. Suara dan panggilan tidak berubah.',
          ),
          _header('Privasi'),
          _group(<Widget>[
            _nav('Siapa yang bisa menelepon saya', _str('callWho', 'Semua orang'),
                () => _pick('Siapa yang bisa menelepon saya', 'callWho', _callPolicy, 'Semua orang')),
            _nav('Pengguna yang diblokir',
                _blocked.isEmpty ? '' : '${_blocked.length}', _openBlocked),
          ]),
          _note(
            'Panggilan suara dan video tidak direkam. Orang yang kamu blokir tidak akan pernah bisa menelepon mu.',
          ),
          _header('Keistimewaan privasi'),
          _group(<Widget>[
            _premium('Kunjungan tak terlihat', 'SVIP / Bangsawan'),
            _premium('Masuk room tak terlihat', 'Bangsawan'),
            _premium('Status online tak terlihat', 'Bangsawan'),
            _premium('Tersembunyi di peringkat', 'Bangsawan'),
          ]),
          _note(
            'Ketuk baris untuk melihat detail dan keanggotaan yang diperlukan. Setelan ini berhenti berfungsi otomatis saat keanggotaanmu berakhir.',
          ),
          _header('Akun'),
          _group(<Widget>[
            _plain('Email', email),
            _nav('Ubah kata sandi', '', _changePassword),
            _nav('Hapus cache', _cache, _clearCache),
          ]),
          _header('Izin saya'),
          _group(<Widget>[
            _switch('Bantu kami meningkatkan aplikasi (pengukuran)',
                _bool('analytics', true), (bool v) => _setBool('analytics', v)),
          ]),
          _note(
            'Ini opsional: kamu bisa memakai aplikasi dengan cara yang sama tanpa semua ini dan mengubahnya kapan saja di Pengaturan.',
          ),
          _header('Hukum'),
          _group(<Widget>[
            _nav('Kebijakan Privasi', '',
                () => _legal('Kebijakan Privasi', 'assets/legal/privacy_policy.md')),
            _nav('Ketentuan Penggunaan', '',
                () => _legal('Ketentuan Penggunaan', 'assets/legal/terms_of_service.md')),
          ]),
          const SizedBox(height: 12),
          _group(<Widget>[
            _nav('Nilai Yanko', '', _rate),
            _nav('Kirim masukan', '', _feedback),
            _nav('Tentang Yanko', _version, _about),
            _nav('Hapus akun', '', _deleteAccount, red: true),
          ]),
          const SizedBox(height: 12),
          _group(<Widget>[
            InkWell(
              onTap: _logout,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Center(
                  child: Text(
                    'Keluar',
                    style: TextStyle(
                      color: Color(0xFFE5484D),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _group(List<Widget> rows) {
    return Container(
      color: Colors.white,
      child: Column(children: rows),
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.35),
      ),
    );
  }

  Widget _nav(String label, String value, VoidCallback onTap, {bool red = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: red ? const Color(0xFFE5484D) : _ink,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBDBBC8)),
          ],
        ),
      ),
    );
  }

  Widget _plain(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 15, color: _ink)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15, color: _ink)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _pink,
          ),
        ],
      ),
    );
  }

  Widget _premium(String label, String badge) {
    return InkWell(
      onTap: () => _lockedSwitch(label, label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15, color: _ink)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFD2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(fontSize: 10, color: Color(0xFFB07A00)),
              ),
            ),
            const SizedBox(width: 6),
            IgnorePointer(
              child: Switch(
                value: false,
                onChanged: (_) {},
                activeTrackColor: _pink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedPage extends StatefulWidget {
  const _BlockedPage({required this.initial, required this.onChanged});

  final List<String> initial;
  final Future<void> Function(List<String>) onChanged;

  @override
  State<_BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends State<_BlockedPage> {
  late List<String> _list;
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _list = List<String>.from(widget.initial);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String id = _input.text.trim();
    if (id.isEmpty || _list.contains(id)) {
      return;
    }
    setState(() => _list = <String>[..._list, id]);
    _input.clear();
    await widget.onChanged(_list);
  }

  Future<void> _remove(String id) async {
    setState(() => _list = _list.where((String e) => e != id).toList());
    await widget.onChanged(_list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: _ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Pengguna yang diblokir',
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Masukkan ID pengguna',
                      filled: true,
                      fillColor: _bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _pink),
                  onPressed: _add,
                  child: const Text('Blokir'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _list.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada pengguna yang diblokir',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : ListView(
                    children: <Widget>[
                      for (final String id in _list)
                        ListTile(
                          tileColor: Colors.white,
                          title: Text('ID: $id'),
                          trailing: TextButton(
                            onPressed: () => _remove(id),
                            child: const Text(
                              'Buka blokir',
                              style: TextStyle(color: _pink),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
