// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:speakbeat/main.dart';

void main() {
  testWidgets('SpeakBeat initial UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SpeakBeatApp());

    // App title
    expect(find.text('说话的节拍器'), findsOneWidget);

    // Current beat starts from 1
    expect(find.text('1'), findsWidgets);

    // Start button label
    expect(find.text('开始'), findsOneWidget);

    // BPM label default 60
    expect(find.textContaining('速度 (BPM): 60'), findsOneWidget);
  });
}
