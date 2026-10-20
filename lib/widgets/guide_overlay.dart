import 'package:flutter/material.dart';

class GuideOverlay extends StatelessWidget {
  const GuideOverlay({
    super.key,
    required this.frameWidthRatio,
    required this.frameHeightRatio,
    required this.hintText,
    required this.isLevel,
    this.guideColor = Colors.blue,
    this.showGrid = false,
  });

  final double frameWidthRatio;
  final double frameHeightRatio;
  final String hintText;
  final bool isLevel;
  final Color guideColor;
  final bool showGrid;

  static Rect frameRectFor({
    required Size size,
    required double frameWidthRatio,
    required double frameHeightRatio,
    double centerYRatio = 0.48,
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
            showGrid: showGrid,
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
    required this.showGrid,
  });

  final Rect frame;
  final Color guideColor;
  final bool isLevel;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final roundedFrame = RRect.fromRectAndRadius(frame, const Radius.circular(24));
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(roundedFrame);
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.55));

    canvas.save();
    canvas.clipRRect(roundedFrame);
    final activeColor = isLevel ? guideColor : Colors.redAccent;
    final guidePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    if (showGrid) {
      for (var i = 1; i < 3; i++) {
        final dx = frame.left + frame.width * i / 3;
        final dy = frame.top + frame.height * i / 3;
        canvas.drawLine(Offset(dx, frame.top), Offset(dx, frame.bottom), guidePaint);
        canvas.drawLine(Offset(frame.left, dy), Offset(frame.right, dy), guidePaint);
      }
    }

    final center = frame.center;
    const crosshairHalfLength = 12.0;
    final crosshairPaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - crosshairHalfLength, center.dy),
      Offset(center.dx + crosshairHalfLength, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairHalfLength),
      Offset(center.dx, center.dy + crosshairHalfLength),
      crosshairPaint,
    );
    canvas.restore();

    canvas.drawRRect(
      roundedFrame,
      Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.guideColor != guideColor ||
      oldDelegate.isLevel != isLevel ||
      oldDelegate.showGrid != showGrid;
}
