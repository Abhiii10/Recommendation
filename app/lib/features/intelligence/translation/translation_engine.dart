import '../models/translation_request.dart';
import '../models/translation_response.dart';

abstract class TranslationEngine {
  Future<void> load();

  Future<TranslationResponse?> translate(TranslationRequest request);
}
