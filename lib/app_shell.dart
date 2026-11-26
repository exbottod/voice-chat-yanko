import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import 'app_lang.dart';

import 'profile_store.dart';
import 'update_service.dart';
import 'res_image.dart';
import 'tabs_content.dart';

const Color kPinkMain = Color(0xFFF59E0B);
const Color kInkMain = Color(0xFF1F1A3D);
const Color kMutedMain = Color(0xFF8E8AA8);

/// Kerangka 5 tab: Jelajahi, Momen, Party, Pesan, Saya (sama seperti AuraVox).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 2});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;
  Map<String, dynamic>? _profile;

  static const List<String> _labels = <String>[
    'Jelajahi',
    'Momen',
    'Party',
    'Pesan',
    'Saya',
  ];
  static const List<String> _icons = <String>[
    'tabs_discover',
    'tabs_moments',
    'tabs_party',
    'tabs_messages',
    'tabs_me',
  ];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.check(context);
      }
    });
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final Map<String, dynamic>? data = await ProfileStore.load(user.uid);
    if (mounted) {
      setState(() => _profile = data ?? <String, dynamic>{});
    }
  }

  Widget _body() {
    switch (_index) {
      case 0:
        return const DiscoverContent();
      case 1:
        return const MomentsContent();
      case 2:
        return const PartyContent();
      case 3:
        return const MessagesContent();
      default:
        return MeContent(profile: _profile, onRefresh: _loadProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _body(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1EFF6))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _labels.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _index = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          ResImage(
                            '${_icons[i]}_${_index == i ? 'on' : 'off'}_v2',
                            width: 34,
                            height: 34,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _labels[i],
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight:
                                  _index == i ? FontWeight.w700 : FontWeight.w500,
                              color: _index == i ? kPinkMain : kMutedMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
