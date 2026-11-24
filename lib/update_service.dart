import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cek versi terbaru dari server dan tampilkan dialog update.
class UpdateService {
  UpdateService._();

  static const String manifestUrl = 'https://login-9604e.web.app/latest.json';
  static const Color _card = Color(0xFF17171A);
  static const Color _gold = Color(0xFFFFC82E);
  static const Color _line = Color(0xFF6B5A1E);

  /// Pecah "1.0.68" jadi [1, 0, 68] supaya bisa dibandingkan per bagian.
  static List<int> _parts(String value) {
    return value
        .split('.')
        .map((String part) =>
            int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  /// Bandingkan versi berdasarkan nama versi (1.0.68), bukan versionCode.
  /// Ini penting karena APK split per ABI punya versionCode berbeda
  /// (armeabi-v7a 1000+x, arm64-v8a 2000+x, x86_64 3000+x).
  static bool _isNewer(String remote, String current) {
    if (remote.isEmpty || current.isEmpty) {
      return false;
    }
    final List<int> r = _parts(remote);
    final List<int> c = _parts(current);
    final int len = r.length > c.length ? r.length : c.length;
    for (int i = 0; i < len; i++) {
      final int rv = i < r.length ? r[i] : 0;
      final int cv = i < c.length ? c[i] : 0;
      if (rv != cv) {
        return rv > cv;
      }
    }
    return false;
  }

  static Future<void> check(BuildContext context) async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final int currentCode = int.tryParse(info.buildNumber) ?? 0;
      final String currentName = info.version;

      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final HttpClientRequest request =
          await client.getUrl(Uri.parse(manifestUrl));
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return;
      }
      final String body = await response.transform(utf8.decoder).join();
      client.close();

      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      final int remoteCode = (data['versionCode'] as num?)?.toInt() ?? 0;
      final String versionName = (data['versionName'] as String?) ?? '';

      final bool newer = versionName.isNotEmpty && currentName.isNotEmpty
          ? _isNewer(versionName, currentName)
          : remoteCode > currentCode;
      if (!newer) {
        return;
      }

      final String mark = versionName.isNotEmpty ? versionName : '$remoteCode';
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getString('skippedVersion') == mark) {
        final int at = prefs.getInt('skippedAt') ?? 0;
        final bool recent = DateTime.now().millisecondsSinceEpoch - at <
            const Duration(hours: 24).inMilliseconds;
        if (recent) {
          return;
        }
      }
      final String apkUrl = (data['apkUrl'] as String?) ?? '';
      final String notes = ((data['notes'] as String?) ?? '').trim();
      final int size = (data['apkSize'] as num?)?.toInt() ?? 0;
      if (apkUrl.isEmpty || !context.mounted) {
        return;
      }
      await _showDialog(context, versionName, notes, apkUrl, mark, size);
    } catch (_) {
      // Diam saja kalau offline atau server tidak bisa dihubungi.
    }
  }

  static String _mb(int bytes) =>
      '${(bytes / 1048576).toStringAsFixed(1)} MB';

  static Future<void> _showDialog(
    BuildContext context,
    String versionName,
    String notes,
    String apkUrl,
    String mark,
    int size,
  ) async {
    final String body = notes.isNotEmpty
        ? notes
        : 'Versi $versionName sudah tersedia. Perbarui untuk fitur dan perbaikan terbaru.';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.download_rounded,
                          size: 18, color: Color(0xFF17171A)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Update Available',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      body,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: Color(0xFFD9D9DE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  size > 0 ? 'Versi $versionName  ·  ${_mb(size)}' : 'Versi $versionName',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A92)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () async {
                        final SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString('skippedVersion', mark);
                        await prefs.setInt('skippedAt',
                            DateTime.now().millisecondsSinceEpoch);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: const Text(
                        'Nanti',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFBDBDC4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF17171A),
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          final Uri uri = Uri.parse(apkUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text(
                          'Update Sekarang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
      },
    );
  }
}
