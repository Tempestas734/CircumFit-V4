import 'package:circumfit_v3/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final screenSize in [
    const Size(320, 480),
    const Size(640, 360),
  ]) {
    testWidgets(
      'keeps the start button visible on ${screenSize.width}x${screenSize.height}',
      (tester) async {
        tester.view.physicalSize = screenSize;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: BodyScanPage()),
        );

        final buttonRect = tester.getRect(find.text('Start body scan'));
        final navigationRect = tester.getRect(find.byIcon(Icons.home));

        expect(buttonRect.top, greaterThanOrEqualTo(0));
        expect(buttonRect.bottom, lessThan(screenSize.height));
        expect(buttonRect.bottom, lessThan(navigationRect.top));
      },
    );
  }
}
