import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circumfit_v3/consent_page.dart';
import 'package:circumfit_v3/utils/consent.dart';

/// Ouvre ConsentPage depuis une page hôte et mémorise ce qu'elle renvoie.
class _Host extends StatelessWidget {
  final void Function(ConsentRecord?) onResult;
  const _Host({required this.onResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final r = await Navigator.push<ConsentRecord>(
              context,
              MaterialPageRoute(
                  builder: (_) => const ConsentPage(patientId: 'PAT-001')),
            );
            onResult(r);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  late ConsentRecord? result;
  late bool returned;

  Future<void> openConsent(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    returned = false;
    result = null;
    await tester.pumpWidget(MaterialApp(
      home: _Host(onResult: (r) {
        returned = true;
        result = r;
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ElevatedButton acceptButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(const Key('consent_accept')));

  testWidgets('affiche le patient et bloque la validation au départ',
      (tester) async {
    await openConsent(tester);
    expect(find.text('Patient : PAT-001'), findsOneWidget);
    expect(acceptButton(tester).onPressed, isNull);
  });

  testWidgets('validation possible seulement quand tout est coché',
      (tester) async {
    await openConsent(tester);
    final n = ConsentText.statements.length;
    for (var i = 0; i < n; i++) {
      expect(acceptButton(tester).onPressed, isNull, reason: 'après $i cases');
      await tester.ensureVisible(find.byKey(Key('consent_check_$i')));
      await tester.tap(find.byKey(Key('consent_check_$i')));
      await tester.pump();
    }
    expect(acceptButton(tester).onPressed, isNotNull);

    // Décocher une case rebloque le bouton.
    await tester.tap(find.byKey(const Key('consent_check_0')));
    await tester.pump();
    expect(acceptButton(tester).onPressed, isNull);
  });

  testWidgets('accepter renvoie un consentement horodaté', (tester) async {
    await openConsent(tester);
    for (var i = 0; i < ConsentText.statements.length; i++) {
      await tester.ensureVisible(find.byKey(Key('consent_check_$i')));
      await tester.tap(find.byKey(Key('consent_check_$i')));
      await tester.pump();
    }
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('consent_accept')));
    await tester.tap(find.byKey(const Key('consent_accept')));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNotNull);
    expect(result!.patientId, 'PAT-001');
    expect(result!.givenAtUtc.isBefore(before), isFalse);
    expect(find.byType(ConsentPage), findsNothing);
  });

  testWidgets('refuser renvoie null', (tester) async {
    await openConsent(tester);
    await tester.ensureVisible(find.byKey(const Key('consent_refuse')));
    await tester.tap(find.byKey(const Key('consent_refuse')));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });
}
