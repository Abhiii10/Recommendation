import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rural_tourism_app/features/translator/data/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline-only translation returns local phrasebook matches', () async {
    final service = TranslationService(client: _RejectingClient());

    final result = await service.translateText(
      'I need drinking water',
      TranslationDirection.englishToNepali,
      allowOnline: false,
    );

    expect(result.isOffline, isTrue);
    expect(result.source, TranslationSource.phrasebook);
    expect(result.translatedText, contains('पानी'));
  });

  test('offline-only translation skips online fallback when no local match',
      () async {
    final service = TranslationService(client: _RejectingClient());

    final result = await service.translateText(
      'purple airplane warranty',
      TranslationDirection.englishToNepali,
      allowOnline: false,
    );

    expect(result.isOffline, isFalse);
    expect(result.source, TranslationSource.fallback);
    expect(result.confidence, 0);
    expect(result.translatedText, contains('No offline translation match'));
  });
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('Offline-only translation should not call online APIs.');
  }
}
