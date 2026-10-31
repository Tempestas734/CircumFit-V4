import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'pose_types.dart';

const _segmentationWidth = 17;
const _segmentationHeight = 23;

class PoseDetector {
  PoseDetector._(this._isolate, this._workerPort);

  final Isolate _isolate;
  final SendPort _workerPort;
  bool _isClosed = false;

  static const _workerTimeout = Duration(seconds: 20);
  static const _keypointCount = 17;

  static Future<PoseDetector> load() async {
    final model = await rootBundle.load('assets/posenet.tflite');
    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _poseWorkerEntry,
      <String, Object>{
        'modelBytes': TransferableTypedData.fromList(
          [model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes)],
        ),
        'readyPort': readyPort.sendPort,
      },
    );

    try {
      final response = await readyPort.first.timeout(_workerTimeout);
      if (response is! Map || response['workerPort'] is! SendPort) {
        final error = response is Map ? response['error'] : null;
        throw StateError('Pose model failed to initialize: $error');
      }
      return PoseDetector._(
        isolate,
        response['workerPort'] as SendPort,
      );
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    } finally {
      readyPort.close();
    }
  }

  Future<PoseEstimate> estimate(CameraImage cameraImage) async {
    if (_isClosed) {
      throw StateError('Pose detector has already been closed.');
    }

    return _estimate(<String, Object>{
      'width': cameraImage.width,
      'height': cameraImage.height,
      'format': cameraImage.format.group.name,
      'planes': cameraImage.planes
          .map(
            (plane) => <String, Object>{
              'bytes': TransferableTypedData.fromList([plane.bytes]),
              'bytesPerRow': plane.bytesPerRow,
              'bytesPerPixel': plane.bytesPerPixel ?? 1,
              'width': plane.width ?? cameraImage.width,
              'height': plane.height ?? cameraImage.height,
            },
          )
          .toList(growable: false),
    });
  }

  Future<PoseEstimate> estimateImage(Uint8List encodedImage) async {
    if (_isClosed) {
      throw StateError('Pose detector has already been closed.');
    }

    return _estimate(<String, Object>{
      'imageBytes': TransferableTypedData.fromList([encodedImage]),
    });
  }

  Future<PoseEstimate> _estimate(Map<String, Object> request) async {
    final responsePort = ReceivePort();
    _workerPort.send(<String, Object>{
      ...request,
      'replyPort': responsePort.sendPort,
    });

    try {
      final response = await responsePort.first.timeout(_workerTimeout);
      if (response is! Map || response['keypoints'] is! List) {
        final error = response is Map ? response['error'] : null;
        throw StateError('Pose detection failed: $error');
      }
      final segmentation = response['segmentation'];
      if (segmentation is! Map ||
          segmentation['confidences'] is! List ||
          segmentation['width'] is! int ||
          segmentation['height'] is! int) {
        throw StateError('Pose model returned an invalid segmentation mask.');
      }
      final points = (response['keypoints'] as List).map((point) {
        final values = point as List;
        return PoseKeypoint(
          x: (values[0] as num).toDouble(),
          y: (values[1] as num).toDouble(),
          confidence: (values[2] as num).toDouble(),
        );
      }).toList(growable: false);
      final confidences = (segmentation['confidences'] as List)
          .map((value) => (value as num).toDouble())
          .toList(growable: false);
      final width = segmentation['width'] as int;
      final height = segmentation['height'] as int;
      if (points.length != _keypointCount) {
        throw StateError(
          'Pose model returned ${points.length} keypoints; '
          'expected $_keypointCount.',
        );
      }
      if (width != _segmentationWidth ||
          height != _segmentationHeight ||
          confidences.length != width * height) {
        throw StateError(
          'Pose model returned an invalid segmentation mask '
          '(${width}x$height, ${confidences.length} values).',
        );
      }
      return PoseEstimate(
        points,
        segmentation: PoseSegmentation(
          width: width,
          height: height,
          confidences: confidences,
        ),
      );
    } finally {
      responsePort.close();
    }
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    final responsePort = ReceivePort();
    _workerPort.send(<String, Object>{
      'close': true,
      'replyPort': responsePort.sendPort,
    });
    try {
      await responsePort.first.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      _isolate.kill(priority: Isolate.immediate);
    } finally {
      responsePort.close();
    }
  }
}

