import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:circumfit_v3/utils/image_crop_helper.dart';

void main() {
  test('maps the guide through a cover-cropped preview', () async {
    final source = img.Image(width: 200, height: 100);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));

    final cropped = await cropImageToGuide(
      imageBytes: Uint8List.fromList(img.encodePng(source)),
      viewportSize: const Size(100, 100),
      guideRect: const Rect.fromLTWH(25, 25, 50, 50),
      mirrorHorizontally: false,
    );

    final decoded = img.decodeImage(cropped);
    expect(decoded, isNotNull);
    expect(decoded!.width, 50);
    expect(decoded.height, 50);
  });

  test('mirrors a front-camera capture before saving the crop', () async {
    final source = img.Image(width: 200, height: 100);
    img.fillRect(
      source,
      x1: 0,
      y1: 0,
      x2: 99,
      y2: 99,
      color: img.ColorRgb8(255, 0, 0),
    );
    img.fillRect(
      source,
      x1: 100,
      y1: 0,
      x2: 199,
      y2: 99,
      color: img.ColorRgb8(0, 0, 255),
    );

    final cropped = await cropImageToGuide(
      imageBytes: Uint8List.fromList(img.encodePng(source)),
      viewportSize: const Size(100, 100),
      guideRect: const Rect.fromLTWH(0, 25, 20, 50),
      mirrorHorizontally: true,
    );

    final decoded = img.decodeImage(cropped);
    expect(decoded, isNotNull);
    final pixel = decoded!.getPixel(5, decoded.height ~/ 2);
    expect(pixel.b, greaterThan(pixel.r));
  });

  test('applies the selected exposure to the saved crop', () async {
    final source = img.Image(width: 100, height: 100);
    img.fill(source, color: img.ColorRgb8(80, 80, 80));

    final cropped = await cropImageToGuide(
      imageBytes: Uint8List.fromList(img.encodePng(source)),
      viewportSize: const Size(100, 100),
      guideRect: const Rect.fromLTWH(0, 0, 100, 100),
      mirrorHorizontally: false,
      exposure: 1,
    );

    final pixel = img.decodeImage(cropped)!.getPixel(50, 50);
    expect(pixel.r, greaterThan(140));
    expect(pixel.g, greaterThan(140));
    expect(pixel.b, greaterThan(140));
  });
}
