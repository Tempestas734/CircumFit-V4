import 'package:flutter_test/flutter_test.dart';
import 'package:circumfit_v3/utils/patient_validators.dart';

void main() {
  group('parseDecimal', () {
    test('accepte le point et la virgule', () {
      expect(parseDecimal('72.5'), 72.5);
      expect(parseDecimal('72,5'), 72.5);
      expect(parseDecimal('172'), 172.0);
      expect(parseDecimal(' 80,25 '), 80.25);
    });

    test('refuse les formats inattendus', () {
      for (final input in [
        '',
        ',5',
        '72,',
        '72,5,1',
        '72.5.1',
        '72,555',
        '1e2',
        '-70',
        'NaN',
        'Infinity',
        'abc',
        '1000',
      ]) {
        expect(parseDecimal(input), isNull, reason: '"$input"');
      }
    });
  });

  group('parseInteger', () {
    test('accepte un entier', () {
      expect(parseInteger('42'), 42);
      expect(parseInteger(' 42 '), 42);
    });
    test('refuse décimales et signes', () {
      for (final input in ['', '42.0', '42,5', '-3', '1000', 'x']) {
        expect(parseInteger(input), isNull, reason: '"$input"');
      }
    });
  });

  group('validateHeight (100-230 cm)', () {
    test('valeurs valides, bornes incluses', () {
      for (final input in ['100', '230', '172,5', '172.5']) {
        expect(validateHeight(input), isNull, reason: '"$input"');
      }
    });
    test('hors bornes', () {
      expect(validateHeight('99,9'), contains('between 100 and 230 cm'));
      expect(validateHeight('230.1'), contains('between 100 and 230 cm'));
    });
    test('vide ou non numérique', () {
      expect(validateHeight('  '), contains('fill out'));
      expect(validateHeight('abc'), contains('must be a number'));
    });
  });

  group('validateWeight (30-250 kg)', () {
    test('valeurs valides, bornes incluses', () {
      for (final input in ['30', '250', '72,5', '72.35']) {
        expect(validateWeight(input), isNull, reason: '"$input"');
      }
    });
    test('hors bornes', () {
      expect(validateWeight('29,9'), contains('between 30 and 250 kg'));
      expect(validateWeight('250,5'), contains('between 30 and 250 kg'));
    });
    test('vide ou non numérique', () {
      expect(validateWeight(''), contains('fill out'));
      expect(validateWeight('1e2'), contains('must be a number'));
    });
  });

  group('validateAge (18-100 ans)', () {
    test('valeurs valides, bornes incluses', () {
      for (final input in ['18', '45', '100']) {
        expect(validateAge(input), isNull, reason: '"$input"');
      }
    });
    test('hors bornes', () {
      expect(validateAge('17'), contains('between 18 and 100'));
      expect(validateAge('101'), contains('between 18 and 100'));
    });
    test('vide ou non entier', () {
      expect(validateAge(''), contains('fill out'));
      expect(validateAge('45,5'), contains('whole number'));
    });
  });

  group('validatePatientId', () {
    test('identifiants valides', () {
      for (final input in ['P042', 'abc', 'patient_01', 'LBA-2026-07', ' P042 ']) {
        expect(validatePatientId(input), isNull, reason: '"$input"');
      }
    });
    test('vide', () {
      expect(validatePatientId('   '), contains('Please enter'));
    });
    test('longueur', () {
      expect(validatePatientId('ab'), contains('3 to 20'));
      expect(validatePatientId('a' * 21), contains('3 to 20'));
      expect(validatePatientId('a' * 20), isNull);
    });
    test('caractères interdits (espaces, accents, ponctuation)', () {
      for (final input in ['Jean Dupont', 'Hélène', 'p@042', 'a/b/c', 'id;drop']) {
        expect(validatePatientId(input), contains('Use only'),
            reason: '"$input"');
      }
    });
  });

  group('validateSex', () {
    test('obligatoire', () {
      expect(validateSex(null), isNotNull);
      expect(validateSex('Male'), isNull);
      expect(validateSex('Female'), isNull);
    });
  });
}
