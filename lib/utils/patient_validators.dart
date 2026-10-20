// Validation des champs du formulaire patient (exigence F-02).
//
// Fonctions pures, sans dépendance à Flutter : elles sont testées dans
// test/patient_validators_test.dart. Chaque validateur renvoie null si la
// saisie est valide, sinon le message d'erreur à afficher sous le champ.

/// Bornes acceptées. À ajuster ici uniquement si le LBA valide d'autres
/// valeurs : les messages d'erreur et les tests s'appuient sur ces constantes.
class PatientLimits {
  static const double minHeightCm = 100;
  static const double maxHeightCm = 230;
  static const double minWeightKg = 30;
  static const double maxWeightKg = 250;
  static const int minAge = 18;
  static const int maxAge = 100;

  static const int minPatientIdLength = 3;
  static const int maxPatientIdLength = 20;
}

/// Caractères autorisés dans l'identifiant patient : lettres sans accent,
/// chiffres, tiret et underscore. Pas d'espace, ce qui décourage la saisie
/// d'un « Prénom Nom » et évite tout caractère gênant côté serveur.
final RegExp _patientIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

/// Nombre décimal : 1 à 3 chiffres, puis éventuellement un séparateur
/// (point ou virgule) suivi de 1 ou 2 chiffres. Exclut volontairement
/// les formes que double.tryParse accepterait mais qui n'ont pas de sens ici
/// (« 1e2 », « -70 », « NaN », « Infinity »).
final RegExp _decimalPattern = RegExp(r'^\d{1,3}([.,]\d{1,2})?$');

/// Entier positif de 1 à 3 chiffres.
final RegExp _integerPattern = RegExp(r'^\d{1,3}$');

/// Convertit une saisie décimale en double, en acceptant la virgule du
/// clavier français (« 72,5 » → 72.5). Renvoie null si la saisie n'est pas
/// un nombre au format attendu.
double? parseDecimal(String input) {
  final value = input.trim();
  if (!_decimalPattern.hasMatch(value)) return null;
  return double.tryParse(value.replaceAll(',', '.'));
}

/// Convertit une saisie entière (âge). Renvoie null si invalide.
int? parseInteger(String input) {
  final value = input.trim();
  if (!_integerPattern.hasMatch(value)) return null;
  return int.tryParse(value);
}

/// Formate une borne sans « .0 » inutile (100.0 → « 100 »).
String _fmt(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String? validatePatientId(String input) {
  final value = input.trim();
  if (value.isEmpty) {
    return 'Please enter a patient ID or pseudonym.';
  }
  if (value.length < PatientLimits.minPatientIdLength ||
      value.length > PatientLimits.maxPatientIdLength) {
    return 'Patient ID must be ${PatientLimits.minPatientIdLength} to '
        '${PatientLimits.maxPatientIdLength} characters long.';
  }
  if (!_patientIdPattern.hasMatch(value)) {
    return 'Use only letters (no accents), digits, - and _ (no spaces).';
  }
  return null;
}

String? validateHeight(String input) => _validateDecimalInRange(
      input,
      fieldName: 'Height',
      unit: 'cm',
      min: PatientLimits.minHeightCm,
      max: PatientLimits.maxHeightCm,
    );

String? validateWeight(String input) => _validateDecimalInRange(
      input,
      fieldName: 'Weight',
      unit: 'kg',
      min: PatientLimits.minWeightKg,
      max: PatientLimits.maxWeightKg,
    );

String? validateAge(String input) {
  if (input.trim().isEmpty) {
    return 'Please fill out the Age field.';
  }
  final age = parseInteger(input);
  if (age == null) {
    return 'Age must be a whole number.';
  }
  if (age < PatientLimits.minAge || age > PatientLimits.maxAge) {
    return 'Age must be between ${PatientLimits.minAge} '
        'and ${PatientLimits.maxAge} years.';
  }
  return null;
}

String? validateSex(String? selected) =>
    selected == null ? 'Please select a sex.' : null;

String? _validateDecimalInRange(
  String input, {
  required String fieldName,
  required String unit,
  required double min,
  required double max,
}) {
  if (input.trim().isEmpty) {
    return 'Please fill out the $fieldName field.';
  }
  final value = parseDecimal(input);
  if (value == null) {
    return '$fieldName must be a number (e.g. 72.5 or 72,5).';
  }
  if (value < min || value > max) {
    return '$fieldName must be between ${_fmt(min)} and ${_fmt(max)} $unit.';
  }
  return null;
}
