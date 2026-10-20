import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/patient_record.dart';
import 'utils/patient_repository.dart';
import 'utils/patient_validators.dart';

// Chiffres + un séparateur décimal (point ou virgule, clavier iPhone FR).
final _decimalInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Création ou modification d'une fiche patient (exigence F-04).
///
/// Sans [initial] : nouvelle fiche. Avec [initial] : modification, avec un
/// bouton de suppression. L'écran se ferme en renvoyant true si une fiche a
/// été créée, modifiée ou supprimée.
///
/// Les champs reprennent les validateurs de F-02 (patient_validators.dart).
class PatientEditPage extends StatefulWidget {
  final PatientRecord? initial;

  const PatientEditPage({super.key, this.initial});

  @override
  State<PatientEditPage> createState() => _PatientEditPageState();
}

class _PatientEditPageState extends State<PatientEditPage> {
  final _repository = PatientRepository();

  late final TextEditingController _idController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _ageController;
  String? _sex;

  bool _showErrors = false;
  bool _busy = false;

  /// Erreur « identifiant déjà pris », connue seulement après la tentative
  /// d'enregistrement. Effacée dès que l'identifiant est modifié.
  String? _duplicateIdError;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _idController = TextEditingController(text: p?.patientId ?? '');
    _heightController =
        TextEditingController(text: p == null ? '' : formatMeasure(p.heightCm));
    _weightController =
        TextEditingController(text: p == null ? '' : formatMeasure(p.weightKg));
    _ageController = TextEditingController(text: p?.age.toString() ?? '');
    _sex = p?.sex;
  }

  @override
  void dispose() {
    _idController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  bool _isValid() =>
      validateSex(_sex) == null &&
      validatePatientId(_idController.text) == null &&
      validateHeight(_heightController.text) == null &&
      validateWeight(_weightController.text) == null &&
      validateAge(_ageController.text) == null;

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _showErrors = true);
    if (!_isValid()) return;

    // Valeurs déjà validées : les parse ne peuvent pas renvoyer null.
    final patientId = _idController.text.trim();
    final height = parseDecimal(_heightController.text)!;
    final weight = parseDecimal(_weightController.text)!;
    final age = parseInteger(_ageController.text)!;

    setState(() => _busy = true);
    try {
      if (_isEditing) {
        await _repository.update(
          widget.initial!.patientId,
          patientId: patientId,
          sex: _sex!,
          age: age,
          weightKg: weight,
          heightCm: height,
        );
      } else {
        await _repository.create(
          patientId: patientId,
          sex: _sex!,
          age: age,
          weightKg: weight,
          heightCm: height,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DuplicatePatientIdException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _duplicateIdError = 'Another record already uses this ID.';
      });
    } on PatientNotFoundException {
      _fail('This record no longer exists on this device.');
    } on PatientStorageException catch (e) {
      _fail(e.message);
    }
  }

  Future<void> _confirmDelete() async {
    if (_busy) return;
    final id = widget.initial!.patientId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this patient record?'),
        content: Text(
          'The record $id will be removed from this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('patient_delete_cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('patient_delete_confirm'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // false = fiche déjà absente : le résultat voulu est atteint.
      await _repository.delete(id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PatientStorageException catch (e) {
      _fail(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit patient record' : 'New patient record',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // SingleChildScrollView + Column : tout l'écran est construit d'un
      // coup (boutons compris), ce que les tests widget attendent.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(51),
                    spreadRadius: 4,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    fieldKey: const Key('patient_field_id'),
                    label: 'Patient ID',
                    hint: 'Enter an ID or pseudonym',
                    controller: _idController,
                    icon: Icons.person_outline,
                    validator: validatePatientId,
                    extraError: _duplicateIdError,
                    maxLength: PatientLimits.maxPatientIdLength,
                    helperText:
                        "Use a pseudonym (e.g. P042), never the patient's name.",
                    onChanged: () => _duplicateIdError = null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    fieldKey: const Key('patient_field_height'),
                    label: 'Height (cm)',
                    hint: 'Enter the height',
                    controller: _heightController,
                    icon: Icons.height,
                    inputType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: validateHeight,
                    inputFormatters: [_decimalInput],
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    fieldKey: const Key('patient_field_weight'),
                    label: 'Weight (kg)',
                    hint: 'Enter the weight',
                    controller: _weightController,
                    icon: Icons.monitor_weight_outlined,
                    inputType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: validateWeight,
                    inputFormatters: [_decimalInput],
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    fieldKey: const Key('patient_field_age'),
                    label: 'Age',
                    hint: 'Enter the age',
                    controller: _ageController,
                    icon: Icons.cake_outlined,
                    inputType: TextInputType.number,
                    validator: validateAge,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Gender',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildSexButton('Male'),
                      const SizedBox(width: 16),
                      _buildSexButton('Female'),
                    ],
                  ),
                  if (_showErrors && validateSex(_sex) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        validateSex(_sex)!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              Text(
                'Created ${_formatDate(widget.initial!.createdAt)} · '
                'last modified ${_formatDate(widget.initial!.updatedAt)}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              key: const Key('patient_save'),
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 18)),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('patient_delete'),
                onPressed: _busy ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete record'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Date locale au format jj/mm/aaaa.
  String _formatDate(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Widget _buildTextField({
    required Key fieldKey,
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String) validator,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? helperText,
    String? extraError,
    VoidCallback? onChanged,
  }) {
    // Même règle que le formulaire « Check details » (F-02) : erreur en
    // temps réel dès que le champ contient du texte, champs vides signalés
    // seulement après un appui sur Save.
    final fieldError = _showErrors || controller.text.isNotEmpty
        ? validator(controller.text)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: inputType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          autocorrect: false,
          cursorColor: Colors.blue,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            helperText: helperText,
            helperMaxLines: 2,
            errorMaxLines: 2,
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            errorText: fieldError ?? extraError,
          ),
          onChanged: (_) => setState(() => onChanged?.call()),
        ),
      ],
    );
  }

  Widget _buildSexButton(String sex) {
    final isSelected = _sex == sex;
    return Expanded(
      child: ElevatedButton(
        key: Key('patient_sex_$sex'),
        onPressed: () => setState(() => _sex = sex),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(sex),
      ),
    );
  }
}
