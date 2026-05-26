import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/safety/emergency_detector.dart';
import 'package:rural_tourism_app/features/intelligence/services/translation_service_advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deterministic emergency detection is comfortably under target', () {
    const detector = EmergencyDetector();
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      detector.detect('sos I am lost and injured');
    }
    stopwatch.stop();
    final averageMs = stopwatch.elapsedMicroseconds / 100 / 1000;
    expect(averageMs, lessThan(20));
  });

  test('warm offline translation is under target', () async {
    final service = TranslationServiceAdvanced();
    await service.init();
    final stopwatch = Stopwatch()..start();
    final response = await service.translate(
      const TranslationRequest(text: 'How much does it cost?'),
    );
    stopwatch.stop();
    expect(response.translatedText, isNotEmpty);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });
}
