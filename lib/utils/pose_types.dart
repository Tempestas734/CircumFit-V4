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
  const PoseEstimate(this.keypoints);

  final List<PoseKeypoint> keypoints;
}
