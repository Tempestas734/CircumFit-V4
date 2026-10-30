import 'package:flutter/material.dart';

class LevelIndicator extends StatelessWidget {
  const LevelIndicator({
    super.key,
    required this.isAvailable,
    required this.isLevel,
    required this.tiltDegrees,
    required this.toleranceDegrees,
  });

  final bool isAvailable;
  final bool isLevel;
  final double tiltDegrees;
  final double toleranceDegrees;

  @override
  Widget build(BuildContext context) {
    final color = !isAvailable
        ? Colors.orangeAccent
        : isLevel
            ? Colors.greenAccent
            : Colors.redAccent;
    final status = !isAvailable
        ? "Capteur indisponible · alignez le téléphone visuellement"
        : isLevel
            ? "Téléphone droit · ${tiltDegrees.toStringAsFixed(0)}°"
            : "Inclinaison ${tiltDegrees.toStringAsFixed(0)}° · maximum ${toleranceDegrees.toStringAsFixed(0)}°";
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !isAvailable
                      ? Icons.screen_rotation_alt
                      : isLevel
                          ? Icons.check_circle
                          : Icons.screen_rotation,
                  color: color,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            if (isAvailable) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  value: (tiltDegrees / 90).clamp(0, 1),
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
