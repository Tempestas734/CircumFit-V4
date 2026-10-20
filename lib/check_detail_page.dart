import 'package:flutter/material.dart';
import 'face_profile_photos_page.dart';

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
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: "Age",
                      hint: "Enter your age",
                      controller: ageController,
                      icon: Icons.cake_outlined,
                      inputType: TextInputType.number,
                      isRequired: true,
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
                    if (showErrors && selectedGender == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "Please select a sex.",
                          style: TextStyle(color: Colors.red, fontSize: 12),
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
                    onPressed: () {
                      setState(() {
                        showErrors = true;
                      });
                      if (_validateInputs()) {
                        _showPhotoOptions(context);
                      }
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
          cursorColor: Colors.blue,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
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
            errorText: showErrors || controller.text.isNotEmpty
                ? _getErrorText(label, controller.text)
                : null,
          ),
          onChanged: (value) => setState(() {}),
        ),
      ],
    );
  }

  String? _getErrorText(String field, String value) {
    if (value.trim().isEmpty) {
      return field == "Patient ID"
          ? "Please enter a patient ID or pseudonym."
          : "Please fill out the $field field.";
    }

    if (field == "Height (cm)") {
      final height = double.tryParse(value);
      if (height == null || !height.isFinite) {
        return "$field must be a valid number.";
      }
      if (height < 100 || height > 230) {
        return "$field must be between 100 and 230 cm.";
      }
    } else if (field == "Weight (kg)") {
      final weight = double.tryParse(value);
      if (weight == null || !weight.isFinite || weight <= 0) {
        return "$field must be a positive number.";
      }
    } else if (field == "Age") {
      final age = int.tryParse(value);
      if (age == null || age <= 0) {
        return "$field must be a positive whole number.";
      }
    }

    return null;
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
    return selectedGender != null &&
        _getErrorText("Patient ID", patientIdController.text) == null &&
        _getErrorText("Height (cm)", heightController.text) == null &&
        _getErrorText("Weight (kg)", weightController.text) == null &&
        _getErrorText("Age", ageController.text) == null;
  }

  void _showPhotoOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Centre les éléments principaux
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                const SizedBox(height: 10),
                const Text(
                  "Photo Instructions",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center, // Centrer le texte
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.grey),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment
                      .start, // Alignement à gauche des instructions
                  children: [
                    _buildInstruction(1, "Ensure proper lighting."),
                    const SizedBox(height: 10),
                    _buildInstruction(2, "Use a contrasting background."),
                    const SizedBox(height: 10),
                    _buildInstruction(3, "Wear tight clothing or underwear."),
                    const SizedBox(height: 10),
                    _buildInstruction(4,
                        "For the front photo: Stand straight with arms at 45° and feet shoulder-width apart."),
                    const SizedBox(height: 10),
                    _buildInstruction(5,
                        "For the side photo: Stand straight with feet together and arms at 90°."),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FaceProfilePhotosPage(
                          userHeight: double.parse(heightController.text),
                          patientId: patientIdController.text.trim(),
                          sex: selectedGender!,
                          age: int.parse(ageController.text),
                          weightKg: double.parse(weightController.text),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Proceed",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstruction(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$number. ",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
            textAlign: TextAlign.justify, // Justification du texte
          ),
        ),
      ],
    );
  }
}
