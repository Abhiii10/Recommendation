import 'package:flutter_test/flutter_test.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';
import 'package:rural_tourism_app/features/intelligence/services/translation_service_advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline phrasebook and template translation work', () async {
    final service = TranslationServiceAdvanced();
    await service.init();

    final phrase = await service.translate(
      const TranslationRequest(text: 'I need drinking water'),
    );
    expect(phrase.method, isNot(TranslationMethod.noResult));
    expect(phrase.isOffline, isTrue);
    expect(phrase.translatedText, contains('पानी'));

    final template = await service.translate(
      const TranslationRequest(text: 'where is Ghandruk'),
    );
    expect(template.method, TranslationMethod.template);
    expect(template.translatedText, contains('Ghandruk'));
  });
}
