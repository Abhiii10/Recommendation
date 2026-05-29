import 'package:rural_tourism_app/features/intelligence/utils/text_utils.dart';

class EmergencyDetector {
  static const _englishPatterns = [
    'emergency',
    'sos',
    'help me',
    'rescue',
    'accident',
    'injured',
    'hurt',
    'lost',
    'missing',
    'police',
    'ambulance',
    'hospital',
    'fire',
    'altitude sickness',
    'bleeding',
    'unconscious',
    'danger',
    'theft',
    'harassment',
  ];

  static const _nepaliPatterns = [
    'आपतकाल',
    'सहयोग',
    'मद्दत',
    'उद्धार',
    'प्रहरी',
    'अस्पताल',
    'एम्बुलेन्स',
    'दमकल',
    'दुर्घटना',
    'घाइते',
    'बिरामी',
    'खतरा',
    'हराएँ',
    'बाटो थाहा भएन',
    'बिपद',
  ];

  static const _romanizedPatterns = [
    'aapatkaal',
    'aapatkal',
    'sahayog',
    'madat',
    'uddhar',
    'udhaar',
    'prahari',
    'aspatal',
    'ambulance',
    'damkal',
    'durghatana',
    'ghaite',
    'birami',
    'khatra',
    'ma haraye',
    'bato thaha bhayena',
  ];

  const EmergencyDetector();

  EmergencyDetectionResult detect(String input) {
    final normalized = TextUtils.normalizeSearchText(input);
    final matched = <String>[];
    for (final pattern in [
      ..._englishPatterns,
      ..._nepaliPatterns,
      ..._romanizedPatterns,
    ]) {
      if (normalized.contains(TextUtils.normalizeSearchText(pattern))) {
        matched.add(pattern);
      }
    }
    final confidence =
        matched.isEmpty ? 0.0 : (0.65 + matched.length * 0.12).clamp(0.0, 1.0);
    return EmergencyDetectionResult(
      isEmergency: confidence >= 0.65,
      confidence: confidence,
      matchedPatterns: matched,
    );
  }
}

class EmergencyDetectionResult {
  final bool isEmergency;
  final double confidence;
  final List<String> matchedPatterns;

  const EmergencyDetectionResult({
    required this.isEmergency,
    required this.confidence,
    required this.matchedPatterns,
  });
}
