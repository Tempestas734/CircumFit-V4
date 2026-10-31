import 'dart:ui';
import 'dart:math' as math;

import 'package:circumfit_v3/utils/local_waist_measurement.dart';
import 'package:circumfit_v3/utils/pose_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates waist width from the contiguous mask at the waist row', () {
    final keypoints = List<PoseKeypoint>.generate(
      17,
      (_) => const PoseKeypoint(x: 0.5, y: 0.5, confidence: 1),
    );
    keypoints[0] = const PoseKeypoint(x: 0.5, y: 0.2, confidence: 1);
    keypoints[5] = const PoseKeypoint(x: 0.4, y: 0.35, confidence: 1);
    keypoints[6] = const PoseKeypoint(x: 0.6, y: 0.35, confidence: 1);
    keypoints[11] = const PoseKeypoint(x: 0.48, y: 0.6, confidence: 1);
    keypoints[12] = const PoseKeypoint(x: 0.52, y: 0.6, confidence: 1);
    keypoints[15] = const PoseKeypoint(x: 0.45, y: 0.9, confidence: 1);
    keypoints[16] = const PoseKeypoint(x: 0.55, y: 0.9, confidence: 1);

    final mask = List<double>.filled(20 * 20, 0);
    for (var x = 7; x <= 12; x++) {
      mask[9 * 20 + x] = 0.9;
    }

    final width = LocalWaistMeasurements.estimateWaistWidthCm(
      pose: PoseEstimate(keypoints),
      segmentation: LocalSegmentationOutput(
        mask: PoseSegmentation(width: 20, height: 20, confidences: mask),
        imageWidth: 200,
        imageHeight: 200,
      ),
      viewportSize: const Size(100, 100),
      guideRect: const Rect.fromLTWH(0, 0, 100, 100),
      heightCm: 180,
      mirrorHorizontally: false,
    );

    expect(width, closeTo(60 * 180 / 154, 0.001));
  });

  test('returns null when the waist row has no nearby foreground', () {
    final keypoints = List<PoseKeypoint>.generate(
      17,
      (_) => const PoseKeypoint(x: 0.5, y: 0.5, confidence: 1),
    );
    keypoints[0] = const PoseKeypoint(x: 0.5, y: 0.2, confidence: 1);
    keypoints[5] = const PoseKeypoint(x: 0.4, y: 0.35, confidence: 1);
    keypoints[6] = const PoseKeypoint(x: 0.6, y: 0.35, confidence: 1);
    keypoints[11] = const PoseKeypoint(x: 0.48, y: 0.6, confidence: 1);
    keypoints[12] = const PoseKeypoint(x: 0.52, y: 0.6, confidence: 1);
    keypoints[15] = const PoseKeypoint(x: 0.45, y: 0.9, confidence: 1);
    keypoints[16] = const PoseKeypoint(x: 0.55, y: 0.9, confidence: 1);

    expect(
      LocalWaistMeasurements.estimateWaistWidthCm(
        pose: PoseEstimate(keypoints),
        segmentation: LocalSegmentationOutput(
          mask: PoseSegmentation(
            width: 20,
            height: 20,
            confidences: List<double>.filled(20 * 20, 0),
          ),
          imageWidth: 200,
          imageHeight: 200,
        ),
        viewportSize: const Size(100, 100),
        guideRect: const Rect.fromLTWH(0, 0, 100, 100),
        heightCm: 180,
        mirrorHorizontally: false,
      ),
      isNull,
    );
  });

  test('calculates the local circumference and BRI with Ramanujan II', () {
    final result = LocalWaistMeasurements.calculate(
      frontWidthCm: 40,
      sideWidthCm: 40,
      heightCm: 170,
    );

    expect(result, isNotNull);
    final expectedCircumference = 2 * 3.141592653589793 * 20;
    final ratio = expectedCircumference / (3.141592653589793 * 170);
    expect(result!.circumferenceCm, closeTo(expectedCircumference, 0.001));
    expect(
      result.bri,
      closeTo(364.2 - 365.5 * math.sqrt(1 - ratio * ratio), 0.001),
    );
  });

  test('uses the Thomas square-root BRI formula', () {
    const circumferenceCm = 85.0;
    const heightCm = 170.0;
    final ratio = circumferenceCm / (3.141592653589793 * heightCm);

    expect(
      LocalWaistMeasurements.calculateBri(
        waistCircumferenceCm: circumferenceCm,
        heightCm: heightCm,
      ),
      closeTo(364.2 - 365.5 * math.sqrt(1 - ratio * ratio), 0.001),
    );
  });

  test('does not calculate circumference without both views', () {
    expect(
      LocalWaistMeasurements.calculate(
        frontWidthCm: 40,
        sideWidthCm: null,
        heightCm: 170,
      ),
      isNull,
    );
  });
}
