import 'package:flutter/material.dart';

import 'main.dart';
import 'net_status.dart';
import 'room_page.dart';

/// Membuka room dengan bulatan loading yang tampil seketika, jadi ketukan
/// terasa langsung merespons walau pemeriksaan jaringan masih berjalan.
Future<void> bukaRoom(BuildContext context, Room room) async {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  OverlayEntry? entry;
  if (overlay != null) {
    entry = OverlayEntry(builder: (_) => const _MemuatRoom());
    overlay.insert(entry);
  }
  try {
    final bool online = await ensureOnline(context);
    if (!online || !context.mounted) {
      return;
    }
    unawaitedPush(context, room);
    // Biarkan bulatan menutup peralihan layar, lalu dilepas oleh room.
    await Future<void>.delayed(const Duration(milliseconds: 320));
  } finally {
    entry?.remove();
    entry = null;
  }
}

/// Dorong halaman room tanpa menunggu halaman ditutup.
void unawaitedPush(BuildContext context, Room room) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => RoomPage(room: room)),
  );
}

class _MemuatRoom extends StatelessWidget {
  const _MemuatRoom();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0B0418),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFFF4D8D),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Membuka room...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
