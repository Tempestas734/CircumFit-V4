import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:circumfit_v3/utils/patient_record.dart';
import 'package:circumfit_v3/utils/patient_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Horloge contrôlée : chaque appel avance d'une minute.
  late DateTime clock;
  late PatientRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime.utc(2026, 10, 20, 9, 0, 0);
    repo = PatientRepository(now: () {
      clock = clock.add(const Duration(minutes: 1));
      return clock;
    });
  });

  Future<PatientRecord> createP001() => repo.create(
        patientId: ' P001 ',
        sex: 'Female',
        age: 45,
        weightKg: 72.5,
        heightCm: 168,
      );

  group('PatientRecord', () {
    test('aller-retour JSON sans perte', () {
      final record = PatientRecord(
        patientId: 'P001',
        sex: 'Male',
        age: 30,
        weightKg: 80.25,
        heightCm: 180,
        createdAt: DateTime.utc(2026, 10, 1, 8),
        updatedAt: DateTime.utc(2026, 10, 2, 8),
      );
      final copy = PatientRecord.fromJson(
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>);
      expect(copy.toJson(), record.toJson());
    });

    test('accepte un poids entier dans le JSON (version web)', () {
      final copy = PatientRecord.fromJson({
        'patientId': 'P002',
        'sex': 'Female',
        'age': 50,
        'weightKg': 72,
        'heightCm': 165,
        'createdAt': '2026-10-01T08:00:00.000Z',
        'updatedAt': '2026-10-01T08:00:00.000Z',
      });
      expect(copy.weightKg, 72.0);
      expect(copy.heightCm, 165.0);
    });

    test('samePatientId ignore la casse et les espaces', () {
      expect(samePatientId('p001', ' P001 '), isTrue);
      expect(samePatientId('P001', 'P002'), isFalse);
    });

    test('formatMeasure retire le .0 inutile', () {
      expect(formatMeasure(72.0), '72');
      expect(formatMeasure(72.5), '72.5');
    });
  });

  group('PatientRepository', () {
    test('aucune fiche au départ', () async {
      expect(await repo.loadAll(), isEmpty);
    });

    test('crée une fiche (identifiant nettoyé, dates UTC)', () async {
      final created = await createP001();
      expect(created.patientId, 'P001');
      expect(created.createdAt, DateTime.utc(2026, 10, 20, 9, 1));
      expect(created.updatedAt, created.createdAt);

      final all = await repo.loadAll();
      expect(all, hasLength(1));
      expect(all.single.toJson(), created.toJson());
    });

    test('les fiches survivent à un nouveau PatientRepository', () async {
      await createP001();
      final other = PatientRepository();
      expect((await other.find('P001'))?.age, 45);
    });

    test('refuse un identifiant déjà pris, même en minuscules', () async {
      await createP001();
      await expectLater(
        repo.create(
            patientId: 'p001',
            sex: 'Male',
            age: 20,
            weightKg: 60,
            heightCm: 170),
        throwsA(isA<DuplicatePatientIdException>()),
      );
      expect(await repo.loadAll(), hasLength(1));
    });

    test('find ignore la casse et renvoie null si absent', () async {
      await createP001();
      expect((await repo.find('p001'))?.patientId, 'P001');
      expect(await repo.find('P999'), isNull);
    });

    test('loadAll trie par identifiant', () async {
      for (final id in ['P010', 'a002', 'B001']) {
        await repo.create(
            patientId: id, sex: 'Male', age: 30, weightKg: 70, heightCm: 175);
      }
      final ids = (await repo.loadAll()).map((r) => r.patientId).toList();
      expect(ids, ['a002', 'B001', 'P010']);
    });

    test('modifie une fiche en gardant sa date de création', () async {
      final created = await createP001();
      final updated = await repo.update(
        'P001',
        patientId: 'P001',
        sex: 'Female',
        age: 46,
        weightKg: 70,
        heightCm: 168,
      );
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
      final stored = await repo.find('P001');
      expect(stored!.age, 46);
      expect(stored.weightKg, 70.0);
    });

    test('peut renommer une fiche', () async {
      await createP001();
      await repo.update('P001',
          patientId: 'P001-B',
          sex: 'Female',
          age: 45,
          weightKg: 72.5,
          heightCm: 168);
      expect(await repo.find('P001'), isNull);
      expect(await repo.find('P001-B'), isNotNull);
      expect(await repo.loadAll(), hasLength(1));
    });

    test('peut changer seulement la casse de son propre identifiant',
        () async {
      await createP001();
      await repo.update('P001',
          patientId: 'p001',
          sex: 'Female',
          age: 45,
          weightKg: 72.5,
          heightCm: 168);
      expect((await repo.loadAll()).single.patientId, 'p001');
    });

    test('refuse de renommer vers l\'identifiant d\'une autre fiche',
        () async {
      await createP001();
      await repo.create(
          patientId: 'P002', sex: 'Male', age: 30, weightKg: 80, heightCm: 180);
      await expectLater(
        repo.update('P002',
            patientId: 'P001',
            sex: 'Male',
            age: 30,
            weightKg: 80,
            heightCm: 180),
        throwsA(isA<DuplicatePatientIdException>()),
      );
      expect((await repo.find('P002'))?.sex, 'Male');
    });

    test('modifier une fiche absente lève PatientNotFoundException',
        () async {
      await expectLater(
        repo.update('P404',
            patientId: 'P404',
            sex: 'Male',
            age: 30,
            weightKg: 80,
            heightCm: 180),
        throwsA(isA<PatientNotFoundException>()),
      );
    });

    test('supprime une fiche et seulement elle', () async {
      await createP001();
      await repo.create(
          patientId: 'P002', sex: 'Male', age: 30, weightKg: 80, heightCm: 180);
      expect(await repo.delete('p001'), isTrue);
      final ids = (await repo.loadAll()).map((r) => r.patientId).toList();
      expect(ids, ['P002']);
      expect(await repo.delete('P001'), isFalse);
    });

    test('données illisibles : erreur, et rien n\'est écrasé', () async {
      SharedPreferences.setMockInitialValues(
          {PatientRepository.storageKey: 'pas du json'});
      await expectLater(
          repo.loadAll(), throwsA(isA<PatientStorageException>()));
      await expectLater(
          createP001(), throwsA(isA<PatientStorageException>()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PatientRepository.storageKey), 'pas du json');
    });
  });
}
