// Stockage local des fiches patient (exigence F-04).
//
// Les fiches sont rangées dans shared_preferences, sous une seule clé, en
// JSON. shared_preferences fonctionne sur iPhone (NSUserDefaults) et en
// version web (localStorage du navigateur), notre moyen de test.
//
// ATTENTION : les données ne sont PAS chiffrées. Le chiffrement est l'objet
// de F-40 ; il suffira alors de changer l'intérieur de cette classe, les
// écrans n'appellent que ses méthodes publiques.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'patient_record.dart';

/// Les fiches enregistrées ne peuvent pas être lues ou écrites.
class PatientStorageException implements Exception {
  final String message;
  const PatientStorageException(this.message);
  @override
  String toString() => message;
}

/// Une autre fiche porte déjà cet identifiant.
class DuplicatePatientIdException implements Exception {
  final String patientId;
  const DuplicatePatientIdException(this.patientId);
  @override
  String toString() => 'A record already exists for $patientId.';
}

/// La fiche à modifier n'existe plus (supprimée entre-temps).
class PatientNotFoundException implements Exception {
  final String patientId;
  const PatientNotFoundException(this.patientId);
  @override
  String toString() => 'No record found for $patientId.';
}

class PatientRepository {
  /// Clé de stockage. Le « v1 » permettra de migrer si le format change.
  static const String storageKey = 'circumfit_patients_v1';

  final DateTime Function() _now;

  /// [now] n'est passé que par les tests, pour maîtriser les dates.
  PatientRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Toutes les fiches, triées par identifiant (sans tenir compte de la casse).
  Future<List<PatientRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final records = _decode(prefs.getString(storageKey));
    records.sort((a, b) =>
        a.patientId.toUpperCase().compareTo(b.patientId.toUpperCase()));
    return records;
  }

  /// La fiche de cet identifiant, ou null si elle n'existe pas.
  Future<PatientRecord?> find(String patientId) async {
    for (final record in await loadAll()) {
      if (samePatientId(record.patientId, patientId)) return record;
    }
    return null;
  }

  /// Crée une fiche. Lève DuplicatePatientIdException si l'identifiant
  /// est déjà pris.
  Future<PatientRecord> create({
    required String patientId,
    required String sex,
    required int age,
    required double weightKg,
    required double heightCm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _decode(prefs.getString(storageKey));
    final id = patientId.trim();
    if (records.any((r) => samePatientId(r.patientId, id))) {
      throw DuplicatePatientIdException(id);
    }
    final now = _now().toUtc();
    final record = PatientRecord(
      patientId: id,
      sex: sex,
      age: age,
      weightKg: weightKg,
      heightCm: heightCm,
      createdAt: now,
      updatedAt: now,
    );
    records.add(record);
    await _save(prefs, records);
    return record;
  }

  /// Modifie la fiche [originalId]. L'identifiant peut changer, à condition
  /// de ne pas reprendre celui d'une autre fiche. La date de création est
  /// conservée.
  Future<PatientRecord> update(
    String originalId, {
    required String patientId,
    required String sex,
    required int age,
    required double weightKg,
    required double heightCm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _decode(prefs.getString(storageKey));
    final index =
        records.indexWhere((r) => samePatientId(r.patientId, originalId));
    if (index < 0) throw PatientNotFoundException(originalId.trim());
    final id = patientId.trim();
    for (var i = 0; i < records.length; i++) {
      if (i != index && samePatientId(records[i].patientId, id)) {
        throw DuplicatePatientIdException(id);
      }
    }
    final updated = PatientRecord(
      patientId: id,
      sex: sex,
      age: age,
      weightKg: weightKg,
      heightCm: heightCm,
      createdAt: records[index].createdAt,
      updatedAt: _now().toUtc(),
    );
    records[index] = updated;
    await _save(prefs, records);
    return updated;
  }

  /// Supprime la fiche. Renvoie false si elle n'existait pas.
  /// (Les images ne sont pas stockées sur l'appareil : leur suppression
  /// relève de F-44.)
  Future<bool> delete(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _decode(prefs.getString(storageKey));
    final before = records.length;
    records.removeWhere((r) => samePatientId(r.patientId, patientId));
    if (records.length == before) return false;
    await _save(prefs, records);
    return true;
  }

  /// Si le contenu stocké est illisible, on lève une exception au lieu de
  /// renvoyer une liste vide : sinon le prochain enregistrement écraserait
  /// toutes les fiches existantes.
  List<PatientRecord> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <PatientRecord>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              PatientRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      throw const PatientStorageException(
          'Saved patient records are unreadable.');
    }
  }

  Future<void> _save(
      SharedPreferences prefs, List<PatientRecord> records) async {
    final ok = await prefs.setString(
      storageKey,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
    if (!ok) {
      throw const PatientStorageException(
          'The patient record could not be saved on this device.');
    }
  }
}
