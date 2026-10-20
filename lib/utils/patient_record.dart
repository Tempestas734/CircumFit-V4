// Fiche patient enregistrée sur l'appareil (exigence F-04).
//
// Classe pure, sans dépendance à Flutter : la conversion JSON est testée
// dans test/patient_repository_test.dart.

/// Une fiche patient : les données du formulaire « Check details »,
/// plus les dates de création et de dernière modification (en UTC).
class PatientRecord {
  /// Identifiant ou pseudonyme (validé par validatePatientId, F-02).
  final String patientId;

  /// 'Male' ou 'Female', les mêmes valeurs que le formulaire et le serveur.
  final String sex;
  final int age;
  final double weightKg;
  final double heightCm;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PatientRecord({
    required this.patientId,
    required this.sex,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Vrai si les données saisies sont identiques (les dates sont ignorées).
  bool hasSameDataAs({
    required String patientId,
    required String sex,
    required int age,
    required double weightKg,
    required double heightCm,
  }) =>
      this.patientId == patientId.trim() &&
      this.sex == sex &&
      this.age == age &&
      this.weightKg == weightKg &&
      this.heightCm == heightCm;

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'sex': sex,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  /// Lève une erreur (TypeError, FormatException) si le JSON est incomplet :
  /// PatientRepository la transforme en PatientStorageException.
  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
        patientId: json['patientId'] as String,
        sex: json['sex'] as String,
        // « as num » : jsonDecode rend 72 (int) pour un poids de 72.0.
        age: (json['age'] as num).toInt(),
        weightKg: (json['weightKg'] as num).toDouble(),
        heightCm: (json['heightCm'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

/// Deux identifiants désignent le même patient sans tenir compte des
/// majuscules ni des espaces autour : « p001 » et « P001 » sont la même fiche.
bool samePatientId(String a, String b) =>
    a.trim().toUpperCase() == b.trim().toUpperCase();

/// Affiche une valeur sans « .0 » inutile (72.0 → « 72 », 72.5 → « 72.5 »).
/// Sert à pré-remplir le formulaire de modification.
String formatMeasure(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