Future<void> _poseWorkerEntry(Map<String, Object> startup) async {
  final readyPort = startup['readyPort'] as SendPort;
  final requests = ReceivePort();
  Interpreter? interpreter;

  try {
    final modelBytes =
        (startup['modelBytes'] as TransferableTypedData).materialize();
    interpreter = Interpreter.fromBuffer(modelBytes.asUint8List());
    _validateModel(interpreter);
    readyPort.send(<String, Object>{'workerPort': requests.sendPort});
  } catch (error) {
    readyPort.send(<String, Object>{'error': error.toString()});
    requests.close();
    interpreter?.close();
    return;
  }

  final outputBuffers = _allocateOutputs(interpreter);
  await for (final request in requests) {
    if (request is! Map) continue;
    final replyPort = request['replyPort'] as SendPort?;
    if (request['close'] == true) {
      interpreter.close();
      replyPort?.send(<String, Object>{'closed': true});
      requests.close();
      break;
    }
    if (replyPort == null) continue;

    try {
      final input = _prepareInput(request);
      interpreter.runForMultipleInputs([input], outputBuffers);
      final segmentation = _decodeSegmentation(outputBuffers);
      replyPort.send(<String, Object>{
        'keypoints': _decodeKeypoints(outputBuffers),
        'segmentation': <String, Object>{
          'width': segmentation.width,
          'height': segmentation.height,
          'confidences': segmentation.confidences,
        },
      });
    } catch (error) {
      replyPort.send(<String, Object>{'error': error.toString()});
    }
  }
}

void _validateModel(Interpreter interpreter) {
  const inputShape = [1, 353, 257, 3];
  const outputShapes = [
    [1, 23, 17, 17],
    [1, 23, 17, 34],
    [1, 23, 17, 64],
    [1, _segmentationHeight, _segmentationWidth, 1],
  ];
  final actualInputShape = interpreter.getInputTensor(0).shape;
  if (!_sameShape(actualInputShape, inputShape)) {
    throw StateError('Unexpected PoseNet input shape: $actualInputShape.');
  }
  final outputs = interpreter.getOutputTensors();
  if (outputs.length != outputShapes.length) {
    throw StateError('Unexpected PoseNet output count: ${outputs.length}.');
  }
  for (var index = 0; index < outputs.length; index++) {
    if (!_sameShape(outputs[index].shape, outputShapes[index])) {
      throw StateError(
        'Unexpected PoseNet output shape at index $index: '
        '${outputs[index].shape}.',
      );
    }
  }
}

bool _sameShape(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

Map<int, Object> _allocateOutputs(Interpreter interpreter) {
  return {
    for (var index = 0; index < interpreter.getOutputTensors().length; index++)
      index: Uint8List(interpreter.getOutputTensor(index).numBytes()),
  };
}

Uint8List _prepareInput(Map request) {
  final encodedImage = request['imageBytes'];
  final img.Image uprightImage;
  if (encodedImage is TransferableTypedData) {
    final decoded = img.decodeImage(encodedImage.materialize().asUint8List());
    if (decoded == null) {
      throw const FormatException('Captured image could not be decoded.');
    }
    uprightImage = img.bakeOrientation(decoded);
  } else {
    final cameraImage = _convertCameraFrame(request);
    uprightImage = defaultTargetPlatform == TargetPlatform.android
        ? img.copyRotate(cameraImage, angle: 90)
        : cameraImage;
  }
  final resized = img.copyResize(
    uprightImage,
    width: 257,
    height: 353,
    interpolation: img.Interpolation.linear,
  );
  final input = Uint8List(353 * 257 * 3 * 4);
  final inputData = ByteData.view(input.buffer);
  var inputOffset = 0;
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      inputData.setFloat32(
        inputOffset,
        (pixel.r.toDouble() - 127.5) / 127.5,
        Endian.little,
      );
      inputData.setFloat32(
        inputOffset + 4,
        (pixel.g.toDouble() - 127.5) / 127.5,
        Endian.little,
      );
      inputData.setFloat32(
        inputOffset + 8,
        (pixel.b.toDouble() - 127.5) / 127.5,
        Endian.little,
      );
      inputOffset += 12;
    }
  }
  return input;
}

