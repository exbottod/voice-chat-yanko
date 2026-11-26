import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_page.dart';
import 'res_image.dart';

const Color _ink = Color(0xFF1F1A3D);
const Color _muted = Color(0xFF9A97B0);
const Color _bg = Color(0xFFF4F4F8);
const String _email = 'developerex100@gmail.com';

/// Tentang aplikasi: ikon, nama, versi asli dari APK, hukum, kontak, lisensi.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.onDeleteAccount});

  final VoidCallback onDeleteAccount;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((PackageInfo info) {
      if (mounted) {
        setState(() => _version = 'Versi ${info.version} (${info.buildNumber})');
      }
    });
  }

  void _legal(String title, String asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, asset: asset),
      ),
    );
  }

  Future<void> _mail() async {
    final Uri uri = Uri(scheme: 'mailto', path: _email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _row(IconData icon, String label, {String? value, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 24, color: const Color(0xFF55536A)),
            const SizedBox(width: 18),
            Text(label, style: const TextStyle(fontSize: 16, color: _ink)),
            const Spacer(),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: _muted),
                ),
              ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, size: 22, color: Color(0xFFB9B6C6)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 62, color: Color(0xFFF0EFF5));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 30, color: _ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'Tentang AuraVox',
          style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: const ResImage('icon', width: 116, height: 116),
                ),
                const SizedBox(height: 18),
                const Text(
                  'AuraVox',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _version,
                  style: const TextStyle(fontSize: 15, color: _muted),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chat suara, teman baru, room seru.',
                  style: TextStyle(fontSize: 14, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _row(
            Icons.shield_outlined,
            'Kebijakan Privasi',
            onTap: () => _legal('Kebijakan Privasi', 'assets/legal/privacy_policy.md'),
          ),
          _divider(),
          _row(
            Icons.description_outlined,
            'Ketentuan Penggunaan',
            onTap: () => _legal('Ketentuan Penggunaan', 'assets/legal/terms_of_service.md'),
          ),
          _divider(),
          _row(
            Icons.delete_outline,
            'Penghapusan akun',
            onTap: widget.onDeleteAccount,
          ),
          const SizedBox(height: 14),
          _row(Icons.mail_outline, 'Kontak', value: _email, onTap: _mail),
          _divider(),
          _row(Icons.apartment_outlined, 'Pengembang', value: 'exbottod'),
          const SizedBox(height: 14),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Lisensi open source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'AuraVox dibuat dengan Flutter, Firebase, dan komponen '
                  'open source lain. Perangkat lunak ini didistribusikan di bawah '
                  'lisensi MIT, Apache 2.0, dan BSD; hak cipta milik pemiliknya '
                  'masing-masing.',
                  style: TextStyle(fontSize: 13.5, color: _muted, height: 1.5),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                '© 2026 AuraVox',
                style: TextStyle(fontSize: 13, color: Color(0xFFB9B6C6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
