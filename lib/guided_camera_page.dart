import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'utils/image_crop_helper.dart';
import 'widgets/guide_overlay.dart';
import 'widgets/level_indicator.dart';

class GuidedCameraPage extends StatefulWidget {
  const GuidedCameraPage({
    super.key,
    this.cameraDirection = CameraLensDirection.back,
    this.frameWidthRatio = 0.72,
    this.frameHeightRatio = 0.58,
    this.guideColor = Colors.blue,
    this.hintText = "Align the subject inside the frame",
    this.showGrid = false,
    this.levelToleranceDegrees = 10,
  })  : assert(frameWidthRatio > 0 && frameWidthRatio <= 1),
        assert(frameHeightRatio > 0 && frameHeightRatio <= 1),
        assert(levelToleranceDegrees > 0 && levelToleranceDegrees < 90);

  final CameraLensDirection cameraDirection;
  final double frameWidthRatio;
  final double frameHeightRatio;
  final Color guideColor;
  final String hintText;
  final bool showGrid;
  final double levelToleranceDegrees;

  @override
  State<GuidedCameraPage> createState() => _GuidedCameraPageState();
}

class _GuidedCameraPageState extends State<GuidedCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isLevel = false;
  bool _isCapturing = false;
  bool _isInitializing = false;
  bool _cameraPermissionDenied = false;
  double _tiltDegrees = 90;
  String? _cameraError;
  bool _isActive = true;
  int _cameraGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _isLevel = true;
    } else {
      _startLevelSensor();
    }
    _initializeCamera();
  }

  void _startLevelSensor() {
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen(
      (event) {
        final gravity = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        final tilt = math.atan2(
              math.sqrt(event.x * event.x + event.z * event.z),
              event.y.abs(),
            ) *
            180 /
            math.pi;
        if (!mounted) return;
        setState(() {
          _tiltDegrees = tilt;
          _isLevel = gravity > 6 && tilt <= widget.levelToleranceDegrees;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLevel = false;
          _cameraError = "The phone level sensor is unavailable: $error";
        });
      },
    );
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || !_isActive) return;
    _isInitializing = true;
    final generation = ++_cameraGeneration;
    CameraController? candidate;

    try {
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );

      final cameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration || !_isActive) return;
      CameraDescription? selectedCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == widget.cameraDirection) {
          selectedCamera = camera;
          break;
        }
      }
      if (selectedCamera == null && kIsWeb && cameras.isNotEmpty) {
        selectedCamera = cameras.first;
      }
      if (selectedCamera == null) {
        throw CameraException(
          "CameraUnavailable",
          "No camera is available.",
        );
      }

      candidate = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await candidate.initialize();
      if (!mounted || generation != _cameraGeneration || !_isActive) return;
      await candidate.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || generation != _cameraGeneration || !_isActive) return;

      setState(() {
        _controller = candidate;
        _cameraPermissionDenied = false;
        _cameraError = null;
      });
      candidate = null;
    } on CameraException catch (error) {
      if (!mounted || generation != _cameraGeneration) return;
      setState(() {
        _cameraPermissionDenied = error.code == "CameraAccessDenied" ||
            error.code == "CameraAccessDeniedWithoutPrompt";
        _cameraError = _cameraPermissionDenied
            ? "Camera access was denied. Allow camera access in your device settings, then try again."
            : "Unable to start the camera: ${error.description ?? error.code}";
      });
    } catch (error) {
      if (!mounted || generation != _cameraGeneration) return;
      setState(() {
        _cameraError = "Unable to start the camera: $error";
      });
    } finally {
      await candidate?.dispose();
      if (mounted && generation == _cameraGeneration) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isActive = false;
      _cameraGeneration++;
      _isInitializing = false;
      final controller = _controller;
      _controller = null;
      if (mounted) setState(() {});
      if (controller != null) {
        unawaited(controller.dispose());
      }
    } else if (state == AppLifecycleState.resumed) {
      _isActive = true;
      _initializeCamera();
    }
  }

  Future<void> _capture(Size viewportSize) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isLevel ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _cameraError = null;
    });
    try {
      final captured = await controller.takePicture();
      final guideRect = GuideOverlay.frameRectFor(
        size: viewportSize,
        frameWidthRatio: widget.frameWidthRatio,
        frameHeightRatio: widget.frameHeightRatio,
      );
      final cropped = await cropImageToGuide(
        imageBytes: await captured.readAsBytes(),
        viewportSize: viewportSize,
        guideRect: guideRect,
        mirrorHorizontally: widget.cameraDirection == CameraLensDirection.front,
      );
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(cropped);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _cameraError =
              "Could not take the photo: ${error.description ?? error.code}";
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _cameraError = "Could not prepare the photo: $error");
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_accelerometerSubscription?.cancel());
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    unawaited(SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize =
              Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && controller.value.isInitialized)
                _buildCoverPreview(controller, viewportSize)
              else
                _buildCameraStatus(),
              IgnorePointer(
                child: GuideOverlay(
                  frameWidthRatio: widget.frameWidthRatio,
                  frameHeightRatio: widget.frameHeightRatio,
                  hintText: widget.hintText,
                  isLevel: _isLevel,
                  guideColor: widget.guideColor,
                  showGrid: widget.showGrid,
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: "Close camera",
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kIsWeb)
                      const Text(
                        "Gardez la caméra droite manuellement",
                        style: TextStyle(color: Colors.white),
                      )
                    else
                      LevelIndicator(
                        isLevel: _isLevel,
                        tiltDegrees: _tiltDegrees,
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: FloatingActionButton(
                        heroTag: "guided-camera-capture",
                        onPressed: controller != null &&
                                controller.value.isInitialized &&
                                _isLevel &&
                                !_isCapturing
                            ? () => _capture(viewportSize)
                            : null,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        disabledElevation: 0,
                        tooltip: "Take photo",
                        child: _isCapturing
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera_alt, size: 34),
                      ),
                    ),
                    if (_cameraError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _cameraError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoverPreview(CameraController controller, Size viewportSize) {
    final previewAspectRatio = 1 / controller.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: viewportSize.height * previewAspectRatio,
        height: viewportSize.height,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildCameraStatus() {
    if (_cameraPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Camera access is needed to take a guided photo. You can enable it in your device settings.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initializeCamera,
                child: const Text("Try again"),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: _cameraError == null
          ? const CircularProgressIndicator(color: Colors.white)
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _cameraError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _initializeCamera,
                    child: const Text("Retry camera"),
                  ),
                ],
              ),
            ),
    );
  }
}
