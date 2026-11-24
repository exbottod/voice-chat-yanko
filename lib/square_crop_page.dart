import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Layar crop 1:1: geser dan cubit gambar di dalam bingkai persegi, lalu
/// ketuk Pakai. Mengembalikan PNG persegi (512 px) atau null bila batal.
class SquareCropPage extends StatefulWidget {
  const SquareCropPage({super.key, required this.bytes});

  final Uint8List bytes;

  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => SquareCropPage(bytes: bytes),
      ),
    );
  }

  @override
  State<SquareCropPage> createState() => _SquareCropPageState();
}

class _SquareCropPageState extends State<SquareCropPage> {
  final GlobalKey _boundary = GlobalKey();
  final TransformationController _tc = TransformationController();
  bool _saving = false;
  Size? _imgSize;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.bytes, (ui.Image img) {
      if (mounted) {
        setState(() => _imgSize = Size(img.width.toDouble(), img.height.toDouble()));
      }
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final RenderRepaintBoundary b = _boundary.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      final double px = 512 / b.size.width;
      final ui.Image img = await b.toImage(pixelRatio: px);
      final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double side = MediaQuery.sizeOf(context).width - 32;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Potong 1:1', style: TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _saving || _imgSize == null ? null : _done,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Pakai',
                    style: TextStyle(
                        color: Color(0xFFFF4F8B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const Spacer(),
          Center(
            child: SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: <Widget>[
                  RepaintBoundary(
                    key: _boundary,
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: _tc,
                        minScale: 1,
                        maxScale: 6,
                        boundaryMargin: EdgeInsets.zero,
                        constrained: true,
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Geser dan cubit untuk mengatur posisi',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
