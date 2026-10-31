import 'dart:math' as math;
import 'dart:ui';

import 'pose_types.dart';

class LocalSegmentationOutput {
  const LocalSegmentationOutput({
    required this.mask,
    required this.imageWidth,
    required this.imageHeight,
  });

  final PoseSegmentation mask;
  final int imageWidth;
  final int imageHeight;
}

class LocalWaistMeasurements {
  static double? estimateWaistWidthCm({
    required PoseEstimate pose,
    required LocalSegmentationOutput segmentation,
    required Size viewportSize,
    required Rect guideRect,
    required double heightCm,
    required bool mirrorHorizontally,
  }) {
    final mask = segmentation.mask;
    if (mask.width <= 0 ||
        mask.height <= 0 ||
        mask.confidences.length != mask.width * mask.height ||
        segmentation.imageWidth <= 0 ||
        segmentation.imageHeight <= 0 ||
        !heightCm.isFinite ||
        heightCm <= 0 ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        guideRect.width <= 0 ||
        guideRect.height <= 0) {
      return null;
    }

    Offset? cropPoint(int index) {
      if (index >= pose.keypoints.length) return null;
      final point = pose.keypoints[index];
      if (!point.x.isFinite ||
          !point.y.isFinite ||
          !point.confidence.isFinite ||
          point.confidence < 0.35) {
        return null;
      }

      var x = (point.x * viewportSize.width - guideRect.left) / guideRect.width;
      final y =
          (point.y * viewportSize.height - guideRect.top) / guideRect.height;
      if (mirrorHorizontally) x = 1 - x;
      if (x < 0 || x > 1 || y < 0 || y > 1) return null;
      return Offset(x, y);
    }

    final nose = cropPoint(0);
    final leftShoulder = cropPoint(5);
    final rightShoulder = cropPoint(6);
    final leftHip = cropPoint(11);
    final rightHip = cropPoint(12);
    final leftAnkle = cropPoint(15);
    final rightAnkle = cropPoint(16);
    if (nose == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return null;
    }

    final shoulderY = (leftShoulder.dy + rightShoulder.dy) / 2;
    final ankleY = (leftAnkle.dy + rightAnkle.dy) / 2;
    if (ankleY <= shoulderY) return null;

    final headY = nose.dy + (nose.dy - ankleY) * 0.1;
    final waistY = shoulderY + (ankleY - shoulderY) * 0.25;
    final waistX = (leftHip.dx + rightHip.dx) / 2;
    if (headY < 0 ||
        headY >= ankleY ||
        waistY < 0 ||
        waistY >= 1 ||
        waistX < 0 ||
        waistX > 1) {
      return null;
    }

    final row = (waistY * mask.height).floor().clamp(0, mask.height - 1);
    final center = (waistX * mask.width).floor().clamp(0, mask.width - 1);
    bool isForeground(int x) => mask.isForeground(x, row);

    var seed = isForeground(center) ? center : -1;
    final searchRadius = (mask.width * 0.05).ceil();
    for (var distance = 1; seed < 0 && distance <= searchRadius; distance++) {
      final left = center - distance;
      final right = center + distance;
      if (left >= 0 && isForeground(left)) {
        seed = left;
      } else if (right < mask.width && isForeground(right)) {
        seed = right;
      }
    }
    if (seed < 0) return null;

    var left = seed;
    var right = seed;
    while (left > 0 && isForeground(left - 1)) {
      left--;
    }
    while (right < mask.width - 1 && isForeground(right + 1)) {
      right++;
    }
    final widthInMaskPixels = right - left + 1;
    if (widthInMaskPixels / mask.width > 0.9) return null;

    final waistWidthPixels =
        widthInMaskPixels * segmentation.imageWidth / mask.width;
    final personHeightPixels = (ankleY - headY) * segmentation.imageHeight;
    if (personHeightPixels <= 0) return null;

    final widthCm = waistWidthPixels * heightCm / personHeightPixels;
    return widthCm.isFinite && widthCm > 0 ? widthCm : null;
  }

  static LocalWaistMeasurement? calculate({
    required double? frontWidthCm,
    required double? sideWidthCm,
    required double heightCm,
  }) {
    if (frontWidthCm == null ||
        sideWidthCm == null ||
        !frontWidthCm.isFinite ||
        !sideWidthCm.isFinite ||
        frontWidthCm <= 0 ||
        sideWidthCm <= 0 ||
        !heightCm.isFinite ||
        heightCm <= 0) {
      return null;
    }

    final r1Cm = frontWidthCm / 2;
    final r2Cm = sideWidthCm / 2;
    final h = math.pow(r1Cm - r2Cm, 2) / math.pow(r1Cm + r2Cm, 2);
    final circumference =
        math.pi * (r1Cm + r2Cm) * (1 + (3 * h) / (10 + math.sqrt(4 - 3 * h)));
    if (!circumference.isFinite || circumference <= 0) return null;

    final bri = calculateBri(
      circumferenceCm: circumference,
      heightCm: heightCm,
    );
    return LocalWaistMeasurement(
      circumferenceCm: circumference,
      bri: bri,
    );
  }

  static double? calculateBri({
    required double circumferenceCm,
    required double heightCm,
  }) {
    if (!circumferenceCm.isFinite ||
        !heightCm.isFinite ||
        circumferenceCm <= 0 ||
        heightCm <= 0) {
      return null;
    }

    final ratio = circumferenceCm / (math.pi * heightCm);
    if (!ratio.isFinite || ratio >= 1) return null;
    return 364.2 - 365.5 * math.sqrt(1 - math.pow(ratio, 2));
  }
}

class LocalWaistMeasurement {
  const LocalWaistMeasurement({
    required this.circumferenceCm,
    required this.bri,
  });

  final double circumferenceCm;
  final double? bri;
}
