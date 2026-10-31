import 'package:flutter/material.dart';

import '../utils/pose_types.dart';

class GuideOverlay extends StatelessWidget {
  const GuideOverlay({
    super.key,
    required this.frameWidthRatio,
    required this.frameHeightRatio,
    required this.hintText,
    required this.isLevel,
    this.isSideView = false,
    this.guideColor = Colors.blue,
    this.showGrid = false,
    this.posePoints = const [],
    this.poseSegmentation,
  });

  final double frameWidthRatio;
  final double frameHeightRatio;
  final String hintText;
  final bool isLevel;
  final bool isSideView;
  final Color guideColor;
  final bool showGrid;
  final List<Offset> posePoints;
  final PoseSegmentation? poseSegmentation;

  static Rect frameRectFor({
    required Size size,
    required double frameWidthRatio,
    required double frameHeightRatio,
    double centerYRatio = 0.38,
  }) {
    final width = size.width * frameWidthRatio;
    final height = size.height * frameHeightRatio;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * centerYRatio),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = frameRectFor(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          frameWidthRatio: frameWidthRatio,
          frameHeightRatio: frameHeightRatio,
        );
        return CustomPaint(
          painter: _GuidePainter(
            frame: frame,
            guideColor: guideColor,
            isLevel: isLevel,
            isSideView: isSideView,
            showGrid: showGrid,
            posePoints: posePoints,
            poseSegmentation: poseSegmentation,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                hintText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.frame,
    required this.guideColor,
    required this.isLevel,
    required this.isSideView,
    required this.showGrid,
    required this.posePoints,
    required this.poseSegmentation,
  });

  final Rect frame;
  final Color guideColor;
  final bool isLevel;
  final bool isSideView;
  final bool showGrid;
  final List<Offset> posePoints;
  final PoseSegmentation? poseSegmentation;

  Offset _point(double x, double y) =>
      Offset(frame.left + frame.width * x, frame.top + frame.height * y);

