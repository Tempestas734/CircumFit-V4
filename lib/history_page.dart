import 'package:flutter/material.dart';

import 'patient_edit_page.dart';
import 'utils/patient_record.dart';
import 'utils/patient_repository.dart';

/// Onglet « Historique » : fiches patient enregistrées sur l'appareil
/// (exigence F-04). Toucher une fiche ouvre sa modification / suppression ;
/// « New patient » en crée une.
///
/// Volontairement minimal : la liste des patients récents, la fiche
/// détaillée et l'historique des mesures relèvent de F-41 et F-40.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repository = PatientRepository();
  List<PatientRecord>? _patients;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final patients = await _repository.loadAll();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _error = null;
      });
    } on PatientStorageException catch (e) {
      if (!mounted) return;
      setState(() {
        _patients = null;
        _error = e.message;
      });
    }
  }

  Future<void> _open([PatientRecord? record]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PatientEditPage(initial: record)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // SingleChildScrollView + Column plutôt que ListView : la liste reste
      // courte et les tests widget trouvent toutes les lignes.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Patient records',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.blue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Saved on this device only.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('patient_add'),
              onPressed: () => _open(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('New patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_error != null) {
      return [
        Text(
          _error!,
          key: const Key('patients_error'),
          style: const TextStyle(color: Colors.red),
        ),
      ];
    }
    final patients = _patients;
    if (patients == null) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (patients.isEmpty) {
      return const [
        Text(
          'No patient record yet.',
          key: Key('patients_empty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ];
    }
    return [
      for (final p in patients)
        Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            key: Key('patient_tile_${p.patientId}'),
            leading: const Icon(Icons.person_outline, color: Colors.blue),
            title: Text(p.patientId, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${p.sex} · ${p.age} y · ${formatMeasure(p.weightKg)} kg · '
              '${formatMeasure(p.heightCm)} cm',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(p),
          ),
        ),
    ];
  }
}
