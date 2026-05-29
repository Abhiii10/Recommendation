import 'package:rural_tourism_app/features/intelligence/models/translation_request.dart';
import 'package:rural_tourism_app/features/intelligence/models/translation_response.dart';

abstract class TranslationEngine {
  Future<void> load();

  Future<TranslationResponse?> translate(TranslationRequest request);
}
