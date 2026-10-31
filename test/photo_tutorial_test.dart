import 'package:circumfit_v3/photo_tutorial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('face tutorial covers clothing, feet, arms and camera setup',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const PhotoTutorialPage(view: PoseView.face, heightCm: 170),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bien s’habiller'), findsOneWidget);
    expect(find.textContaining('Haut ajusté'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Placer ses pieds'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Placer ses bras'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Régler le téléphone'), findsOneWidget);
    expect(find.textContaining('Objectif à ≈ 102 cm'), findsOneWidget);
    expect(find.textContaining('Distance : ≈ 2,0 m'), findsOneWidget);
  });
}
