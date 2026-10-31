import 'dart:math' as math;

class PoseKeypoint {
  const PoseKeypoint({
    required this.x,
    required this.y,
    required this.confidence,
  });

  final double x;
  final double y;
  final double confidence;
}

class PoseEstimate {
  const PoseEstimate(this.keypoints, {this.segmentation});

  final List<PoseKeypoint> keypoints;
  final PoseSegmentation? segmentation;
}

class PoseSegmentation {
  const PoseSegmentation({
    required this.width,
    required this.height,
    required this.confidences,
  })  : assert(width > 0),
        assert(height > 0),
        assert(confidences.length == width * height);

  factory PoseSegmentation.fromLogits({
    required int width,
    required int height,
    required List<double> logits,
  }) {
    if (width <= 0 ||
        height <= 0 ||
        logits.length != width * height ||
        logits.any((logit) => !logit.isFinite)) {
      throw ArgumentError(
          'Segmentation logits have invalid dimensions or values.');
    }

    return PoseSegmentation(
      width: width,
      height: height,
      confidences: [
        for (final logit in logits)
          if (logit >= 0)
            1 / (1 + math.exp(-logit))
          else
            math.exp(logit) / (1 + math.exp(logit)),
      ],
    );
  }

  final int width;
  final int height;
  final List<double> confidences;

  bool get hasForeground => confidences.any((confidence) => confidence >= 0.5);

  bool isForeground(int x, int y, {double threshold = 0.5}) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('Segmentation coordinates are outside the mask.');
    }
    return confidences[y * width + x] >= threshold;
  }
}
