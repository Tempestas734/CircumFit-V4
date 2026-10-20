// Consentement du patient avant la prise de photo (exigence F-03).
//
// Fonctions et classes pures, sans dépendance à Flutter : elles sont testées
// dans test/consent_test.dart. L'écran correspondant est lib/consent_page.dart.

/// Texte du consentement présenté au patient. Toute modification du texte
/// doit s'accompagner d'un changement de [version], pour savoir a posteriori
/// quelle formulation le patient a acceptée.
class ConsentText {
  static const String version = 'v1-2026-10-20';

  static const String title = 'Consentement du patient';

  static const String intro =
      'Avant toute photo, lisez ces points au patient et cochez-les '
      'un par un après son accord oral.';

  static const List<String> statements = [
    "Le patient a été informé de l'objectif : estimer son tour de taille "
        'à partir de deux photos (face et profil).',
    'Le patient sait que les photos sont envoyées à un serveur de calcul et '
        "que la mesure est associée à son identifiant pseudonymisé, "
        'pas à son nom.',
    "Le patient sait qu'il peut refuser ou retirer son consentement à tout "
        'moment, sans conséquence sur sa prise en charge.',
    "Le patient accepte d'être photographié de face et de profil.",
  ];
}

/// Vrai seulement si chaque point du texte a été coché.
bool allStatementsAccepted(List<bool> checks) =>
    checks.length == ConsentText.statements.length &&
    checks.every((checked) => checked);

/// Trace du consentement : qui (identifiant patient), quand (horodatage UTC
/// à la seconde) et sur quel texte (version).
class ConsentRecord {
  final String patientId;
  final DateTime givenAtUtc;
  final String textVersion;

  const ConsentRecord._({
    required this.patientId,
    required this.givenAtUtc,
    required this.textVersion,
  });

  /// Crée l'enregistrement au moment où le professionnel valide.
  /// Lève une [ArgumentError] si un point n'est pas coché ou si l'identifiant
  /// est vide : on ne peut pas obtenir de [ConsentRecord] sans consentement
  /// complet. [now] sert uniquement aux tests.
  factory ConsentRecord.give({
    required String patientId,
    required List<bool> checks,
    DateTime? now,
  }) {
    final id = patientId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(patientId, 'patientId', 'identifiant vide');
    }
    if (!allStatementsAccepted(checks)) {
      throw ArgumentError.value(checks, 'checks', 'consentement incomplet');
    }
    final t = (now ?? DateTime.now()).toUtc();
    // Tronqué à la seconde : même format sur iPhone, Android et web.
    final utc = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
    return ConsentRecord._(
      patientId: id,
      givenAtUtc: utc,
      textVersion: ConsentText.version,
    );
  }

  /// Horodatage ISO 8601 en UTC, ex. « 2026-10-20T16:34:12.000Z ».
  String get timestampIso => givenAtUtc.toIso8601String();

  /// Le consentement ne vaut que pour le patient qui l'a donné.
  bool coversPatient(String id) => id.trim() == patientId;

  /// Champs ajoutés à la requête envoyée au serveur, pour garder la trace
  /// du consentement avec la mesure.
  Map<String, String> toFormFields() => {
        'consent_given': 'true',
        'consent_timestamp': timestampIso,
        'consent_version': textVersion,
      };
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Date lisible en heure locale du téléphone : « 20/10/2026 à 18:34:12 ».
String formatConsentTimestamp(DateTime dateTime) {
  final d = dateTime.toLocal();
  return '${_two(d.day)}/${_two(d.month)}/${d.year} à '
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
}