img.Image _convertCameraFrame(Map request) {
  final width = request['width'] as int;
  final height = request['height'] as int;
  final planes = request['planes'] as List;
  final format = request['format'] as String;

  if (format == ImageFormatGroup.bgra8888.name) {
    final plane = planes.first as Map;
    final bytes =
        (plane['bytes'] as TransferableTypedData).materialize().asUint8List();
    return img.Image.fromBytes(
      width: plane['width'] as int,
      height: plane['height'] as int,
      bytes: bytes.buffer,
      rowStride: plane['bytesPerRow'] as int,
      bytesOffset: 28,
      order: img.ChannelOrder.bgra,
    );
  }

  if (format != ImageFormatGroup.yuv420.name || planes.length < 3) {
    throw StateError('Unsupported camera image format: $format.');
  }
  final yPlane = _materializePlane(planes[0] as Map);
  final uPlane = _materializePlane(planes[1] as Map);
  final vPlane = _materializePlane(planes[2] as Map);
  final image = img.Image(width: width, height: height);
  final yStride = yPlane.bytesPerRow;
  final uStride = uPlane.bytesPerRow;
  final vStride = vPlane.bytesPerRow;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yValue = yPlane.bytes[y * yStride + x * yPlane.bytesPerPixel];
      final uvRow = y ~/ 2;
      final uvColumn = x ~/ 2;
      final uValue =
          uPlane.bytes[uvRow * uStride + uvColumn * uPlane.bytesPerPixel];
      final vValue =
          vPlane.bytes[uvRow * vStride + uvColumn * vPlane.bytesPerPixel];
      final red = (yValue + vValue * 1436 / 1024 - 179).round().clamp(0, 255);
      final green =
          (yValue - uValue * 46549 / 131072 + 44 - vValue * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
      final blue = (yValue + uValue * 1814 / 1024 - 227).round().clamp(0, 255);
      image.setPixelRgb(x, y, red, green, blue);
    }
  }
  return image;
}

_CameraPlane _materializePlane(Map plane) {
  return _CameraPlane(
    bytes:
        (plane['bytes'] as TransferableTypedData).materialize().asUint8List(),
    bytesPerRow: plane['bytesPerRow'] as int,
    bytesPerPixel: plane['bytesPerPixel'] as int,
  );
}

class _CameraPlane {
  const _CameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

List<List<double>> _decodeKeypoints(Map<int, Object> outputs) {
  const keypointCount = 17;
  const heatmapHeight = 23;
  const heatmapWidth = 17;
  const inputHeight = 353.0;
  const inputWidth = 257.0;

  final heatmaps = ByteData.view((outputs[0] as Uint8List).buffer);
  final offsets = ByteData.view((outputs[1] as Uint8List).buffer);
  final keypoints = <List<double>>[];

  for (var keypoint = 0; keypoint < keypointCount; keypoint++) {
    var maxRow = 0;
    var maxColumn = 0;
    var maxLogit = double.negativeInfinity;
    for (var row = 0; row < heatmapHeight; row++) {
      for (var column = 0; column < heatmapWidth; column++) {
        final index =
            ((row * heatmapWidth + column) * keypointCount + keypoint) * 4;
        final logit = heatmaps.getFloat32(index, Endian.little);
        if (logit > maxLogit) {
          maxLogit = logit;
          maxRow = row;
          maxColumn = column;
        }
      }
    }

    final offsetBase =
        ((maxRow * heatmapWidth + maxColumn) * keypointCount * 2) * 4;
    final yOffset = offsets.getFloat32(
      offsetBase + keypoint * 4,
      Endian.little,
    );
    final xOffset = offsets.getFloat32(
      offsetBase + (keypointCount + keypoint) * 4,
      Endian.little,
    );
    final y =
        (maxRow / (heatmapHeight - 1) * inputHeight + yOffset) / inputHeight;
    final x =
        (maxColumn / (heatmapWidth - 1) * inputWidth + xOffset) / inputWidth;
    final confidence = 1 / (1 + math.exp(-maxLogit));
    keypoints.add([x, y, confidence]);
  }

  return keypoints;
}

PoseSegmentation _decodeSegmentation(Map<int, Object> outputs) {
  const valueCount = _segmentationWidth * _segmentationHeight;
  final logits = ByteData.view((outputs[3] as Uint8List).buffer);

  return PoseSegmentation.fromLogits(
    width: _segmentationWidth,
    height: _segmentationHeight,
    logits: [
      for (var index = 0; index < valueCount; index++)
        logits.getFloat32(index * 4, Endian.little),
    ],
  );
}
