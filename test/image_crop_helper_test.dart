import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:circumfit_v3/utils/image_crop_helper.dart';

void main() {
  test('maps the guide through a cover-cropped preview', () async {
    final source = img.Image(width: 200, height: 100);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));
    final sourceFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'circumfit_crop_source.png',
    );
    await sourceFile.writeAsBytes(img.encodePng(source));

    final cropped = await cropImageToGuide(
      imagePath: sourceFile.path,
      viewportSize: const Size(100, 100),
      guideRect: const Rect.fromLTWH(25, 25, 50, 50),
      mirrorHorizontally: false,
    );

    final decoded = img.decodeImage(await cropped.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 50);
    expect(decoded.height, 50);
    await sourceFile.delete();
    await cropped.delete();
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
    final sourceFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'circumfit_crop_mirror_source.png',
    );
    await sourceFile.writeAsBytes(img.encodePng(source));

    final cropped = await cropImageToGuide(
      imagePath: sourceFile.path,
      viewportSize: const Size(100, 100),
      guideRect: const Rect.fromLTWH(0, 25, 20, 50),
      mirrorHorizontally: true,
    );

    final decoded = img.decodeImage(await cropped.readAsBytes());
    expect(decoded, isNotNull);
    final pixel = decoded!.getPixel(5, decoded.height ~/ 2);
    expect(pixel.b, greaterThan(pixel.r));
    await sourceFile.delete();
    await cropped.delete();
  });
}
