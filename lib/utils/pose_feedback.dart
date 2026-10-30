import 'dart:ui';

import 'pose_types.dart';

class PoseFeedback {
  const PoseFeedback({required this.isReady, required this.message});

  final bool isReady;
  final String? message;

  static const _minimumConfidence = 0.35;

  static PoseFeedback evaluate({
    required PoseEstimate pose,
    required Rect guideRect,
  }) {
    const groups = <_LandmarkGroup>[
      _LandmarkGroup('épaules', [5, 6]),
      _LandmarkGroup('mains', [9, 10]),
      _LandmarkGroup('pieds', [15, 16]),
    ];
    final problems = <String>[];
    var detectedGroups = 0;

    for (final group in groups) {
      final visiblePoints = group.indices
          .map((index) => pose.keypoints[index])
          .where(
            (point) =>
                point.confidence >= _minimumConfidence &&
                point.x.isFinite &&
                point.y.isFinite,
          )
          .toList(growable: false);
      if (visiblePoints.isEmpty) continue;

      detectedGroups++;
      if (visiblePoints.any(
        (point) =>
            point.x < guideRect.left ||
            point.x > guideRect.right ||
            point.y < guideRect.top ||
            point.y > guideRect.bottom,
      )) {
        problems.add(group.label);
      }
    }

    if (detectedGroups == 0) {
      return const PoseFeedback(
        isReady: false,
        message:
            'Les épaules, les mains et les pieds ne sont pas détectés. Placez-vous dans la silhouette.',
      );
    }
    if (problems.isNotEmpty) {
      return PoseFeedback(
        isReady: false,
        message: 'Gardez les ${problems.join(', ')} dans la silhouette.',
      );
    }
    if (detectedGroups < groups.length) {
      final missing = groups
          .where(
            (group) => !group.indices.any(
              (index) => pose.keypoints[index].confidence >= _minimumConfidence,
            ),
          )
          .map((group) => group.label)
          .toList(growable: false);
      return PoseFeedback(
        isReady: false,
        message: 'Gardez les ${missing.join(', ')} visibles.',
      );
    }

    return const PoseFeedback(
      isReady: true,
      message: 'Bonne position : épaules, mains et pieds sont visibles.',
    );
  }
}

class _LandmarkGroup {
  const _LandmarkGroup(this.label, this.indices);

  final String label;
  final List<int> indices;
}
