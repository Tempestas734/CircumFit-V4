import 'package:circumfit_v3/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('body scan home shows its primary action and navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BodyScanPage()),
    );

    expect(find.text('Welcome back on,'), findsOneWidget);
    expect(find.byKey(const Key('start_body_scan')), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
