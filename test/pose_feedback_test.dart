import 'dart:ui';

import 'package:circumfit_v3/utils/pose_feedback.dart';
import 'package:circumfit_v3/utils/pose_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guideRect = Rect.fromLTRB(0.15, 0.05, 0.85, 0.75);

  test('accepts a pose with all measured landmarks inside the guide', () {
    final feedback = PoseFeedback.evaluate(
      pose: _pose(),
      guideRect: guideRect,
    );

    expect(feedback.isReady, isTrue);
    expect(feedback.message, contains('Bonne position'));
  });

  test('warns when a hand is outside the guide', () {
    final feedback = PoseFeedback.evaluate(
      pose: _pose(outside: const {9}),
      guideRect: guideRect,
    );

    expect(feedback.isReady, isFalse);
    expect(feedback.message, contains('mains'));
  });

  test('asks for visible landmarks when PoseNet cannot find them', () {
    final feedback = PoseFeedback.evaluate(
      pose: _pose(missing: const {5, 6, 9, 10, 15, 16}),
      guideRect: guideRect,
    );

    expect(feedback.isReady, isFalse);
    expect(feedback.message, contains('épaules'));
    expect(feedback.message, contains('mains'));
    expect(feedback.message, contains('pieds'));
  });
}

PoseEstimate _pose({
  Set<int> outside = const {},
  Set<int> missing = const {},
}) {
  return PoseEstimate([
    for (var index = 0; index < 17; index++)
      PoseKeypoint(
        x: outside.contains(index) ? 0.95 : 0.5,
        y: 0.4,
        confidence: missing.contains(index) ? 0 : 0.9,
      ),
  ]);
}
