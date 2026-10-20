import 'package:flutter_test/flutter_test.dart';
import 'package:circumfit_v3/utils/consent.dart';

void main() {
  final n = ConsentText.statements.length;
  List<bool> all(bool v) => List<bool>.filled(n, v);

  group('allStatementsAccepted', () {
    test('vrai seulement si tout est coché', () {
      expect(allStatementsAccepted(all(true)), isTrue);
      expect(allStatementsAccepted(all(false)), isFalse);
      for (var i = 0; i < n; i++) {
        final checks = all(true)..[i] = false;
        expect(allStatementsAccepted(checks), isFalse, reason: 'point $i');
      }
    });

    test('faux si le nombre de cases ne correspond pas au texte', () {
      expect(allStatementsAccepted([]), isFalse);
      expect(allStatementsAccepted(List<bool>.filled(n + 1, true)), isFalse);
    });
  });

  group('ConsentRecord.give', () {
    test('horodate en UTC, tronqué à la seconde', () {
      final r = ConsentRecord.give(
        patientId: 'PAT-001',
        checks: all(true),
        now: DateTime.utc(2026, 10, 20, 16, 34, 12, 789, 123),
      );
      expect(r.givenAtUtc, DateTime.utc(2026, 10, 20, 16, 34, 12));
      expect(r.givenAtUtc.isUtc, isTrue);
      expect(r.timestampIso, '2026-10-20T16:34:12.000Z');
      expect(r.textVersion, ConsentText.version);
    });

    test('heure locale convertie en UTC', () {
      final local = DateTime(2026, 10, 20, 18, 34, 12);
      final r = ConsentRecord.give(
          patientId: 'PAT-001', checks: all(true), now: local);
      expect(r.givenAtUtc.isAtSameMomentAs(local), isTrue);
    });

    test('sans date fournie, prend l\'heure actuelle', () {
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      final r = ConsentRecord.give(patientId: 'PAT-001', checks: all(true));
      final after = DateTime.now().toUtc();
      expect(r.givenAtUtc.isBefore(before), isFalse);
      expect(r.givenAtUtc.isAfter(after), isFalse);
    });

    test('refuse un consentement incomplet', () {
      final checks = all(true)..[n - 1] = false;
      expect(() => ConsentRecord.give(patientId: 'PAT-001', checks: checks),
          throwsArgumentError);
    });

    test('refuse un identifiant vide', () {
      expect(() => ConsentRecord.give(patientId: '   ', checks: all(true)),
          throwsArgumentError);
    });

    test('identifiant nettoyé et lié au patient', () {
      final r = ConsentRecord.give(patientId: ' PAT-001 ', checks: all(true));
      expect(r.patientId, 'PAT-001');
      expect(r.coversPatient('PAT-001'), isTrue);
      expect(r.coversPatient('PAT-002'), isFalse);
    });
  });

  test('toFormFields : champs envoyés au serveur', () {
    final r = ConsentRecord.give(
      patientId: 'PAT-001',
      checks: all(true),
      now: DateTime.utc(2026, 10, 20, 16, 34, 12),
    );
    expect(r.toFormFields(), {
      'consent_given': 'true',
      'consent_timestamp': '2026-10-20T16:34:12.000Z',
      'consent_version': ConsentText.version,
    });
  });

  test('formatConsentTimestamp : jj/mm/aaaa à hh:mm:ss en heure locale', () {
    expect(formatConsentTimestamp(DateTime(2026, 3, 5, 8, 4, 9)),
        '05/03/2026 à 08:04:09');
    final utc = DateTime.utc(2026, 10, 20, 16, 34, 12);
    expect(formatConsentTimestamp(utc), formatConsentTimestamp(utc.toLocal()));
  });
}
