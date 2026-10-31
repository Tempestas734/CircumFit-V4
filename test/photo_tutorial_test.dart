import 'package:circumfit_v3/photo_tutorial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('face tutorial covers clothes, feet, arms, and camera setup',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoTutorialPage(view: PoseView.face, heightCm: 170),
      ),
    );
    await tester.pump();

    expect(find.text('Haut ajusté et uni, qui contraste avec le mur'),
        findsOneWidget);

    Future<void> nextPage() async {
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    await nextPage();
    expect(find.text('Écartés de la largeur des épaules, parallèles'),
        findsOneWidget);

    await nextPage();
    expect(
        find.text('Légèrement écartés du corps (10 à 15 cm)'), findsOneWidget);

    await nextPage();
    expect(find.text('Objectif à ≈ 102 cm du sol, au niveau du nombril'),
        findsOneWidget);
    expect(find.text('Distance : ≈ 2,0 m entre vous et le téléphone'),
        findsOneWidget);
    expect(find.text('Même hauteur et même distance pour la face et le profil'),
        findsOneWidget);
  });
}
