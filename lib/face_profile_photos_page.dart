import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'results_page.dart';
import 'photo_tutorial_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'guided_camera_page.dart';
import 'utils/consent.dart';

class FaceProfilePhotosPage extends StatefulWidget {
  final double userHeight;
  final String patientId;
  final String sex;
  final int age;
  final double weightKg;

  /// Consentement horodaté (F-03) : la page ne peut pas être ouverte sans.
  final ConsentRecord consent;

  const FaceProfilePhotosPage({
    super.key,
    required this.userHeight,
    required this.patientId,
    required this.sex,
    required this.age,
    required this.weightKg,
    required this.consent,
  });

  @override
  FaceProfilePhotosPageState createState() => FaceProfilePhotosPageState();
}

class FaceProfilePhotosPageState extends State<FaceProfilePhotosPage> {
  XFile? _frontImage;
  XFile? _sideImage;
  bool _isGuiding = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureImage(ImageType.front, showTutorial: true);
    });
  }

  Future<void> sendImagesToApi() async {
    if (_isSending) return;
    if (_frontImage == null || _sideImage == null) {
      _showErrorDialog(context, message: 'Please upload both images.');
      return;
    }

    setState(() => _isSending = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Processing...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Please wait while we process your images.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    Map<String, dynamic>? result;
    String? errorMessage;
    try {
      //final uri = Uri.parse('http://192.168.1.22:5000/calculate-bri'); //
      final uri = Uri.parse(
                'https://circumfit-v4.onrender.com/calculate-bri'); //URL publique de l'API (serveur A-05, Render Frankfurt)
      final request = http.MultipartRequest('POST', uri);

      // Ajouter les données patient et les images
      request.fields['user_height_cm'] = widget.userHeight.toString();
      request.fields['patient_id'] = widget.patientId;
      request.fields['sex'] = widget.sex;
      request.fields['age'] = widget.age.toString();
      request.fields['weight_kg'] = widget.weightKg.toString();
      // F-03 : trace du consentement (consent_given, consent_timestamp,
      // consent_version). Champs supplémentaires, ignorés si le serveur
      // ne les lit pas.
      request.fields.addAll(widget.consent.toFormFields());
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_side',
          await _sideImage!.readAsBytes(),
          filename: _sideImage!.name,
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_front',
          await _frontImage!.readAsBytes(),
          filename: _frontImage!.name,
        ),
      );

      // Envoyer la requête
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decoded = jsonDecode(responseData);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid response from the API.');
        }
        result = decoded;
      } else {
        errorMessage = 'API Error: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isSending = false);
      }
    }

    if (!mounted) return;
    if (errorMessage != null) {
      _showErrorDialog(context, message: errorMessage);
    } else if (result != null) {
      final apiResult = result;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsPage(
            waistCircumference: apiResult['waist_circumference'],
            bri: apiResult['BRI'],
          ),
        ),
      );
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Face & Profile Photos',
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConsentBanner(),
              const SizedBox(height: 20),
              Text(
                _sideImage != null
                    ? 'Photo de profil'
                    : _frontImage != null
                        ? 'Photo de face'
                        : 'Préparation de la photo de face',
                key: const Key('photo_flow_stage'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_sideImage != null) ...[
                _buildPhotoPreview(_sideImage!),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('side_photo_retake'),
                        onPressed: _isGuiding
                            ? null
                            : () => _captureImage(
                                  ImageType.side,
                                  showTutorial: false,
                                ),
                        child: const Text('Reprendre'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('side_photo_send'),
                        onPressed: _isSending ? null : sendImagesToApi,
                        child: const Text('Envoyer'),
                      ),
                    ),
                  ],
                ),
              ] else if (_frontImage != null) ...[
                _buildPhotoPreview(_frontImage!),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('front_photo_retake'),
                        onPressed: _isGuiding
                            ? null
                            : () => _captureImage(
                                  ImageType.front,
                                  showTutorial: false,
                                ),
                        child: const Text('Reprendre'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('front_photo_next'),
                        onPressed: _isGuiding
                            ? null
                            : () => _captureImage(ImageType.side,
                                showTutorial: true),
                        child: const Text('Suivant'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                if (!_isGuiding) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('front_photo_start'),
                    onPressed: () => _captureImage(
                      ImageType.front,
                      showTutorial: true,
                    ),
                    child: const Text('Commencer la photo de face'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(XFile image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FutureBuilder<Uint8List>(
        future: image.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SizedBox(
              height: 300,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: 420,
          );
        },
      ),
    );
  }

  Widget _buildConsentBanner() {
    return Container(
      key: const Key('consent_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Consentement recueilli le '
              '${formatConsentTimestamp(widget.consent.givenAtUtc)}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage(
    ImageType type, {
    required bool showTutorial,
  }) async {
    // F-03 : garde-fou, le consentement doit concerner ce patient.
    if (!widget.consent.coversPatient(widget.patientId)) {
      _showErrorDialog(context,
          message: 'Consentement manquant pour ce patient.');
      return;
    }
    if (_isGuiding) return;
    setState(() => _isGuiding = true);
    try {
      if (showTutorial) {
        final understood = await showPhotoTutorial(
          context,
          view: type == ImageType.front ? PoseView.face : PoseView.profil,
          heightCm: widget.userHeight,
        );
        if (!mounted || !understood) return;
      }

      final imageBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => GuidedCameraPage(
            frameWidthRatio: type == ImageType.front ? 0.66 : 0.55,
            frameHeightRatio: type == ImageType.front ? 0.62 : 0.66,
            hintText: type == ImageType.front
                ? "De face : tête, épaules, mains et pieds dans la silhouette"
                : "De profil : épaules, ventre, mains et pieds visibles",
            isSideView: type == ImageType.side,
            showGrid: true,
          ),
        ),
      );
      if (!mounted || imageBytes == null) return;
      final image = XFile.fromData(
        imageBytes,
        name: "circumfit_${DateTime.now().microsecondsSinceEpoch}.jpg",
        mimeType: "image/jpeg",
      );
      setState(() {
        if (type == ImageType.front) {
          _frontImage = image;
        } else {
          _sideImage = image;
        }
      });
    } finally {
      if (mounted) setState(() => _isGuiding = false);
    }
  }

  void _showErrorDialog(BuildContext context, {required String message}) {
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
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                const Text(
                  "Error",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message, // Utilisation du message passé en paramètre
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum ImageType { front, side }
