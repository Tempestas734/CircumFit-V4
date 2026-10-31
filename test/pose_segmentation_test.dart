import 'package:circumfit_v3/utils/pose_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts model logits into foreground confidence', () {
    final segmentation = PoseSegmentation.fromLogits(
      width: 3,
      height: 1,
      logits: const [-2, 0, 2],
    );

    expect(segmentation.confidences[0], closeTo(0.1192, 0.0001));
    expect(segmentation.confidences[1], 0.5);
    expect(segmentation.confidences[2], closeTo(0.8808, 0.0001));
  });

  test('reports foreground cells using row-major mask coordinates', () {
    final segmentation = PoseSegmentation.fromLogits(
      width: 2,
      height: 2,
      logits: const [-1, 1, 1, -1],
    );

    expect(segmentation.hasForeground, isTrue);
    expect(segmentation.isForeground(1, 0), isTrue);
    expect(segmentation.isForeground(0, 1), isTrue);
    expect(segmentation.isForeground(0, 0), isFalse);
  });

  test('rejects invalid mask dimensions and non-finite logits', () {
    expect(
      () => PoseSegmentation.fromLogits(
        width: 2,
        height: 2,
        logits: const [0, 1],
      ),
      throwsArgumentError,
    );
    expect(
      () => PoseSegmentation.fromLogits(
        width: 1,
        height: 1,
        logits: const [double.nan],
      ),
      throwsArgumentError,
    );
  });

  test('rejects coordinates outside the mask', () {
    final segmentation = PoseSegmentation.fromLogits(
      width: 1,
      height: 1,
      logits: const [1],
    );

    expect(() => segmentation.isForeground(-1, 0), throwsRangeError);
    expect(() => segmentation.isForeground(0, 1), throwsRangeError);
  });
}
