import 'package:flutter/material.dart';

class LevelIndicator extends StatelessWidget {
  const LevelIndicator({
    super.key,
    required this.isLevel,
    required this.tiltDegrees,
  });

  final bool isLevel;
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    final color = isLevel ? Colors.greenAccent : Colors.redAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isLevel ? Icons.check_circle : Icons.screen_rotation,
                color: color),
            const SizedBox(width: 8),
            Text(
              isLevel
                  ? "Téléphone droit"
                  : "Redressez le téléphone (${tiltDegrees.toStringAsFixed(0)}°)",
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
