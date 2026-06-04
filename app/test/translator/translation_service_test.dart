import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rural_tourism_app/features/translator/data/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    expect(result.translatedText, contains('No match found offline'));
  });

  test('simple English templates translate offline', () async {
    final service = TranslationService(client: _RejectingClient());

    final alias = await service.translateText(
      'thanks',
      TranslationDirection.englishToNepali,
      allowOnline: false,
    );
    expect(alias.source, TranslationSource.phrasebook);
    expect(alias.translatedText, contains('धन्यवाद'));

    final confirmation = await service.translateText(
      'ok',
      TranslationDirection.englishToNepali,
      allowOnline: false,
    );
    expect(confirmation.source, TranslationSource.template);
    expect(confirmation.translatedText, 'ठिक छ');
    expect(confirmation.romanized, 'Thik cha');

    final currentlyDoing = await service.translateText(
      'I am currently doing my project',
      TranslationDirection.englishToNepali,
      allowOnline: false,
    );
    expect(currentlyDoing.source, TranslationSource.template);
    expect(currentlyDoing.translatedText, contains('म हाल'));
    expect(currentlyDoing.translatedText, contains('प्रोजेक्ट'));
    expect(currentlyDoing.translatedText, contains('गर्दैछु'));
  });

  test('asset templates and Roman Nepali dictionary improve offline matching',
      () async {
    final service = TranslationService(client: _RejectingClient());

    final template = await service.translateText(
      'is there a hotel nearby',
      TranslationDirection.englishToNepali,
      allowOnline: false,
    );
    expect(template.source, TranslationSource.template);
    expect(template.translatedText, contains('होटल'));
    expect(template.translatedText, contains('नजिकै'));

    final roman = await service.translateText(
      'tapai kasari hunuhuncha',
      TranslationDirection.autoDetect,
      allowOnline: false,
    );
    expect(roman.source, TranslationSource.template);
    expect(roman.translatedText, 'How are you?');
  });

  test('low confidence MyMemory result still returns with warning', () async {
    final service = TranslationService(
      client: _JsonClient({
        'responseData': {
          'translatedText': 'नमूना अनुवाद',
          'match': 0.2,
        },
      }),
    );

    final result = await service.translateText(
      'purple airplane warranty',
      TranslationDirection.englishToNepali,
    );

    expect(result.source, TranslationSource.online);
    expect(result.translatedText, 'नमूना अनुवाद');
    expect(result.warningMessage, contains('Low confidence'));
  });
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('Offline-only translation should not call online APIs.');
  }
}

class _JsonClient extends http.BaseClient {
  final Map<String, dynamic> payload;

  _JsonClient(this.payload);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(payload));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
