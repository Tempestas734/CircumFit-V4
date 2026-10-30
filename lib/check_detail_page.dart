import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'consent_page.dart';
import 'face_profile_photos_page.dart';
import 'utils/consent.dart';
import 'utils/patient_repository.dart';
import 'utils/patient_validators.dart';

// Chiffres + un séparateur décimal (point ou virgule, clavier iPhone FR).
final _decimalInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

class CheckDetailPage extends StatefulWidget {
  const CheckDetailPage({super.key});
  @override
  CheckDetailPageState createState() => CheckDetailPageState();
}

class CheckDetailPageState extends State<CheckDetailPage> {
  String? selectedGender;
  final TextEditingController patientIdController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  bool showErrors = false;

  // F-04 : la fiche patient est enregistrée sur l'appareil à l'appui sur Next.
  final _patients = PatientRepository();

  @override
  void dispose() {
    patientIdController.dispose();
    heightController.dispose();
    weightController.dispose();
    ageController.dispose();
    super.dispose();
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
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Check details',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20.0),
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
                      label: "Patient ID",
                      hint: "Enter an ID or pseudonym",
                      controller: patientIdController,
                      icon: Icons.person_outline,
                      isRequired: true,
                      validator: validatePatientId,
                      maxLength: PatientLimits.maxPatientIdLength,
                      helperText:
                          "Use a pseudonym (e.g. P042), never the patient's name.",
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Height (cm)",
                      hint: "Enter your height",
                      controller: heightController,
                      icon: Icons.height,
                      inputType:
                          const TextInputType.numberWithOptions(decimal: true),
                      isRequired: true, // Indique que ce champ est obligatoire
                      validator: validateHeight,
                      inputFormatters: [_decimalInput],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Weight (kg)",
                      hint: "Enter your weight",
                      controller: weightController,
                      icon: Icons.monitor_weight_outlined,
                      inputType:
                          const TextInputType.numberWithOptions(decimal: true),
                      isRequired: true,
                      validator: validateWeight,
                      inputFormatters: [_decimalInput],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Age",
                      hint: "Enter your age",
                      controller: ageController,
                      icon: Icons.cake_outlined,
                      inputType: TextInputType.number,
                      isRequired: true,
                      validator: validateAge,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Gender",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildGenderButton("Male"),
                        const SizedBox(width: 16),
                        _buildGenderButton("Female"),
                      ],
                    ),
                    if (showErrors && validateSex(selectedGender) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          validateSex(selectedGender)!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 50,
                  width: 150,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.lightBlueAccent],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withAlpha((0.3 * 255).toInt()),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        showErrors = true;
                      });
                      if (!_validateInputs()) return;
                      final proceed = await _savePatientRecord();
                      if (!proceed) return;
                      await _continueToConsent();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "Next",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool isRequired = false, // Ajout pour indiquer si un champ est obligatoire
    required String? Function(String) validator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? helperText,
  }) {
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
            if (isRequired) // Affiche l'astérisque rouge si le champ est obligatoire
              const Text(
                " *",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
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
              borderSide: const BorderSide(
                  color: Colors.grey), // Contour gris par défaut
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Colors.blue,
                  width: 2), // Contour bleu pour la case active
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Colors.grey), // Contour gris pour les cases inactives
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Colors.red), // Contour rouge en cas d'erreur
            ),
            // Validation en temps réel dès que le champ contient du texte ;
            // les champs vides ne sont signalés qu'après un appui sur Next.
            errorText: showErrors || controller.text.isNotEmpty
                ? validator(controller.text)
                : null,
          ),
          onChanged: (value) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildGenderButton(String gender) {
    bool isSelected = selectedGender == gender;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            selectedGender = gender;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(gender),
      ),
    );
  }

  bool _validateInputs() {
    return validateSex(selectedGender) == null &&
        validatePatientId(patientIdController.text) == null &&
        validateHeight(heightController.text) == null &&
        validateWeight(weightController.text) == null &&
        validateAge(ageController.text) == null;
  }

  /// F-04 : crée la fiche patient, ou la met à jour si l'identifiant existe
  /// déjà avec d'autres valeurs (après confirmation).
  ///
  /// Renvoie false seulement si l'utilisateur annule la mise à jour : il
  /// reste alors sur le formulaire. Une erreur de stockage n'empêche pas la
  /// mesure : elle est signalée et le parcours continue.
  Future<bool> _savePatientRecord() async {
    final patientId = patientIdController.text.trim();
    final sex = selectedGender!;
    final age = parseInteger(ageController.text)!;
    final weight = parseDecimal(weightController.text)!;
    final height = parseDecimal(heightController.text)!;
    try {
      final existing = await _patients.find(patientId);
      if (existing == null) {
        await _patients.create(
          patientId: patientId,
          sex: sex,
          age: age,
          weightKg: weight,
          heightCm: height,
        );
        return true;
      }
      if (existing.hasSameDataAs(
        patientId: patientId,
        sex: sex,
        age: age,
        weightKg: weight,
        heightCm: height,
      )) {
        return true;
      }
      if (!mounted) return false;
      final update = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update patient record?'),
          content: Text(
            'A record already exists for ${existing.patientId} with other '
            'values. Replace them with the values entered?',
          ),
          actions: [
            TextButton(
              key: const Key('record_update_cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('record_update_confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (update != true) return false;
      await _patients.update(
        existing.patientId,
        patientId: patientId,
        sex: sex,
        age: age,
        weightKg: weight,
        heightCm: height,
      );
      return true;
    } on DuplicatePatientIdException {
      // Double appui sur Next : la fiche vient d'être créée par le premier.
      return true;
    } on PatientStorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Patient record not saved: ${e.message}')),
        );
      }
      return true;
    }
  }

  Future<void> _continueToConsent() async {
    final height = parseDecimal(heightController.text);
    final weight = parseDecimal(weightController.text);
    final age = parseInteger(ageController.text);
    if (height == null || weight == null || age == null) return;

    final patientId = patientIdController.text.trim();
    final consent = await Navigator.push<ConsentRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => ConsentPage(patientId: patientId),
      ),
    );
    if (!mounted) return;
    if (consent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune photo sans consentement du patient.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceProfilePhotosPage(
          userHeight: height,
          patientId: patientId,
          sex: selectedGender!,
          age: age,
          weightKg: weight,
          consent: consent,
        ),
      ),
    );
  }
}
