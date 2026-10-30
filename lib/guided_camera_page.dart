import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'utils/image_crop_helper.dart';
import 'utils/pose_detector.dart';
import 'utils/pose_feedback.dart';
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
    this.isSideView = false,
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
  final bool isSideView;
  final bool showGrid;
  final double levelToleranceDegrees;

  @override
  State<GuidedCameraPage> createState() => _GuidedCameraPageState();
}

class _GuidedCameraPageState extends State<GuidedCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _levelSensorTimeout;
  bool _isLevel = false;
  bool _isCapturing = false;
  bool _isSwitchingCamera = false;
  bool _canSwitchCamera = false;
  bool _isInitializing = false;
  bool _isPoseInitializing = false;
  bool _poseStreamStarting = false;
  bool _poseProcessing = false;
  bool _cameraPermissionDenied = false;
  bool _exposureControlAvailable = false;
  bool _tiltSensorAvailable = false;
  bool _poseDetectionReady = false;
  bool _poseDetectionFailed = false;
  bool _hasPoseReading = false;
  bool _isPoseInFrame = false;
  double _tiltDegrees = 90;
  double _minExposureOffset = 0;
  double _maxExposureOffset = 0;
  double _exposureOffset = 0;
  double _appliedExposureOffset = 0;
  String? _cameraError;
  String? _exposureError;
  String? _levelError;
  String? _poseError;
  String? _poseMessage;
  List<Offset> _poseLandmarks = const [];
  bool _isActive = true;
  int _cameraGeneration = 0;
  late CameraLensDirection _cameraDirection = widget.cameraDirection;
  DateTime _lastPoseFrame = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _supportsLivePose =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLevel = true;
    _startLevelSensor();
    if (_supportsLivePose) {
      _isPoseInitializing = true;
      unawaited(_initializePoseDetector());
    }
    _initializeCamera();
  }

  Future<void> _initializePoseDetector() async {
    try {
      final detector = await PoseDetector.load();
      if (!mounted) {
        await detector.close();
        return;
      }
      _poseDetector = detector;
      _isPoseInitializing = false;
      final controller = _controller;
      if (_isActive && controller != null) {
        unawaited(_startPoseStream(controller));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPoseInitializing = false;
        _poseDetectionFailed = true;
        _poseError =
            "Détection automatique indisponible : $error. Cadrez-vous manuellement.";
      });
    }
  }

  Future<void> _startPoseStream(CameraController controller) async {
    if (!_supportsLivePose ||
        _poseDetector == null ||
        _poseStreamStarting ||
        controller.value.isStreamingImages ||
        !controller.value.isInitialized) {
      return;
    }
    _poseStreamStarting = true;
    try {
      await controller.startImageStream(_processPoseFrame);
      if (!mounted || !identical(controller, _controller)) return;
      setState(() {
        _poseDetectionReady = true;
        _poseDetectionFailed = false;
        _hasPoseReading = false;
        _isPoseInFrame = false;
        _poseError = null;
        _poseMessage = "Analyse de la pose en cours…";
        _poseLandmarks = const [];
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _poseDetectionFailed = true;
        _poseDetectionReady = false;
        _poseError =
            "Analyse de pose indisponible : ${error.description ?? error.code}. Cadrez-vous manuellement.";
      });
    } finally {
      _poseStreamStarting = false;
    }
  }

  Future<void> _processPoseFrame(CameraImage image) async {
    if (_poseProcessing ||
        !_isActive ||
        _poseDetector == null ||
        DateTime.now().difference(_lastPoseFrame) <
            const Duration(milliseconds: 350)) {
      return;
    }
    _poseProcessing = true;
    _lastPoseFrame = DateTime.now();
    try {
      final pose = await _poseDetector!.estimate(image);
      if (!mounted || !_isActive) return;
      final guideRect = GuideOverlay.frameRectFor(
        size: const Size(1, 1),
        frameWidthRatio: widget.frameWidthRatio,
        frameHeightRatio: widget.frameHeightRatio,
      );
      final feedback = PoseFeedback.evaluate(
        pose: pose,
        guideRect: guideRect,
      );
      const importantLandmarks = {5, 6, 9, 10, 15, 16};
      setState(() {
        _hasPoseReading = true;
        _isPoseInFrame = feedback.isReady;
        _poseMessage = feedback.message;
        _poseLandmarks = [
          for (var index = 0; index < pose.keypoints.length; index++)
            if (importantLandmarks.contains(index) &&
                pose.keypoints[index].confidence >= 0.35)
              Offset(pose.keypoints[index].x, pose.keypoints[index].y),
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _poseDetectionFailed = true;
        _poseDetectionReady = false;
        _poseError =
            "Détection automatique interrompue : $error. Cadrez-vous manuellement.";
      });
      final controller = _controller;
      if (controller?.value.isStreamingImages == true) {
        try {
          await controller!.stopImageStream();
        } on CameraException catch (stopError) {
          if (mounted) {
            setState(() {
              _cameraError =
                  "Impossible d’arrêter le flux caméra : ${stopError.description ?? stopError.code}";
            });
          }
        }
      }
    } finally {
      _poseProcessing = false;
    }
  }

  void _startLevelSensor() {
    _levelSensorTimeout?.cancel();
    _levelSensorTimeout = Timer(const Duration(seconds: 2), () {
      if (!mounted || _tiltSensorAvailable) return;
      setState(() {
        _isLevel = true;
        _levelError =
            "Le capteur d’inclinaison n’est pas accessible. Alignez le téléphone visuellement.";
      });
    });
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
        if (gravity <= 6) {
          setState(() {
            _isLevel = true;
            _tiltSensorAvailable = false;
            _levelError =
                "Le capteur d’inclinaison n’est pas accessible. Alignez le téléphone visuellement.";
          });
          return;
        }
        _levelSensorTimeout?.cancel();
        setState(() {
          _tiltDegrees = tilt;
          _tiltSensorAvailable = true;
          _isLevel = tilt <= widget.levelToleranceDegrees;
          _levelError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLevel = true;
          _tiltSensorAvailable = false;
          _levelError =
              "Capteur d’inclinaison indisponible : $error. Alignez le téléphone visuellement.";
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
      final hasFrontCamera = cameras.any(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      final hasBackCamera = cameras.any(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      setState(() {
        _canSwitchCamera = hasFrontCamera && hasBackCamera;
      });
      CameraDescription? selectedCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == _cameraDirection) {
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
        imageFormatGroup: _supportsLivePose
            ? defaultTargetPlatform == TargetPlatform.iOS
                ? ImageFormatGroup.bgra8888
                : ImageFormatGroup.yuv420
            : null,
      );
      await candidate.initialize();
      if (!mounted || generation != _cameraGeneration || !_isActive) return;
      if (!kIsWeb) {
        await candidate.lockCaptureOrientation(DeviceOrientation.portraitUp);
      }
      if (!mounted || generation != _cameraGeneration || !_isActive) return;

      var exposureAvailable = false;
      var minimumExposure = 0.0;
      var maximumExposure = 0.0;
      String? exposureError;
      if (!kIsWeb) {
        try {
          minimumExposure = await candidate.getMinExposureOffset();
          maximumExposure = await candidate.getMaxExposureOffset();
          exposureAvailable = maximumExposure > minimumExposure;
        } on CameraException catch (error) {
          exposureError =
              "Réglage matériel indisponible (${error.description ?? error.code}) ; le réglage logiciel reste actif.";
        }
      }
      if (!mounted || generation != _cameraGeneration || !_isActive) return;

      final initializedController = candidate;
      setState(() {
        _controller = candidate;
        _cameraPermissionDenied = false;
        _cameraError = null;
        _exposureControlAvailable = exposureAvailable;
        _minExposureOffset = exposureAvailable ? minimumExposure : -1;
        _maxExposureOffset = exposureAvailable ? maximumExposure : 1;
        _exposureOffset =
            0.clamp(_minExposureOffset, _maxExposureOffset).toDouble();
        _appliedExposureOffset = _exposureOffset;
        _exposureError = exposureError;
      });
      candidate = null;
      if (_supportsLivePose) {
        unawaited(_startPoseStream(initializedController));
      }
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

  Future<void> _switchCamera() async {
    final controller = _controller;
    if (!_canSwitchCamera ||
        _isSwitchingCamera ||
        _isInitializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isSwitchingCamera = true;
      _controller = null;
      _poseDetectionReady = false;
      _hasPoseReading = false;
      _poseMessage = "Analyse de la pose en cours…";
      _poseLandmarks = const [];
    });

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _cameraDirection = _cameraDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;
        _cameraError = null;
      });
      await _initializeCamera();
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _cameraError =
              "Impossible de changer de caméra : ${error.description ?? error.code}";
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cameraError = "Impossible de changer de caméra : $error";
        });
      }
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
    }
  }

  Future<void> _setExposureOffset(double value) async {
    final controller = _controller;
    if (controller == null || !_exposureControlAvailable) {
      setState(() {
        _exposureOffset = value;
        _appliedExposureOffset = value;
      });
      return;
    }
    setState(() => _exposureOffset = value);
    try {
      final appliedValue = await controller.setExposureOffset(value);
      if (mounted) {
        setState(() {
          _exposureOffset = appliedValue;
          _appliedExposureOffset = appliedValue;
          _exposureError = null;
        });
      }
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _exposureOffset = _appliedExposureOffset;
        _exposureError =
            "Impossible de régler la luminosité : ${error.description ?? error.code}";
      });
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
      _poseDetectionReady = false;
      _hasPoseReading = false;
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
    final canCapturePose = !_supportsLivePose ||
        _poseDetectionFailed ||
        (_poseDetectionReady && _hasPoseReading && _isPoseInFrame);
    if (controller == null ||
        !controller.value.isInitialized ||
        (_tiltSensorAvailable && !_isLevel) ||
        !canCapturePose ||
        _isCapturing) {
      return;
    }

    var restartPoseStream = false;
    var captureCompleted = false;
    setState(() {
      _isCapturing = true;
      _cameraError = null;
    });
    try {
      if (controller.value.isStreamingImages) {
        restartPoseStream = true;
        await controller.stopImageStream();
      }
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
        exposure: _exposureControlAvailable ? 0 : _exposureOffset,
      );
      if (!mounted) return;
      captureCompleted = true;
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
      if (mounted &&
          restartPoseStream &&
          !captureCompleted &&
          controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        await _startPoseStream(controller);
      }
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_accelerometerSubscription?.cancel());
    _levelSensorTimeout?.cancel();
    final controller = _controller;
    final detector = _poseDetector;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    if (detector != null) unawaited(detector.close());
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
                  isLevel: _isLevel && (!_poseDetectionReady || _isPoseInFrame),
                  isSideView: widget.isSideView,
                  guideColor: widget.guideColor,
                  showGrid: widget.showGrid,
                  posePoints: _poseLandmarks,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: "Close camera",
                      ),
                      if (_canSwitchCamera)
                        IconButton(
                          key: const Key('switch_camera'),
                          onPressed: _isSwitchingCamera || _isInitializing
                              ? null
                              : _switchCamera,
                          icon: _isSwitchingCamera
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.flip_camera_android,
                                  color: Colors.white,
                                ),
                          tooltip: _cameraDirection == CameraLensDirection.front
                              ? "Switch to back camera"
                              : "Switch to front camera",
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildExposureControl(),
                    if (_exposureError != null)
                      Text(
                        _exposureError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 8),
                    LevelIndicator(
                      isAvailable: _tiltSensorAvailable,
                      isLevel: _isLevel,
                      tiltDegrees: _tiltDegrees,
                      toleranceDegrees: widget.levelToleranceDegrees,
                    ),
                    if (!_tiltSensorAvailable && _levelError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _levelError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (!_isLevel && _tiltSensorAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _levelError ??
                              "Photo bloquée : redressez le téléphone à moins de ${widget.levelToleranceDegrees.toStringAsFixed(0)}°.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    _buildPoseStatus(),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: FloatingActionButton(
                        heroTag: "guided-camera-capture",
                        onPressed: controller != null &&
                                controller.value.isInitialized &&
                                !_isSwitchingCamera &&
                                (!_tiltSensorAvailable || _isLevel) &&
                                (!_supportsLivePose ||
                                    _poseDetectionFailed ||
                                    (_poseDetectionReady &&
                                        _hasPoseReading &&
                                        _isPoseInFrame)) &&
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

  Widget _buildPoseStatus() {
    if (!_supportsLivePose && !kIsWeb) return const SizedBox.shrink();
    final message = _poseError ??
        _poseMessage ??
        (_isPoseInitializing
            ? "Chargement de la détection de pose…"
            : kIsWeb
                ? "Détection automatique indisponible dans le navigateur. Cadrez-vous manuellement."
                : "Initialisation de la détection de pose…");
    final color = _poseError != null || (_hasPoseReading && !_isPoseInFrame)
        ? Colors.redAccent
        : _isPoseInFrame
            ? Colors.greenAccent
            : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildExposureControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text("Luminosité", style: TextStyle(color: Colors.white)),
            const Spacer(),
            Text(
              "${_exposureOffset > 0 ? '+' : ''}${_exposureOffset.toStringAsFixed(1)} EV",
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.brightness_low, color: Colors.white, size: 20),
            Expanded(
              child: Slider(
                min: _minExposureOffset,
                max: _maxExposureOffset,
                value: _exposureOffset
                    .clamp(_minExposureOffset, _maxExposureOffset)
                    .toDouble(),
                onChanged: (value) => setState(() => _exposureOffset = value),
                onChangeEnd: (value) => unawaited(_setExposureOffset(value)),
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
              ),
            ),
            const Icon(Icons.brightness_high, color: Colors.white, size: 20),
          ],
        ),
        Text(
          _exposureControlAvailable ? "Exposition caméra" : "Aperçu et photo",
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCoverPreview(CameraController controller, Size viewportSize) {
    final previewAspectRatio = 1 / controller.value.aspectRatio;
    final gain = math.pow(2, _exposureOffset).toDouble();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: viewportSize.height * previewAspectRatio,
        height: viewportSize.height,
        child: _exposureControlAvailable
            ? CameraPreview(controller)
            : ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  gain,
                  0,
                  0,
                  0,
                  0,
                  0,
                  gain,
                  0,
                  0,
                  0,
                  0,
                  0,
                  gain,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: CameraPreview(controller),
              ),
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
