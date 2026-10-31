import 'dart:convert';
import 'dart:typed_data';

import 'package:circumfit_v3/face_profile_photos_page.dart';
import 'package:circumfit_v3/guided_camera_page.dart';
import 'package:circumfit_v3/photo_tutorial_page.dart';
import 'package:circumfit_v3/utils/consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CaptureRouteObserver extends NavigatorObserver {
  int captureCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is! MaterialPageRoute<GuidedCameraCapture>) return;

    captureCount++;
    final navigator = route.navigator;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) {
        navigator.pop(
          GuidedCameraCapture(
            imageBytes: Uint8List.fromList(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
              ),
            ),
            localWaistWidthCm: 40,
            localMeasurementError: null,
          ),
        );
      }
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final observer = _CaptureRouteObserver();
  final consent = ConsentRecord.give(
    patientId: 'P001',
    checks: List<bool>.filled(ConsentText.statements.length, true),
    now: DateTime.utc(2026, 10, 31, 16),
  );

  setUp(() {
    observer.captureCount = 0;
  });

  Future<void> startFlow(WidgetTester tester, ConsentRecord record) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: FaceProfilePhotosPage(
          userHeight: 170,
          patientId: 'P001',
          sex: 'Female',
          age: 30,
          weightKg: 60,
          consent: record,
        ),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    if (record.coversPatient('P001')) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  Future<void> skipTutorialAndCapture(WidgetTester tester) async {
    expect(find.byType(PhotoTutorialPage), findsOneWidget);
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
  }

  testWidgets('captures face then profile through the guided flow',
      (tester) async {
    await startFlow(tester, consent);

    await skipTutorialAndCapture(tester);
    expect(find.text('Photo de face'), findsOneWidget);
    expect(find.byKey(const Key('front_photo_next')), findsOneWidget);
    expect(observer.captureCount, 1);

    await tester.tap(find.byKey(const Key('front_photo_next')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoTutorialPage), findsOneWidget);
    expect(find.text('Photo de profil (2/2)'), findsOneWidget);

    await skipTutorialAndCapture(tester);
    expect(find.text('Photo de profil'), findsOneWidget);
    expect(find.byKey(const Key('side_photo_send')), findsOneWidget);
    expect(observer.captureCount, 2);
  });

  testWidgets('refuses to open the camera with consent for another patient',
      (tester) async {
    final otherPatientConsent = ConsentRecord.give(
      patientId: 'P002',
      checks: List<bool>.filled(ConsentText.statements.length, true),
    );

    await startFlow(tester, otherPatientConsent);

    expect(find.text('Consentement manquant pour ce patient.'), findsOneWidget);
    expect(find.byType(PhotoTutorialPage), findsNothing);
    expect(observer.captureCount, 0);
  });
}
