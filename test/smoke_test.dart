import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_yanko/login_page.dart';

void main() {
  testWidgets('halaman login tampil', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.text(kBrandName), findsOneWidget);
    expect(find.text('Google Login'), findsOneWidget);
  });
}
