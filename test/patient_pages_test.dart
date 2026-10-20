import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:circumfit_v3/check_detail_page.dart';
import 'package:circumfit_v3/history_page.dart';
import 'package:circumfit_v3/utils/patient_repository.dart';

/// Une fiche P001 déjà enregistrée, au format stocké par PatientRepository.
Map<String, Object> seedP001() => {
      PatientRepository.storageKey: jsonEncode([
        {
          'patientId': 'P001',
          'sex': 'Female',
          'age': 45,
          'weightKg': 72.5,
          'heightCm': 168.0,
          'createdAt': '2026-10-01T08:00:00.000Z',
          'updatedAt': '2026-10-01T08:00:00.000Z',
        }
      ]),
    };

/// 600 x 1200 points logiques : la police de test (chaque lettre est un
/// carré) est bien plus large que la vraie.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openHistory(WidgetTester tester) async {
  useTallScreen(tester);
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: HistoryPage())),
  );
  await tester.pumpAndSettle();
}

Future<void> fillPatientForm(
  WidgetTester tester, {
  required String id,
  required String height,
  required String weight,
  required String age,
  required String sex,
}) async {
  await tester.enterText(find.byKey(const Key('patient_field_id')), id);
  await tester.enterText(find.byKey(const Key('patient_field_height')), height);
  await tester.enterText(find.byKey(const Key('patient_field_weight')), weight);
  await tester.enterText(find.byKey(const Key('patient_field_age')), age);
  await tapKey(tester, 'patient_sex_$sex');
}

void main() {
  group('HistoryPage + PatientEditPage', () {
    testWidgets('liste vide au départ', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHistory(tester);
      expect(find.byKey(const Key('patients_empty')), findsOneWidget);
    });

    testWidgets('crée une fiche', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHistory(tester);

      await tapKey(tester, 'patient_add');
      expect(find.text('New patient record'), findsOneWidget);
      expect(find.byKey(const Key('patient_delete')), findsNothing);

      await fillPatientForm(tester,
          id: 'P042', height: '170,5', weight: '80', age: '33', sex: 'Male');
      await tapKey(tester, 'patient_save');

      // Retour à la liste, qui affiche la nouvelle fiche.
      expect(find.byKey(const Key('patient_tile_P042')), findsOneWidget);
      expect(find.text('Male · 33 y · 80 kg · 170.5 cm'), findsOneWidget);
      final saved = await PatientRepository().find('P042');
      expect(saved!.heightCm, 170.5);
    });

    testWidgets('formulaire vide : erreurs affichées, rien enregistré',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openHistory(tester);
      await tapKey(tester, 'patient_add');
      await tapKey(tester, 'patient_save');

      expect(find.text('Please enter a patient ID or pseudonym.'),
          findsOneWidget);
      expect(find.text('Please select a sex.'), findsOneWidget);
      expect(find.text('New patient record'), findsOneWidget);
      expect(await PatientRepository().loadAll(), isEmpty);
    });

    testWidgets('refuse un identifiant déjà pris', (tester) async {
      SharedPreferences.setMockInitialValues(seedP001());
      await openHistory(tester);
      await tapKey(tester, 'patient_add');
      await fillPatientForm(tester,
          id: 'p001', height: '180', weight: '90', age: '50', sex: 'Male');
      await tapKey(tester, 'patient_save');

      expect(find.text('Another record already uses this ID.'),
          findsOneWidget);
      expect(await PatientRepository().loadAll(), hasLength(1));
    });

    testWidgets('modifie une fiche existante', (tester) async {
      SharedPreferences.setMockInitialValues(seedP001());
      await openHistory(tester);
      expect(find.text('Female · 45 y · 72.5 kg · 168 cm'), findsOneWidget);

      await tapKey(tester, 'patient_tile_P001');
      expect(find.text('Edit patient record'), findsOneWidget);
      // Formulaire pré-rempli.
      expect(find.text('72.5'), findsOneWidget);
      expect(find.text('168'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('patient_field_weight')), '70');
      await tapKey(tester, 'patient_save');

      expect(find.text('Female · 45 y · 70 kg · 168 cm'), findsOneWidget);
      final saved = await PatientRepository().find('P001');
      expect(saved!.weightKg, 70.0);
      expect(saved.createdAt, DateTime.utc(2026, 10, 1, 8));
    });

    testWidgets('supprime une fiche après confirmation', (tester) async {
      SharedPreferences.setMockInitialValues(seedP001());
      await openHistory(tester);
      await tapKey(tester, 'patient_tile_P001');

      // Annuler ne supprime rien.
      await tapKey(tester, 'patient_delete');
      await tapKey(tester, 'patient_delete_cancel');
      expect(find.text('Edit patient record'), findsOneWidget);
      expect(await PatientRepository().find('P001'), isNotNull);

      await tapKey(tester, 'patient_delete');
      await tapKey(tester, 'patient_delete_confirm');
      expect(find.byKey(const Key('patients_empty')), findsOneWidget);
      expect(await PatientRepository().find('P001'), isNull);
    });

    testWidgets('données illisibles : message d\'erreur', (tester) async {
      SharedPreferences.setMockInitialValues(
          {PatientRepository.storageKey: 'pas du json'});
      await openHistory(tester);
      expect(find.byKey(const Key('patients_error')), findsOneWidget);
    });
  });

  group('CheckDetailPage (bouton Next)', () {
    Future<void> fillCheckDetails(WidgetTester tester,
        {required String weight}) async {
      useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: CheckDetailPage()));
      // Ordre des champs : identifiant, taille, poids, âge.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'P001');
      await tester.enterText(fields.at(1), '168');
      await tester.enterText(fields.at(2), weight);
      await tester.enterText(fields.at(3), '45');
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    testWidgets('crée la fiche puis affiche les consignes photo',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await fillCheckDetails(tester, weight: '72,5');

      expect(find.text('Photo Instructions'), findsOneWidget);
      final saved = await PatientRepository().find('P001');
      expect(saved!.weightKg, 72.5);
      expect(saved.sex, 'Female');
    });

    testWidgets('fiche identique : pas de question', (tester) async {
      SharedPreferences.setMockInitialValues(seedP001());
      await fillCheckDetails(tester, weight: '72.5');

      expect(find.text('Update patient record?'), findsNothing);
      expect(find.text('Photo Instructions'), findsOneWidget);
    });

    testWidgets('valeurs différentes : Cancel garde la fiche et le formulaire',
        (tester) async {
      SharedPreferences.setMockInitialValues(seedP001());
      await fillCheckDetails(tester, weight: '75');

      expect(find.text('Update patient record?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('record_update_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Photo Instructions'), findsNothing);
      expect((await PatientRepository().find('P001'))!.weightKg, 72.5);
    });

    testWidgets('valeurs différentes : Update met la fiche à jour',
        (tester) async {
      SharedPreferences.setMockInitialValues(seedP001());
      await fillCheckDetails(tester, weight: '75');

      await tester.tap(find.byKey(const Key('record_update_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Photo Instructions'), findsOneWidget);
      expect((await PatientRepository().find('P001'))!.weightKg, 75.0);
    });
  });
}
