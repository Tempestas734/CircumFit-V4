import 'package:flutter/material.dart';

import 'utils/local_waist_measurement.dart';

class ResultsPage extends StatelessWidget {
  final double waistCircumference;
  final double bri;
  final LocalWaistMeasurement? localMeasurement;
  final String? localMeasurementError;

  const ResultsPage({
    super.key,
    required this.waistCircumference,
    required this.bri,
    this.localMeasurement,
    this.localMeasurementError,
  });

  String _getBriCategory(double bri) {
    if (bri < 1) return "Underweight";
    if (bri < 3) return "Normal";
    if (bri < 4) return "Overweight";
    return "Obesity";
  }

  Color _getBriColor(double bri) {
    if (bri < 3.41) return Colors.blue;
    if (bri < 4.45) return Colors.green;
    if (bri < 5.66) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final String briCategory = _getBriCategory(bri);
    final Color briColor = _getBriColor(bri);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Results",
          style: TextStyle(color: Colors.black, fontSize: 24),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Waist Circumference Card (réduit en taille)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                margin: const EdgeInsets.only(bottom: 30),
                width: MediaQuery.of(context).size.width *
                    0.9, // Réduction de la largeur à 90% de l'écran
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((0.3 * 255).toInt()),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.straighten,
                          color: Colors.grey,
                          size: 30,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Server waist circumference",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "${waistCircumference.toStringAsFixed(1)} cm",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((0.3 * 255).toInt()),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "On-device estimate (experimental)",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Ramanujan ellipse, shape factor 1.0 (not calibrated)",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    if (localMeasurement != null) ...[
                      Text(
                        "${localMeasurement!.circumferenceCm.toStringAsFixed(1)} cm",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        "Difference from server: "
                        "${(localMeasurement!.circumferenceCm - waistCircumference).toStringAsFixed(1)} cm",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localMeasurement!.bri == null
                            ? "Local BRI unavailable for these dimensions."
                            : "Local BRI: ${localMeasurement!.bri!.toStringAsFixed(1)} "
                                "(server: ${bri.toStringAsFixed(1)})",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ] else
                      Text(
                        "Unavailable: ${localMeasurementError ?? 'both local views are required.'}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                  ],
                ),
              ),

              // BRI Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((0.3 * 255).toInt()),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.analytics, size: 50, color: Colors.orange),
                    const SizedBox(height: 10),
                    const Text(
                      "Server Body Roundness Index (BRI)",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bri.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: briColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("< 3.41", style: TextStyle(color: Colors.grey)),
                        Text("4.45", style: TextStyle(color: Colors.grey)),
                        Text("5.66", style: TextStyle(color: Colors.grey)),
                        Text("> 6.91", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      briCategory,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: briColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Recommendations Section (Dernière version optimisée)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((0.3 * 255).toInt()),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recommendations",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.local_dining_outlined, color: Colors.green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Maintain a balanced diet with proper nutrient intake.",
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.fitness_center, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Include regular physical activity, like walking or gym sessions, in your routine.",
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.medical_services_outlined,
                            color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Consult a healthcare professional for personalized advice.",
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
