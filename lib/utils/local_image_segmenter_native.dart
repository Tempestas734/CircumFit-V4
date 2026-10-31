import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import 'local_waist_measurement.dart';
import 'pose_types.dart';

class LocalImageSegmenter {
  final SelfieSegmenter _segmenter = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: true,
  );

  Future<LocalSegmentationOutput?> segment(Uint8List encodedImage) async {
    final decoded = img.decodeImage(encodedImage);
    if (decoded == null) {
      throw const FormatException('Captured image could not be decoded.');
    }
    final oriented = img.bakeOrientation(decoded);
    final rgba = Uint8List(oriented.width * oriented.height * 4);
    var offset = 0;
    for (var y = 0; y < oriented.height; y++) {
      for (var x = 0; x < oriented.width; x++) {
        final pixel = oriented.getPixel(x, y);
        rgba[offset++] = pixel.r.toInt();
        rgba[offset++] = pixel.g.toInt();
        rgba[offset++] = pixel.b.toInt();
        rgba[offset++] = pixel.a.toInt();
      }
    }
    final inputImage = InputImage.fromBitmap(
      bitmap: rgba,
      width: oriented.width,
      height: oriented.height,
    );
    final result = await _segmenter.processImage(inputImage);
    if (result == null ||
        result.width <= 0 ||
        result.height <= 0 ||
        result.confidences.length != result.width * result.height ||
        result.confidences.any((confidence) => !confidence.isFinite)) {
      return null;
    }

    return LocalSegmentationOutput(
      mask: PoseSegmentation(
        width: result.width,
        height: result.height,
        confidences: result.confidences,
      ),
      imageWidth: oriented.width,
      imageHeight: oriented.height,
    );
  }

  Future<void> close() => _segmenter.close();
}
