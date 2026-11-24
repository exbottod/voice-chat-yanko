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
  static const Color _pink = Color(0xFFFF4F8B);
  static const Color _ink = Color(0xFF1F1A3D);

  static Future<void> check(BuildContext context) async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final int current = int.tryParse(info.buildNumber) ?? 0;

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
      final int remote = (data['versionCode'] as num?)?.toInt() ?? 0;
      if (remote <= current) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('skippedUpdate') == remote) {
        return;
      }
      final String versionName = (data['versionName'] as String?) ?? '';
      final String apkUrl = (data['apkUrl'] as String?) ?? '';
      final String notes = (data['notes'] as String?) ?? '';
      if (apkUrl.isEmpty || !context.mounted) {
        return;
      }
      await _showDialog(context, versionName, notes, apkUrl);
    } catch (_) {
      // Diam saja kalau offline atau server tidak bisa dihubungi.
    }
  }

  static Future<void> _showDialog(
    BuildContext context,
    String versionName,
    String notes,
    String apkUrl,
    int versionCode,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Update tersedia',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                versionName.isEmpty ? 'Versi baru sudah terbit.' : 'Versi $versionName sudah terbit.',
                style: const TextStyle(color: _ink),
              ),
              if (notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  notes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8AA8)),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                await prefs.setInt('skippedUpdate', versionCode);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Nanti', style: TextStyle(color: Color(0xFF8E8AA8))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _pink),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final Uri uri = Uri.parse(apkUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update sekarang'),
            ),
          ],
        );
      },
    );
  }
}
