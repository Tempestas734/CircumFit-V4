// Tutoriel en 5 pages animées, affiché avant chaque photo (face, puis profil).
// Aucune dépendance externe : Flutter (Material 3) uniquement.

import 'dart:math' as math;
import 'package:flutter/material.dart';

enum PoseView { face, profil }

/// Affiche le tutoriel en plein écran.
/// Renvoie true si la personne passe à l’étape suivante (bouton final ou « Passer »),
/// false si elle ferme l’écran avec la croix.
Future<bool> showPhotoTutorial(
  BuildContext context, {
  required PoseView view,
  double? heightCm,
}) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoTutorialPage(view: view, heightCm: heightCm),
    ),
  );
  return ok ?? false;
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
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  final PageController _pages = PageController();
  int _index = 0;

  bool get _face => widget.view == PoseView.face;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim
        ..stop()
        ..value = 0.5;
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _pages.dispose();
    super.dispose();
  }

  List<_PageData> get _data {
    final h = widget.heightCm ?? 170;
    final cam = (h * 0.6).round();
    final dist = (h * 1.2 / 100).toStringAsFixed(1).replaceAll('.', ',');
    final known = widget.heightCm != null;
    final commonPages = [
      _PageData(
        "Bien s’habiller",
        const [
          "Haut ajusté et uni, qui contraste avec le mur",
          "Pieds nus, sans ceinture ni poches remplies",
          "Pas de veste ni de sweat ample",
        ],
        (t, cs) => _ClothesScene(t, cs),
      ),
      _PageData(
        "Régler le téléphone",
        [
          known
              ? "Objectif à ≈ $cam cm du sol, au niveau du nombril"
              : "Objectif au niveau du nombril (≈ 60 % de votre taille)",
          known
              ? "Distance : ≈ $dist m entre vous et le téléphone"
              : "Distance : ≈ 1,2 fois votre taille",
          "Téléphone vertical et d’aplomb (inclinaison 0°)",
          "Même hauteur et même distance pour la face et le profil",
        ],
        (t, cs) => _CameraScene(t, cs, h),
      ),
      _PageData(
        "Dernière vérification",
        const [
          "Tête et pieds visibles, avec une petite marge",
          "Fond uni, lumière uniforme, personne d’autre dans le cadre",
          "Respirez normalement, déclenchez après une expiration",
          "Utilisez un trépied ou le minuteur de 10 s",
        ],
        (t, cs) => _FrameScene(t, cs, widget.view),
      ),
    ];
    if (_face) {
      return [
        commonPages[0],
        _PageData(
          "Placer ses pieds",
          const [
            "Écartés de la largeur des épaules, parallèles",
            "Pointes vers l’avant, poids réparti également",
            "Pieds entiers dans le cadre",
          ],
          (t, cs) => _FeetScene(t, cs, widget.view),
        ),
        _PageData(
          "Placer ses bras",
          const [
            "Légèrement écartés du corps (10 à 15 cm)",
            "Mains détendues, paumes vers les cuisses",
            "Épaules relâchées, regard droit devant",
          ],
          (t, cs) => _ArmsScene(t, cs, widget.view),
        ),
        commonPages[1],
        commonPages[2],
      ];
    }

    return [
      commonPages[0],
      _PageData(
        "Tourner de 90°",
        const [
          "Tournez-vous sur place, pieds écartés de la largeur des épaules",
          "Le téléphone reste immobile : seul le corps pivote",
          "Pieds entiers dans le cadre",
        ],
        (t, cs) => _FeetScene(t, cs, widget.view),
      ),
      _PageData(
        "Placer ses bras",
        const [
          "Croisés sur la poitrine, coudes un peu relevés",
          "La taille doit rester bien dégagée",
          "Épaules relâchées",
        ],
        (t, cs) => _ArmsScene(t, cs, widget.view),
      ),
      _PageData(
        "Se tenir droit de profil",
        const [
          "Oreille, épaule, hanche et cheville alignées sur la verticale",
          "Dos naturel : ne vous penchez pas, ne creusez pas les reins",
          "Regardez droit devant, pas vers l’appareil",
          "Ventre relâché, et gardez le même côté d’une mesure à l’autre",
        ],
        (t, cs) => _PostureScene(t, cs),
      ),
      commonPages[1],
      commonPages[2],
    ];
  }

  void _done() => Navigator.of(context).pop(true);

  void _go(int delta) => _pages.animateToPage(
        _index + delta,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _data;
    final last = _index == data.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(_face ? "Photo de face (1/2)" : "Photo de profil (2/2)"),
        actions: [
          if (!last) TextButton(onPressed: _done, child: const Text("Passer")),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: data.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _buildPage(data[i], cs),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Visibility(
              visible: _index > 0,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: TextButton(
                onPressed: () => _go(-1),
                child: const Text("Précédent"),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < data.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 8,
                      width: i == _index ? 22 : 8,
                      decoration: BoxDecoration(
                        color: i == _index ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            last
                ? FilledButton.icon(
                    onPressed: _done,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text("Étape suivante"),
                  )
                : FilledButton(
                    onPressed: () => _go(1),
                    child: const Text("Suivant"),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_PageData d, ColorScheme cs) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (_, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: math.min(300, box.maxHeight * 0.5),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) =>
                    CustomPaint(painter: d.scene(_anim.value, cs)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              d.title,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final b in d.bullets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: text.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  _PageData(this.title, this.bullets, this.scene);

  final String title;
  final List<String> bullets;
  final _Scene Function(double t, ColorScheme cs) scene;
}

double _lerp(double a, double b, double p) => a + (b - a) * p;

double _phase(double t) {
  final raw = t < 0.25
      ? 0.0
      : t < 0.5
          ? (t - 0.25) / 0.25
          : t < 0.85
              ? 1.0
              : (1 - t) / 0.15;
  return Curves.easeInOut.transform(raw.clamp(0.0, 1.0));
}

abstract class _Scene extends CustomPainter {
  _Scene(this.t, ColorScheme cs)
      : body = cs.outlineVariant,
        accent = cs.primary,
        bad = cs.error;

  final double t;
  final Color body;
  final Color accent;
  final Color bad;

  double get vw;
  double get vh;
  void draw(Canvas c);

  double get pulse => 0.5 + 0.5 * math.sin(2 * math.pi * t * 3);

  @override
  void paint(Canvas c, Size s) {
    final k = math.min(s.width / vw, s.height / vh);
    c.save();
    c.translate((s.width - vw * k) / 2, (s.height - vh * k) / 2);
    c.scale(k);
    draw(c);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _Scene old) =>
      old.t != t || old.body != body || old.accent != accent || old.bad != bad;

  Paint get fill => Paint()..color = body;

  Paint stroke(Color col, double w) => Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void dash(Canvas c, Offset a, Offset b, Paint p) {
    const d = 5.0, g = 4.0;
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (double x = 0; x < len; x += d + g) {
      c.drawLine(a + dir * x, a + dir * math.min(x + d, len), p);
    }
  }

  void dashRect(Canvas c, Rect r, Paint p) {
    dash(c, r.topLeft, r.topRight, p);
    dash(c, r.topRight, r.bottomRight, p);
    dash(c, r.bottomRight, r.bottomLeft, p);
    dash(c, r.bottomLeft, r.topLeft, p);
  }

  void label(Canvas c, String s, Offset center, Color col, {double size = 14}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: col,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void figure(Canvas c, {required bool face, required double p}) {
    final q = face ? 0.0 : p;
    final limb = stroke(body, 9);
    c.drawLine(
      Offset(_lerp(88, 100, q), 147),
      Offset(_lerp(82, 98, q), 265),
      limb,
    );
    c.drawLine(
      Offset(_lerp(112, 100, q), 147),
      Offset(_lerp(118, 102, q), 265),
      limb,
    );
    final w = face ? 50.0 : _lerp(50, 28, p);
    c.drawRRect(
      RRect.fromLTRBR(
        100 - w / 2,
        52,
        100 + w / 2,
        147,
        const Radius.circular(14),
      ),
      fill,
    );
    c.drawCircle(const Offset(100, 30), 15, fill);
    final hw = face ? 36.0 : _lerp(36, 24, p);
    dash(c, Offset(100 - hw, 108), Offset(100 + hw, 108), stroke(accent, 2.5));
    if (face) {
      final a = 26 * math.pi / 180 * p;
      void arm(double sx, double ex, double sign) {
        c.save();
        c.translate(sx, 62);
        c.rotate(a * sign);
        c.translate(-sx, -62);
        c.drawLine(Offset(sx, 64), Offset(ex, 150), limb);
        c.restore();
      }

      arm(77, 72, 1);
      arm(123, 128, -1);
    } else {
      final hang = stroke(body.withOpacity(1 - p), 9);
      c.drawLine(
        Offset(_lerp(77, 100, p), 64),
        Offset(_lerp(72, 98, p), 150),
        hang,
      );
      c.drawLine(
        Offset(_lerp(123, 100, p), 64),
        Offset(_lerp(128, 102, p), 150),
        hang,
      );
      c.drawPath(
        Path()
          ..moveTo(100, 66)
          ..lineTo(112, 82)
          ..lineTo(94, 78),
        stroke(accent.withOpacity(p), 9),
      );
    }
  }
}

class _ClothesScene extends _Scene {
  _ClothesScene(super.t, super.cs);

  @override
  double get vw => 300;

  @override
  double get vh => 230;

  @override
  void draw(Canvas c) {
    c.drawCircle(const Offset(80, 30), 15, fill);
    c.drawRRect(
      RRect.fromLTRBR(30, 52, 130, 172, const Radius.circular(16)),
      Paint()..color = body.withOpacity(0.45),
    );
    dashRect(c, const Rect.fromLTRB(30, 52, 130, 172), stroke(bad, 3));
    c.drawCircle(const Offset(220, 30), 15, fill);
    final fit = RRect.fromLTRBR(192, 52, 248, 172, const Radius.circular(16));
    c.drawRRect(fit, fill);
    c.drawRRect(fit.inflate(2), stroke(accent, 3));
    dash(
      c,
      const Offset(180, 115),
      const Offset(260, 115),
      stroke(accent.withOpacity(0.35 + 0.65 * pulse), 2.5),
    );
    label(c, "✗ Ample", const Offset(80, 205), bad);
    label(c, "✓ Ajusté", const Offset(220, 205), accent);
  }
}

class _FeetScene extends _Scene {
  _FeetScene(super.t, super.cs, this.view);

  final PoseView view;

  @override
  double get vw => 200;

  @override
  double get vh => 215;

  @override
  void draw(Canvas c) {
    final ray = stroke(body, 2);
    c.drawLine(const Offset(100, 195), const Offset(55, 150), ray);
    c.drawLine(const Offset(100, 195), const Offset(145, 150), ray);
    c.drawRRect(
      RRect.fromLTRBR(90, 190, 110, 204, const Radius.circular(3)),
      Paint()..color = accent,
    );
    final p = view == PoseView.profil ? _phase(t) : 0.0;
    c.save();
    c.translate(100, 95);
    c.rotate(math.pi / 2 * p);
    c.translate(-100, -95);
    c.drawOval(
      Rect.fromCenter(center: const Offset(100, 70), width: 64, height: 18),
      fill,
    );
    c.drawCircle(
        const Offset(100, 70), 10, Paint()..color = body.withOpacity(0.7));
    c.drawPath(
      Path()
        ..moveTo(96, 81)
        ..lineTo(104, 81)
        ..lineTo(100, 89)
        ..close(),
      Paint()..color = accent,
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(84, 118), width: 16, height: 30),
      fill,
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(116, 118), width: 16, height: 30),
      fill,
    );
    dash(
      c,
      const Offset(84, 142),
      const Offset(116, 142),
      stroke(accent.withOpacity(0.4 + 0.6 * pulse), 2.5),
    );
    c.restore();
  }
}

class _ArmsScene extends _Scene {
  _ArmsScene(super.t, super.cs, this.view);

  final PoseView view;

  @override
  double get vw => 200;

  @override
  double get vh => 290;

  @override
  void draw(Canvas c) => figure(c, face: view == PoseView.face, p: _phase(t));
}

class _PostureScene extends _Scene {
  _PostureScene(super.t, super.cs);

  @override
  double get vw => 200;

  @override
  double get vh => 290;

  @override
  void draw(Canvas c) {
    dash(c, const Offset(100, 6), const Offset(100, 278), stroke(accent, 2));
    final p = _phase(t);
    c.save();
    c.translate(100, 265);
    c.rotate(9 * math.pi / 180 * (1 - p));
    c.translate(-100, -265);
    figure(c, face: false, p: 1);
    final dot = Paint()..color = accent;
    for (final y in const [30.0, 62.0, 147.0, 262.0]) {
      c.drawCircle(Offset(100, y), 4.5, dot);
    }
    final guide = stroke(accent.withOpacity(0.4 + 0.6 * pulse), 3);
    c.drawLine(const Offset(122, 30), const Offset(150, 30), guide);
    c.drawLine(const Offset(150, 30), const Offset(143, 24), guide);
    c.drawLine(const Offset(150, 30), const Offset(143, 36), guide);
    c.restore();
    label(
      c,
      p < 0.5 ? "✗ Penché" : "✓ Aligné",
      const Offset(40, 20),
      p < 0.5 ? bad : accent,
    );
  }
}

class _CameraScene extends _Scene {
  _CameraScene(super.t, super.cs, this.heightCm);

  final double heightCm;

  @override
  double get vw => 380;

  @override
  double get vh => 230;

  @override
  void draw(Canvas c) {
    const s = 100.0, floor = 205.0, px = 50.0;
    final h = heightCm / 100;
    final cam = 0.6 * h, d = 1.2 * h;
    final x = px + d * s;
    final cy = floor - cam * s;
    final top = floor - h * s;
    final e = 0.65 * d * s;

    c.drawLine(
        const Offset(0, floor), const Offset(380, floor), stroke(body, 2));
    c.drawPath(
      Path()
        ..moveTo(px, cy)
        ..lineTo(x, cy - e)
        ..lineTo(x, cy + e)
        ..close(),
      Paint()..color = accent.withOpacity(0.08 + 0.08 * pulse),
    );
    c.drawLine(Offset(px, cy + 12), const Offset(px, floor), stroke(body, 3));
    c.drawRRect(
      RRect.fromLTRBR(
          px - 5, cy - 12, px + 5, cy + 12, const Radius.circular(3)),
      Paint()..color = accent,
    );
    dash(c, Offset(px + 8, cy), Offset(x - 8, cy), stroke(accent, 2.5));
    c.drawLine(Offset(x, floor), Offset(x, top + 9), stroke(body, 10));
    c.drawCircle(Offset(x, top), 9, fill);
    c.drawCircle(Offset(x, cy), 5, Paint()..color = accent);
    label(
      c,
      "${d.toStringAsFixed(1).replaceAll('.', ',')} m",
      Offset((px + x) / 2, cy - 12),
      accent,
    );
    label(c, "${(cam * 100).round()} cm", Offset(px + 34, (cy + floor) / 2),
        accent);
    label(c, "Inclinaison 0°", const Offset(72, 16), body, size: 12);
  }
}

class _FrameScene extends _Scene {
  _FrameScene(super.t, super.cs, this.view);

  final PoseView view;

  @override
  double get vw => 200;

  @override
  double get vh => 290;

  @override
  void draw(Canvas c) {
    c.drawRRect(
      RRect.fromLTRBR(50, 4, 150, 286, const Radius.circular(18)),
      stroke(body, 4),
    );
    c.save();
    c.translate(15, 21.75);
    c.scale(0.85);
    figure(c, face: view == PoseView.face, p: 1);
    c.restore();
    final br = stroke(accent.withOpacity(0.4 + 0.6 * pulse), 4);
    const l = 14.0;
    for (final o in const [
      Offset(62, 16),
      Offset(138, 16),
      Offset(62, 274),
      Offset(138, 274),
    ]) {
      final sx = o.dx < 100 ? 1.0 : -1.0;
      final sy = o.dy < 100 ? 1.0 : -1.0;
      c.drawLine(o, o + Offset(l * sx, 0), br);
      c.drawLine(o, o + Offset(0, l * sy), br);
    }
  }
}