  @override
  void paint(Canvas canvas, Size size) {
    final color = isLevel ? guideColor : Colors.redAccent;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    _drawSegmentation(canvas, size);

    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.24)
        ..strokeWidth = 1;
      for (var i = 1; i < 3; i++) {
        final dx = frame.left + frame.width * i / 3;
        final dy = frame.top + frame.height * i / 3;
        canvas.drawLine(
            Offset(dx, frame.top), Offset(dx, frame.bottom), gridPaint);
        canvas.drawLine(
            Offset(frame.left, dy), Offset(frame.right, dy), gridPaint);
      }
    }

    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.88)
      ..strokeWidth = 0.004
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final detailStroke = Paint()
      ..color = color.withValues(alpha: 0.88)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final limbStroke = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = frame.width * (isSideView ? 0.055 : 0.045)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final head = Rect.fromCenter(
      center: _point(isSideView ? 0.53 : 0.5, 0.105),
      width: frame.width * (isSideView ? 0.17 : 0.19),
      height: frame.height * 0.12,
    );
    canvas.drawOval(head, fill);
    canvas.drawOval(head, detailStroke);

    if (isSideView) {
      _drawSidePose(canvas, fill, stroke, detailStroke, limbStroke);
    } else {
      _drawFrontPose(canvas, fill, stroke, detailStroke, limbStroke);
    }

    final markers = isSideView
        ? const [
            Offset(0.48, 0.25),
            Offset(0.62, 0.43),
            Offset(0.53, 0.96),
          ]
        : const [
            Offset(0.34, 0.25),
            Offset(0.66, 0.25),
            Offset(0.27, 0.48),
            Offset(0.73, 0.48),
            Offset(0.42, 0.96),
            Offset(0.58, 0.96),
          ];
    for (final marker in markers) {
      canvas.drawCircle(
        _point(marker.dx, marker.dy),
        frame.width * 0.012,
        Paint()..color = color,
      );
    }

    final detectedPaint = Paint()
      ..color = isLevel ? Colors.lightGreenAccent : Colors.redAccent
      ..style = PaintingStyle.fill;
    for (final point in posePoints) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        5,
        detectedPaint,
      );
    }
  }

  void _drawSegmentation(Canvas canvas, Size size) {
    final segmentation = poseSegmentation;
    if (segmentation == null) return;

    final paint = Paint()
      ..color = Colors.lightGreenAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final cells = Path();
    for (var y = 0; y < segmentation.height; y++) {
      for (var x = 0; x < segmentation.width; x++) {
        if (!segmentation.isForeground(x, y)) continue;
        cells.addRect(Rect.fromLTWH(
          x * size.width / segmentation.width,
          y * size.height / segmentation.height,
          size.width / segmentation.width,
          size.height / segmentation.height,
        ));
      }
    }
    canvas.drawPath(cells, paint);
  }

  void _drawFrontPose(
    Canvas canvas,
    Paint fill,
    Paint stroke,
    Paint detailStroke,
    Paint limbStroke,
  ) {
    final torso = Path()
      ..moveTo(0.39, 0.22)
      ..quadraticBezierTo(0.5, 0.19, 0.61, 0.22)
      ..lineTo(0.68, 0.36)
      ..lineTo(0.59, 0.60)
      ..lineTo(0.61, 0.67)
      ..lineTo(0.57, 0.71)
      ..lineTo(0.43, 0.71)
      ..lineTo(0.39, 0.67)
      ..lineTo(0.41, 0.60)
      ..lineTo(0.32, 0.36)
      ..close();
    _drawShape(canvas, torso, fill, stroke);
    _drawNeck(canvas, 0.5, limbStroke);

    _drawLimb(canvas, limbStroke, [
      const Offset(0.36, 0.25),
      const Offset(0.27, 0.34),
      const Offset(0.22, 0.49),
    ]);
    _drawLimb(canvas, limbStroke, [
      const Offset(0.64, 0.25),
      const Offset(0.73, 0.34),
      const Offset(0.78, 0.49),
    ]);
    _drawHand(canvas, detailStroke, 0.22, 0.51);
    _drawHand(canvas, detailStroke, 0.78, 0.51);
    _drawLimb(canvas, limbStroke, [
      const Offset(0.44, 0.67),
      const Offset(0.42, 0.82),
      const Offset(0.41, 0.96),
    ]);
    _drawLimb(canvas, limbStroke, [
      const Offset(0.56, 0.67),
      const Offset(0.58, 0.82),
      const Offset(0.59, 0.96),
    ]);
    _drawFoot(canvas, limbStroke, 0.38, 0.98, 0.44, 0.98);
    _drawFoot(canvas, limbStroke, 0.56, 0.98, 0.62, 0.98);
  }

  void _drawSidePose(
    Canvas canvas,
    Paint fill,
    Paint stroke,
    Paint detailStroke,
    Paint limbStroke,
  ) {
    final torso = Path()
      ..moveTo(0.49, 0.22)
      ..quadraticBezierTo(0.62, 0.26, 0.59, 0.38)
      ..quadraticBezierTo(0.68, 0.49, 0.59, 0.61)
      ..lineTo(0.56, 0.70)
      ..lineTo(0.42, 0.70)
      ..lineTo(0.45, 0.58)
      ..quadraticBezierTo(0.40, 0.43, 0.44, 0.32)
      ..close();
    _drawShape(canvas, torso, fill, stroke);
    _drawNeck(canvas, 0.51, limbStroke);

    _drawLimb(canvas, limbStroke, [
      const Offset(0.48, 0.25),
      const Offset(0.57, 0.34),
      const Offset(0.62, 0.42),
    ]);
    _drawLimb(canvas, limbStroke, [
      const Offset(0.62, 0.42),
      const Offset(0.55, 0.47),
      const Offset(0.48, 0.43),
    ]);
    _drawHand(canvas, detailStroke, 0.47, 0.44);
    _drawLimb(canvas, limbStroke, [
      const Offset(0.44, 0.67),
      const Offset(0.46, 0.82),
      const Offset(0.46, 0.96),
    ]);
    _drawLimb(canvas, limbStroke, [
      const Offset(0.54, 0.67),
      const Offset(0.57, 0.82),
      const Offset(0.57, 0.96),
    ]);
    _drawFoot(canvas, limbStroke, 0.44, 0.98, 0.51, 0.98);
    _drawFoot(canvas, limbStroke, 0.55, 0.98, 0.62, 0.98);
  }

  void _drawShape(Canvas canvas, Path path, Paint fill, Paint stroke) {
    canvas.save();
    canvas.translate(frame.left, frame.top);
    canvas.scale(frame.width, frame.height);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  void _drawNeck(Canvas canvas, double x, Paint paint) {
    final top = _point(x, 0.155);
    final bottom = _point(x, 0.225);
    canvas.drawLine(top, bottom, paint);
  }

  void _drawLimb(Canvas canvas, Paint paint, List<Offset> points) {
    final first = _point(points.first.dx, points.first.dy);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final offset = _point(point.dx, point.dy);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawHand(Canvas canvas, Paint stroke, double x, double y) {
    final hand = Rect.fromCenter(
      center: _point(x, y),
      width: frame.width * 0.045,
      height: frame.height * 0.045,
    );
    canvas.drawOval(
        hand, Paint()..color = stroke.color.withValues(alpha: 0.18));
    canvas.drawOval(hand, stroke);
  }

  void _drawFoot(
    Canvas canvas,
    Paint paint,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final path = Path()
      ..moveTo(_point(left, top).dx, _point(left, top).dy)
      ..lineTo(_point(right, bottom).dx, _point(right, bottom).dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.guideColor != guideColor ||
      oldDelegate.isLevel != isLevel ||
      oldDelegate.isSideView != isSideView ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.posePoints != posePoints;
}
