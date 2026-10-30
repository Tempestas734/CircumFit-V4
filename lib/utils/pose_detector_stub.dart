import 'package:camera/camera.dart';

import 'pose_types.dart';

class PoseDetector {
  static Future<PoseDetector> load() async {
    throw UnsupportedError(
      'Live pose detection is only available on iOS and Android.',
    );
  }

  Future<PoseEstimate> estimate(CameraImage cameraImage) {
    throw UnsupportedError(
      'Live pose detection is only available on iOS and Android.',
    );
  }

  Future<void> close() async {}
}
