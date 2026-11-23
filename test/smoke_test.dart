import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_yanko/main.dart';

void main() {
  testWidgets('judul aplikasi tampil', (WidgetTester tester) async {
    await tester.pumpWidget(const YankoApp());
    expect(find.text('Voice Chat Yanko'), findsOneWidget);
  });
}
