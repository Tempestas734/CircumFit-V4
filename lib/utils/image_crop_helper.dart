import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

Future<File> cropImageToGuide({
  required String imagePath,
  required Size viewportSize,
  required Rect guideRect,
  required bool mirrorHorizontally,
}) async {
  final bytes = await File(imagePath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException("The captured image could not be decoded.");
  }

  var oriented = img.bakeOrientation(decoded);
  if (mirrorHorizontally) {
    oriented = img.flipHorizontal(oriented);
  }

  // BoxFit.cover scales the source until it covers the preview viewport.
  final scale = math.max(
    viewportSize.width / oriented.width,
    viewportSize.height / oriented.height,
  );
  final displayedWidth = oriented.width * scale;
  final displayedHeight = oriented.height * scale;
  final offsetX = (displayedWidth - viewportSize.width) / 2;
  final offsetY = (displayedHeight - viewportSize.height) / 2;

  final left =
      ((guideRect.left + offsetX) / scale).floor().clamp(0, oriented.width - 1);
  final top =
      ((guideRect.top + offsetY) / scale).floor().clamp(0, oriented.height - 1);
  final right = ((guideRect.right + offsetX) / scale)
      .ceil()
      .clamp(left + 1, oriented.width);
  final bottom = ((guideRect.bottom + offsetY) / scale)
      .ceil()
      .clamp(top + 1, oriented.height);

  final cropped = img.copyCrop(
    oriented,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  final output = File(
    "${Directory.systemTemp.path}${Platform.pathSeparator}"
    "circumfit_${DateTime.now().microsecondsSinceEpoch}.jpg",
  );
  await output.writeAsBytes(img.encodeJpg(cropped, quality: 95), flush: true);
  return output;
}
