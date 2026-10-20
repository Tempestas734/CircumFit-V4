import 'package:flutter/material.dart';
import 'utils/consent.dart';

/// Écran de consentement (exigence F-03), affiché avant toute prise de photo.
///
/// Renvoie (via Navigator.pop) un [ConsentRecord] horodaté si le patient
/// consent, ou null s'il refuse ou si l'on revient en arrière.
class ConsentPage extends StatefulWidget {
  final String patientId;

  const ConsentPage({super.key, required this.patientId});

  @override
  ConsentPageState createState() => ConsentPageState();
}

class ConsentPageState extends State<ConsentPage> {
  final List<bool> _checks =
      List<bool>.filled(ConsentText.statements.length, false);

  bool get _complete => allStatementsAccepted(_checks);

  void _accept() {
    // L'horodatage est pris ici, au moment exact de la validation.
    final record = ConsentRecord.give(
      patientId: widget.patientId,
      checks: _checks,
    );
    Navigator.pop(context, record);
  }

  void _refuse() {
    Navigator.pop<ConsentRecord>(context, null);
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
                    onPressed: _refuse,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    ConsentText.title,
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Patient : ${widget.patientId}',
                      key: const Key('consent_patient_id'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              ConsentText.intro,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < ConsentText.statements.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: CheckboxListTile(
                    key: Key('consent_check_$i'),
                    value: _checks[i],
                    onChanged: (value) =>
                        setState(() => _checks[i] = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      ConsentText.statements[i],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              "La date et l'heure du consentement seront enregistrées "
              'avec la mesure (texte ${ConsentText.version}).',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                key: const Key('consent_accept'),
                onPressed: _complete ? _accept : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Le patient consent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                key: const Key('consent_refuse'),
                onPressed: _refuse,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Le patient refuse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
