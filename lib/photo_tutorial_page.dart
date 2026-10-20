import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PoseView { face, profil }

Future<bool> showPhotoTutorial(
  BuildContext context, {
  required PoseView view,
  double? heightCm,
}) async {
  final understood = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoTutorialPage(view: view, heightCm: heightCm),
    ),
  );
  return understood ?? false;
}

class PhotoTutorialPage extends StatefulWidget {
  const PhotoTutorialPage({super.key, required this.view, this.heightCm});

  final PoseView view;
  final double? heightCm;

  @override
  State<PhotoTutorialPage> createState() => _PhotoTutorialPageState();
}

class _PhotoTutorialPageState extends State<PhotoTutorialPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl
        ..stop()
        ..value = 0.5;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_Tip> get _tips {
    final height = widget.heightCm;
    final cameraTip = height == null
        ? "Objectif au niveau du nombril (environ 60 % de votre taille), téléphone vertical et d’aplomb."
        : "Objectif à environ ${(height * 0.6).round()} cm du sol (niveau du nombril), à ≈ ${(height * 1.2 / 100).toStringAsFixed(1).replaceAll('.', ',')} m de vous. Téléphone vertical et d’aplomb.";
    final face = widget.view == PoseView.face;
    return [
      const _Tip(
        Icons.checkroom,
        "Vêtements",
        "Haut ajusté et uni, pieds nus. Pas de veste, sweat ample, ceinture ni poches remplies.",
      ),
      const _Tip(
        Icons.directions_walk,
        "Pieds",
        "Écartés de la largeur des épaules, parallèles, pointes vers l’avant. Pieds entiers dans le cadre.",
      ),
      _Tip(
        Icons.accessibility_new,
        "Bras",
        face
            ? "Légèrement écartés du corps (10 à 15 cm), mains détendues, paumes vers les cuisses."
            : "Croisés sur la poitrine, coudes un peu relevés, pour dégager la taille. Tournez-vous de 90° sans bouger les pieds.",
      ),
      _Tip(Icons.smartphone, "Caméra", cameraTip),
      const _Tip(
        Icons.air,
        "Respiration",
        "Respirez normalement et déclenchez après une expiration, sans rentrer le ventre.",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final face = widget.view == PoseView.face;
    return Scaffold(
      appBar: AppBar(
        title: Text(face ? "Photo de face (1/2)" : "Photo de profil (2/2)"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(
            height: 260,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _FigurePainter(
                  view: widget.view,
                  t: _ctrl.value,
                  body: colorScheme.outlineVariant,
                  accent: colorScheme.primary,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              face
                  ? "Les bras s’écartent légèrement du corps"
                  : "Tournez de 90°, bras croisés",
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 12),
          for (final tip in _tips)
            ListTile(
              leading: Icon(tip.icon, color: colorScheme.primary),
              title: Text(tip.title),
              subtitle: Text(tip.text),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.photo_camera),
          label: const Text("J’ai compris, ouvrir l’appareil photo"),
        ),
      ),
    );
  }
}

class _Tip {
  const _Tip(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.view,
    required this.t,
    required this.body,
    required this.accent,
  });

  final PoseView view;
  final double t;
  final Color body;
  final Color accent;

  static double _lerp(double a, double b, double progress) =>
      a + (b - a) * progress;

  void _dash(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 5.0;
    const gapLength = 4.0;
    final length = (end - start).distance;
    final direction = (end - start) / length;
    for (double offset = 0; offset < length; offset += dashLength + gapLength) {
      canvas.drawLine(
        start + direction * offset,
        start + direction * math.min(offset + dashLength, length),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 200, size.height / 290);
    canvas.save();
    canvas.translate(
      (size.width - 200 * scale) / 2,
      (size.height - 290 * scale) / 2,
    );
    canvas.scale(scale);

    final rawProgress = t < 0.25
        ? 0.0
        : t < 0.5
            ? (t - 0.25) / 0.25
            : t < 0.85
                ? 1.0
                : (1 - t) / 0.15;
    final progress = Curves.easeInOut.transform(rawProgress.clamp(0.0, 1.0));
    final face = view == PoseView.face;

    final limb = Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = body;
    final waist = Paint()
      ..color = accent
      ..strokeWidth = 2.5;

    final legProgress = face ? 0.0 : progress;
    canvas.drawLine(
      Offset(_lerp(88, 100, legProgress), 147),
      Offset(_lerp(82, 98, legProgress), 265),
      limb,
    );
    canvas.drawLine(
      Offset(_lerp(112, 100, legProgress), 147),
      Offset(_lerp(118, 102, legProgress), 265),
      limb,
    );

    final torsoWidth = face ? 50.0 : _lerp(50, 28, progress);
    canvas.drawRRect(
      RRect.fromLTRBR(
        100 - torsoWidth / 2,
        52,
        100 + torsoWidth / 2,
        147,
        const Radius.circular(14),
      ),
      fill,
    );
    canvas.drawCircle(const Offset(100, 30), 15, fill);

    final waistHalfWidth = face ? 36.0 : _lerp(36, 24, progress);
    _dash(
      canvas,
      Offset(100 - waistHalfWidth, 108),
      Offset(100 + waistHalfWidth, 108),
      waist,
    );

    if (face) {
      final armAngle = 26 * math.pi / 180 * progress;
      void drawArm(double startX, double endX, double direction) {
        canvas.save();
        canvas.translate(startX, 62);
        canvas.rotate(armAngle * direction);
        canvas.translate(-startX, -62);
        canvas.drawLine(Offset(startX, 64), Offset(endX, 150), limb);
        canvas.restore();
      }

      drawArm(77, 72, 1);
      drawArm(123, 128, -1);
    } else {
      final hangingArms = Paint()
        ..color = body.withValues(alpha: 1 - progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(_lerp(77, 100, progress), 64),
        Offset(_lerp(72, 98, progress), 150),
        hangingArms,
      );
      canvas.drawLine(
        Offset(_lerp(123, 100, progress), 64),
        Offset(_lerp(128, 102, progress), 150),
        hangingArms,
      );
      final crossedArms = Paint()
        ..color = accent.withValues(alpha: progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(100, 66)
          ..lineTo(112, 82)
          ..lineTo(94, 78),
        crossedArms,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.t != t ||
      old.view != view ||
      old.body != body ||
      old.accent != accent;
}
