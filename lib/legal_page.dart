import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_page.dart' show kBrand, kInk;

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.asset});

  final String title;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kInk,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kBrand));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: _buildBlocks(snapshot.data!),
          );
        },
      ),
    );
  }

  List<Widget> _buildBlocks(String text) {
    final List<Widget> widgets = <Widget>[];
    for (final String line in text.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 10));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Text(
          trimmed.substring(2),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ));
        widgets.add(const SizedBox(height: 8));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            trimmed.substring(3),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
        ));
      } else {
        widgets.add(Text(
          trimmed,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.55,
            color: Colors.black87,
          ),
        ));
        widgets.add(const SizedBox(height: 4));
      }
    }
    return widgets;
  }
}
